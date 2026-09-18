"use client";

import { useEffect, useState } from "react";
import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  type User,
} from "firebase/auth";
import { auth, firebaseEnabled } from "./firebase";
import { ensureUserProfile } from "./useHousehold";

export function useAuth() {
  // Tant que Firebase n'est pas configuré, on ne bloque personne (mode
  // lecture seule déjà géré ailleurs) : pas d'auth à vérifier.
  const [user, setUser] = useState<User | null>(null);
  const [checking, setChecking] = useState(firebaseEnabled);

  useEffect(() => {
    if (!firebaseEnabled || !auth) return;
    return onAuthStateChanged(auth, (u) => {
      setUser(u);
      setChecking(false);
      // Defensive: covers accounts created before profiles/households
      // existed. ensureUserProfile no-ops if both already exist.
      if (u) void ensureUserProfile(u);
    });
  }, []);

  return { user, checking };
}

function authErrorMessage(e: unknown): string {
  const code = e && typeof e === "object" && "code" in e ? String((e as { code: unknown }).code) : "";
  switch (code) {
    case "auth/email-already-in-use":
      return "Un compte existe déjà avec cet e-mail — connecte-toi plutôt.";
    case "auth/invalid-email":
      return "Adresse e-mail invalide.";
    case "auth/weak-password":
      return "Mot de passe trop court (6 caractères minimum).";
    case "auth/invalid-credential":
    case "auth/wrong-password":
    case "auth/user-not-found":
      return "E-mail ou mot de passe incorrect.";
    case "auth/too-many-requests":
      return "Trop de tentatives, réessaie dans un instant.";
    default:
      return "Une erreur est survenue, réessaie.";
  }
}

export async function signIn(email: string, password: string) {
  if (!auth) throw new Error("Firebase n'est pas configuré.");
  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (e) {
    throw new Error(authErrorMessage(e));
  }
}

export async function signUp(email: string, password: string, displayName: string) {
  if (!auth) throw new Error("Firebase n'est pas configuré.");
  try {
    const cred = await createUserWithEmailAndPassword(auth, email, password);
    await ensureUserProfile(cred.user, displayName);
  } catch (e) {
    throw new Error(authErrorMessage(e));
  }
}

export async function resetPassword(email: string) {
  if (!auth) throw new Error("Firebase n'est pas configuré.");
  try {
    await sendPasswordResetEmail(auth, email);
  } catch (e) {
    throw new Error(authErrorMessage(e));
  }
}

export async function signOut() {
  if (!auth) return;
  await firebaseSignOut(auth);
}
