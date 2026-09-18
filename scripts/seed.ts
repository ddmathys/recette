/**
 * One-time seed: pushes the 64 built-in recipes into Firestore so the app
 * switches from its read-only local fallback to the real shared library.
 *
 * Usage:
 *   1. Firebase console → Project settings → Service accounts → Generate new
 *      private key. Save the file as serviceAccountKey.json at the repo root
 *      (already gitignored).
 *   2. npm run seed
 *
 * Safe to re-run: it skips recipes that already exist (matched by name).
 */
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { SEED_RECIPES } from "../src/data/seed-recipes";

const keyPath = resolve(process.cwd(), "serviceAccountKey.json");

let serviceAccount: Record<string, unknown>;
try {
  serviceAccount = JSON.parse(readFileSync(keyPath, "utf8"));
} catch {
  console.error(
    `\nImpossible de lire ${keyPath}.\n` +
      "Télécharge une clé de compte de service depuis la console Firebase\n" +
      "(Project settings > Service accounts > Generate new private key)\n" +
      "et enregistre-la sous serviceAccountKey.json à la racine du projet.\n",
  );
  process.exit(1);
}

if (!getApps().length) {
  initializeApp({ credential: cert(serviceAccount) });
}
const db = getFirestore();

async function main() {
  const existing = await db.collection("recipes").select("name").get();
  const existingNames = new Set(existing.docs.map((d) => d.data().name));

  let added = 0;
  for (const recipe of SEED_RECIPES) {
    if (existingNames.has(recipe.name)) continue;
    const { id: _id, ...data } = recipe;
    void _id;
    await db.collection("recipes").add({
      ...data,
      createdAt: new Date().toISOString(),
    });
    added++;
  }

  console.log(`Terminé : ${added} recette(s) ajoutée(s), ${SEED_RECIPES.length - added} déjà présente(s).`);
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
