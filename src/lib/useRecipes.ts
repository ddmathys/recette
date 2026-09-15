"use client";

import { useEffect, useState } from "react";
import {
  addDoc,
  collection,
  deleteField,
  doc,
  onSnapshot,
  orderBy,
  query,
  updateDoc,
} from "firebase/firestore";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { db, storage, firebaseEnabled } from "./firebase";
import { SEED_RECIPES } from "@/data/seed-recipes";
import type { Recipe, RecipeDraft } from "./types";

const COLLECTION = "recipes";

export function useRecipes() {
  const [recipes, setRecipes] = useState<Recipe[]>(SEED_RECIPES);
  const [loading, setLoading] = useState(firebaseEnabled);
  const [usingSeedFallback, setUsingSeedFallback] = useState(true);

  useEffect(() => {
    if (!firebaseEnabled || !db) return;
    const q = query(collection(db, COLLECTION), orderBy("createdAt", "asc"));
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
  }, []);

  const readOnly = !firebaseEnabled || usingSeedFallback;
  return { recipes, loading, readOnly };
}

export async function addRecipe(draft: RecipeDraft, source: string | null, photoUrl: string | null) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  const data: Omit<Recipe, "id"> = {
    ...draft,
    source: source || null,
    photoUrl: photoUrl || null,
    notes: "",
    createdAt: new Date().toISOString(),
  };
  await addDoc(collection(db, COLLECTION), data);
}

export async function saveNotes(id: string, text: string) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  await updateDoc(doc(db, COLLECTION, id), { notes: text });
}

export async function uploadRecipePhoto(id: string, file: File) {
  if (!db || !storage) throw new Error("Firebase n'est pas configuré.");
  const fileRef = ref(storage, `recipes/${id}/${Date.now()}-${file.name}`);
  await uploadBytes(fileRef, file);
  const url = await getDownloadURL(fileRef);
  await updateDoc(doc(db, COLLECTION, id), { photoUrl: url });
  return url;
}

export async function setRecipePhotoUrl(id: string, url: string) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  await updateDoc(doc(db, COLLECTION, id), { photoUrl: url });
}

export async function clearRecipePhoto(id: string) {
  if (!db) throw new Error("Firebase n'est pas configuré.");
  await updateDoc(doc(db, COLLECTION, id), { photoUrl: deleteField() });
}
