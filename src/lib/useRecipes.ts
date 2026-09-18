"use client";

import { useEffect, useState } from "react";
import {
  addDoc,
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  deleteField,
  doc,
  onSnapshot,
  orderBy,
  query,
  updateDoc,
  where,
} from "firebase/firestore";
import { ref, uploadBytes, getDownloadURL, deleteObject } from "firebase/storage";
import { db, storage, firebaseEnabled } from "./firebase";
import { SEED_RECIPES } from "@/data/seed-recipes";
import type { Recipe, RecipeDraft } from "./types";

const COLLECTION = "recipes";

/** `householdId` scopes the query to the signed-in user's current shared
 * library (their own, or one they joined — see useHousehold.ts). Pass
 * null while that's still loading to avoid a flash of someone else's
 * data or a permission-denied query. */
export function useRecipes(householdId: string | null) {
  const [recipes, setRecipes] = useState<Recipe[]>(SEED_RECIPES);
  const [loading, setLoading] = useState(firebaseEnabled);
  const [usingSeedFallback, setUsingSeedFallback] = useState(true);

  useEffect(() => {
    if (!firebaseEnabled || !db || !householdId) return;
    const q = query(
      collection(db, COLLECTION),
      where("householdId", "==", householdId),
      orderBy("createdAt", "asc"),
    );
    const unsub = onSnapshot(
      q,
      (snap) => {
        if (snap.empty) {
          // Firestore is reachable but not seeded yet (run `npm run seed`):
          // keep showing the built-in recipes, read-only, instead of a blank page.
          setRecipes(SEED_RECIPES);
          setUsingSeedFallback(true);
        } else {
          setRecipes(snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<Recipe, "id">) })));
          setUsingSeedFallback(false);
        }
        setLoading(false);
      },
      () => setLoading(false),
    );
    return unsub;
  }, [householdId]);

  const readOnly = !firebaseEnabled || usingSeedFallback;
  return { recipes, loading, readOnly };
}

/** Returns the new document's id so callers can attach a photo afterwards
 * without risking a duplicate recipe if that second step fails. */
export async function addRecipe(
  draft: RecipeDraft,
  source: string | null,
  photoUrl: string | null,
  owner: { uid: string; name: string; householdId: string },
) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  const data: Omit<Recipe, "id"> = {
    ...draft,
    source: source || null,
    photoUrl: photoUrl || null,
    notes: "",
    createdAt: new Date().toISOString(),
    householdId: owner.householdId,
    ownerId: owner.uid,
    ownerName: owner.name,
  };
  const ref = await addDoc(collection(db, COLLECTION), data);
  return ref.id;
}

/** Full content replacement for the "edit recipe" flow (manual or
 * AI-assisted) — everything except ownership/notes/photo/eaten dates,
 * which are managed by their own dedicated functions. */
export async function updateRecipeContent(id: string, draft: RecipeDraft) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  await updateDoc(doc(db, COLLECTION, id), { ...draft });
}

export async function saveNotes(id: string, text: string) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  await updateDoc(doc(db, COLLECTION, id), { notes: text });
}

export async function addEatenDate(id: string, date: string) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  await updateDoc(doc(db, COLLECTION, id), { eatenDates: arrayUnion(date) });
}

export async function removeEatenDate(id: string, date: string) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  await updateDoc(doc(db, COLLECTION, id), { eatenDates: arrayRemove(date) });
}

function storageErrorMessage(e: unknown): string {
  const code = e && typeof e === "object" && "code" in e ? String((e as { code: unknown }).code) : "";
  switch (code) {
    case "storage/unauthorized":
      return "Envoi refusé par les règles de sécurité Storage.";
    case "storage/canceled":
      return "Envoi annulé.";
    case "storage/quota-exceeded":
      return "Quota de stockage dépassé.";
    case "storage/retry-limit-exceeded":
      return "Connexion trop lente ou instable, réessaie.";
    default:
      return "L'envoi de la photo a échoué, réessaie.";
  }
}

export async function uploadRecipePhoto(id: string, file: File) {
  if (!db || !storage) throw new Error("Firebase n'est pas configuré.");
  const fileRef = ref(storage, `recipes/${id}/${Date.now()}-${file.name}`);
  try {
    await uploadBytes(fileRef, file);
    const url = await getDownloadURL(fileRef);
    await updateDoc(doc(db, COLLECTION, id), { photoUrl: url });
    return url;
  } catch (e) {
    throw new Error(storageErrorMessage(e));
  }
}

export async function deleteRecipe(id: string, photoUrl?: string | null) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  if (storage && photoUrl) {
    try {
      await deleteObject(ref(storage, photoUrl));
    } catch {
      // Best effort: photo may already be gone, or hosted outside our bucket.
    }
  }
  await deleteDoc(doc(db, COLLECTION, id));
}

export async function setRecipePhotoUrl(id: string, url: string) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  await updateDoc(doc(db, COLLECTION, id), { photoUrl: url });
}

export async function clearRecipePhoto(id: string) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  await updateDoc(doc(db, COLLECTION, id), { photoUrl: deleteField() });
}
