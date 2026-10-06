import { adminDb } from "./firebaseAdmin";

export const AI_DAILY_LIMIT = 40;
export const VISION_DAILY_LIMIT = 60;

export type AiRateLimitKind = "text" | "vision";

/** Simple per-user daily quota so a stray loop (or a shared link) can't run
 * up the AI bill. Firestore-backed since Vercel functions don't share
 * memory between invocations.
 *
 * `kind` picks the counter: "text" (default) is shared by /api/parse-recipe
 * and /api/edit-recipe (DeepSeek, same cost profile, one counter — same doc
 * id as before this parameter existed, so no migration needed). "vision" is
 * its own counter for /api/analyze-meal-photo (Gemini, logged much more
 * often than recipes are created, so it gets a separate, higher budget). */
export async function checkAiRateLimit(uid: string, kind: AiRateLimitKind = "text"): Promise<boolean> {
  const limit = kind === "vision" ? VISION_DAILY_LIMIT : AI_DAILY_LIMIT;
  return checkDailyQuota(kind === "vision" ? `${uid}_vision` : uid, limit);
}

/** Compteur journalier générique, une ligne `rateLimits/{docId}` par
 * compteur. Utilisé par les quotas IA (par uid) et par l'envoi de lien de
 * mot de passe oublié (par adresse e-mail, qui n'a pas d'uid connu à ce
 * moment-là). Ouvre en grand si l'admin SDK n'est pas configuré : mieux
 * vaut une fonctionnalité qui marche sans plafond qu'une fonctionnalité
 * cassée. */
export async function checkDailyQuota(docId: string, limit: number): Promise<boolean> {
  if (!adminDb) return true;
  const today = new Date().toISOString().slice(0, 10);
  const ref = adminDb.collection("rateLimits").doc(docId);
  return adminDb.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    if (!data || data.day !== today) {
      tx.set(ref, { day: today, count: 1 });
      return true;
    }
    if (data.count >= limit) return false;
    tx.update(ref, { count: data.count + 1 });
    return true;
  });
}
