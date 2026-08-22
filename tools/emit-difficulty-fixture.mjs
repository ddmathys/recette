#!/usr/bin/env node
/**
 * Émet (ou vérifie) le témoin de parité de la formule de difficulté.
 *
 * La formule existe deux fois : ici en JavaScript pour le pipeline, et en
 * Dart dans le moteur. Ce fichier est le contrat entre les deux — le test
 * `parite_formule` du moteur le relit et compare. Si quelqu'un change un
 * poids d'un seul côté, un des deux casse.
 *
 *   node emit-difficulty-fixture.mjs es          # écrit
 *   node emit-difficulty-fixture.mjs es --check  # vérifie (CI)
 */
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

import { WEIGHTS, difficulty, band } from './lib/difficulty.mjs';

const lang = process.argv[2] ?? 'es';
const check = process.argv.includes('--check');
const here = dirname(fileURLToPath(import.meta.url));
const src = join(here, '..', 'content', lang, 'lexicon-seed.json');
const out = join(here, '..', 'content', lang, 'difficulty-fixture.json');

const lemmas = JSON.parse(readFileSync(src, 'utf8')).lemmas;
const fixture = {
  note: 'Généré par tools/emit-difficulty-fixture.mjs — ne pas éditer à la main.',
  weights: WEIGHTS,
  difficulties: Object.fromEntries(
    lemmas.map((l) => [l.id, Number(difficulty(l).toFixed(4))]),
  ),
  bands: Object.fromEntries(lemmas.map((l) => [l.id, band(difficulty(l))])),
};
const serialized = `${JSON.stringify(fixture, null, 2)}\n`;

if (check) {
  if (!existsSync(out)) {
    console.error(`❌ ${out} manquant — lance : node emit-difficulty-fixture.mjs ${lang}`);
    process.exit(1);
  }
  if (readFileSync(out, 'utf8') !== serialized) {
    console.error(
      `❌ ${out} est périmé — le répertoire ou les poids ont changé.\n` +
        `   Relance : node emit-difficulty-fixture.mjs ${lang}`,
    );
    process.exit(1);
  }
  console.log(`✅ témoin de parité à jour (${lemmas.length} lemmes)`);
} else {
  writeFileSync(out, serialized);
  console.log(`✅ ${out} — ${lemmas.length} lemmes`);
}
