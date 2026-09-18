/**
 * One-off migration: creates David's profile + household, and backfills
 * every pre-existing recipe (created before the household/sharing feature
 * existed) with householdId/ownerId/ownerName so they belong to his
 * account. Safe to re-run (skips recipes that already have an ownerId).
 *
 * Usage: node scripts/migrate-household.mjs
 */
import { readFileSync } from "node:fs";
import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const DAVID_EMAIL = "david.mathys24@gmail.com";
const DAVID_NAME = "David";

const serviceAccount = JSON.parse(readFileSync(new URL("../serviceAccountKey.json", import.meta.url)));
if (!getApps().length) initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

async function main() {
  const { getAuth } = await import("firebase-admin/auth");
  const user = await getAuth().getUserByEmail(DAVID_EMAIL);
  const uid = user.uid;
  console.log(`David's uid: ${uid}`);

  await db.doc(`users/${uid}`).set(
    { email: DAVID_EMAIL, displayName: DAVID_NAME, householdId: uid },
    { merge: true },
  );
  await db.doc(`households/${uid}`).set(
    { ownerId: uid, ownerEmail: DAVID_EMAIL, members: [uid] },
    { merge: true },
  );
  console.log("Profile + household ready.");

  const snap = await db.collection("recipes").get();
  let migrated = 0;
  const batchSize = 400;
  let batch = db.batch();
  let inBatch = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.ownerId) continue; // already migrated
    batch.update(doc.ref, { householdId: uid, ownerId: uid, ownerName: DAVID_NAME });
    migrated++;
    inBatch++;
    if (inBatch >= batchSize) {
      await batch.commit();
      batch = db.batch();
      inBatch = 0;
    }
  }
  if (inBatch > 0) await batch.commit();

  console.log(`Migrated ${migrated} recipe(s) (of ${snap.size} total) to household ${uid}.`);
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
