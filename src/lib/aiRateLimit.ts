import { adminDb } from "./firebaseAdmin";

export const AI_DAILY_LIMIT = 40;

/** Simple per-user daily quota so a stray loop (or a shared link) can't run
 * up the DeepSeek bill. Firestore-backed since Vercel functions don't share
 * memory between invocations. Shared by /api/parse-recipe and
 * /api/edit-recipe — same cost profile, one counter. */
export async function checkAiRateLimit(uid: string): Promise<boolean> {
  if (!adminDb) return true; // no admin creds configured (shouldn't happen once auth is required) — fail open rather than break the feature
  const today = new Date().toISOString().slice(0, 10);
  const ref = adminDb.collection("rateLimits").doc(uid);
  return adminDb.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    if (!data || data.day !== today) {
      tx.set(ref, { day: today, count: 1 });
      return true;
    }
    if (data.count >= AI_DAILY_LIMIT) return false;
    tx.update(ref, { count: data.count + 1 });
    return true;
  });
}
