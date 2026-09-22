"use client";

import { useEffect, useState } from "react";
import {
  arrayRemove,
  arrayUnion,
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  query,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";
import type { User } from "firebase/auth";
import { db } from "./firebase";
import type { Household, UserProfile } from "./types";

/** Fallback display name from the local part of an email (`marie.d@…` → "Marie.d")
 * — used only if the account was created before the "Prénom" field existed,
 * or as a defensive default. */
function nameFromEmail(email: string): string {
  const local = email.split("@")[0] || "Moi";
  return local.charAt(0).toUpperCase() + local.slice(1);
}

/** Creates users/{uid} and households/{uid} the first time an account is
 * seen, if they don't already exist. Safe to call on every sign-in. */
export async function ensureUserProfile(user: User, displayName?: string) {
  if (!db) return;
  const userRef = doc(db, "users", user.uid);
  const snap = await getDoc(userRef);
  if (!snap.exists()) {
    const name = displayName?.trim() || nameFromEmail(user.email || "");
    await setDoc(userRef, {
      email: (user.email || "").toLowerCase(),
      displayName: name,
      householdId: user.uid,
    } satisfies UserProfile);
  }
  const householdRef = doc(db, "households", user.uid);
  const householdSnap = await getDoc(householdRef);
  if (!householdSnap.exists()) {
    await setDoc(householdRef, {
      ownerId: user.uid,
      ownerEmail: (user.email || "").toLowerCase(),
      members: [user.uid],
    } satisfies Household);
  }
}

export function useHousehold(uid: string | null) {
  // `undefined` = not fetched yet (loading); `null` = fetched, doesn't
  // exist. Distinguishing the two avoids resetting state synchronously in
  // an effect's early-return branch just to flip a separate `loading` flag
  // — the guard branches below simply don't subscribe, and the app never
  // observes uid flip to null while this hook stays mounted anyway (page.tsx
  // unmounts this whole subtree on sign-out, swapping in AuthLanding).
  const [profile, setProfile] = useState<UserProfile | null | undefined>(undefined);
  const [household, setHousehold] = useState<Household | null>(null);

  useEffect(() => {
    if (!uid || !db) return;
    const unsub = onSnapshot(doc(db, "users", uid), (snap) => {
      setProfile(snap.exists() ? (snap.data() as UserProfile) : null);
    });
    return unsub;
  }, [uid]);

  useEffect(() => {
    if (!db || !profile?.householdId) return;
    const unsub = onSnapshot(doc(db, "households", profile.householdId), (snap) => {
      setHousehold(snap.exists() ? (snap.data() as Household) : null);
    });
    return unsub;
  }, [profile?.householdId]);

  return { profile: profile ?? null, household, loading: Boolean(uid) && profile === undefined };
}

/** Looks up an account by email (used to join someone's shared library). */
async function findUserByEmail(email: string): Promise<{ uid: string; profile: UserProfile } | null> {
  if (!db) return null;
  const q = query(collection(db, "users"), where("email", "==", email.trim().toLowerCase()), limit(1));
  const snap = await getDocs(q);
  if (snap.empty) return null;
  const d = snap.docs[0];
  return { uid: d.id, profile: d.data() as UserProfile };
}

export async function joinHousehold(myUid: string, targetEmail: string): Promise<void> {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  const target = await findUserByEmail(targetEmail);
  if (!target) throw new Error("Aucun compte trouvé avec cet e-mail.");
  if (target.uid === myUid) throw new Error("C'est déjà ta bibliothèque.");

  await updateDoc(doc(db, "households", target.uid), { members: arrayUnion(myUid) });
  await updateDoc(doc(db, "users", myUid), { householdId: target.uid });
}

export async function setDailyKcalGoal(uid: string, goal: number): Promise<void> {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  await updateDoc(doc(db, "users", uid), { dailyKcalGoal: goal });
}

export async function leaveHousehold(myUid: string, currentHouseholdId: string): Promise<void> {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  if (currentHouseholdId !== myUid) {
    await updateDoc(doc(db, "households", currentHouseholdId), { members: arrayRemove(myUid) }).catch(() => {
      // Best effort: if we've lost access to update it (e.g. the owner
      // already removed us), still restore our own householdId below.
    });
  }
  await updateDoc(doc(db, "users", myUid), { householdId: myUid });
}
