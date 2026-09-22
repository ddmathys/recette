"use client";

import { useEffect, useState } from "react";
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  onSnapshot,
  orderBy,
  query,
  updateDoc,
  where,
} from "firebase/firestore";
import { ref, uploadBytes, getDownloadURL, deleteObject } from "firebase/storage";
import { db, storage, firebaseEnabled } from "./firebase";
import type { MealLog, MealLogDraft } from "./types";

const COLLECTION = "mealLogs";

/** All meal logs for the household, newest first — same simple
 * fetch-everything approach as useRecipes.ts (household volumes stay small
 * enough that client-side day filtering is fine, no need for range
 * queries). Pass null while householdId is still loading. */
export function useMealLogs(householdId: string | null) {
  const [logs, setLogs] = useState<MealLog[]>([]);
  const [loading, setLoading] = useState(firebaseEnabled);

  useEffect(() => {
    if (!firebaseEnabled || !db || !householdId) return;
    const q = query(
      collection(db, COLLECTION),
      where("householdId", "==", householdId),
      orderBy("eatenAt", "desc"),
    );
    const unsub = onSnapshot(
      q,
      (snap) => {
        setLogs(snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<MealLog, "id">) })));
        setLoading(false);
      },
      () => setLoading(false),
    );
    return unsub;
  }, [householdId]);

  return { logs, loading };
}

export async function addMealLog(
  draft: MealLogDraft,
  photoUrl: string | null,
  source: MealLog["source"],
  owner: { uid: string; name: string; householdId: string },
) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  const data: Omit<MealLog, "id"> = {
    ...draft,
    recipeId: draft.recipeId || null,
    photoUrl: photoUrl || null,
    source,
    createdAt: new Date().toISOString(),
    householdId: owner.householdId,
    ownerId: owner.uid,
    ownerName: owner.name,
  };
  const ref = await addDoc(collection(db, COLLECTION), data);
  return ref.id;
}

export async function updateMealLog(id: string, draft: MealLogDraft) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  await updateDoc(doc(db, COLLECTION, id), { ...draft, recipeId: draft.recipeId || null });
}

export async function deleteMealLog(id: string, photoUrl?: string | null) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  if (storage && photoUrl) {
    try {
      await deleteObject(ref(storage, photoUrl));
    } catch {
      // Best effort: photo may already be gone.
    }
  }
  await deleteDoc(doc(db, COLLECTION, id));
}

export async function uploadMealPhoto(uid: string, file: File): Promise<string> {
  if (!storage) throw new Error("Firebase n'est pas configuré.");
  const fileRef = ref(storage, `mealPhotos/${uid}/${Date.now()}-${file.name}`);
  await uploadBytes(fileRef, file);
  return getDownloadURL(fileRef);
}
