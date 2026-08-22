#!/usr/bin/env node
/**
 * Recalcule les champs du répertoire qui n'ont aucune raison d'être annotés
 * à la main — aujourd'hui l'opacité orthographique (doc 03 §6, étape 3).
 *
 * Une valeur calculée ne peut pas être fausse ; une valeur saisie à la main
 * sur 3 000 entrées le sera forcément. Un lemme peut refuser le calcul en
 * passant `oManual: true` (cas rare : un mot opaque mais universellement
 * connu).
 *
 *   node normalize-lexicon.mjs es [--dry]
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

import { opacity, difficulty, band } from './lib/difficulty.mjs';

const lang = process.argv[2] ?? 'es';
const dry = process.argv.includes('--dry');
const here = dirname(fileURLToPath(import.meta.url));
const path = join(here, '..', 'content', lang, 'lexicon-seed.json');

const doc = JSON.parse(readFileSync(path, 'utf8'));
let changed = 0;
const moves = [];

for (const lemma of doc.lemmas) {
  if (lemma.oManual) continue;
  const before = band(difficulty(lemma));
  const computed = opacity(lemma.term, lemma.fr);
  if (computed !== lemma.o) {
    changed++;
    lemma.o = computed;
  }
  const after = band(difficulty(lemma));
  if (before !== after) moves.push(`${lemma.term} : ${before} → ${after}`);
}

if (dry) {
  console.log(`${changed} opacité(s) à recalculer, ${moves.length} changement(s) de palier`);
  for (const m of moves) console.log(`  ${m}`);
  process.exit(0);
}

writeFileSync(path, `${JSON.stringify(doc, null, 2)}\n`);
console.log(`✅ ${changed} opacité(s) recalculée(s), ${moves.length} changement(s) de palier`);
for (const m of moves) console.log(`   ${m}`);
