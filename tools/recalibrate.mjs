#!/usr/bin/env node
/**
 * Recalibre la difficulté du répertoire avec les réponses réelles.
 *
 *   node recalibrate.mjs --telemetry telemetrie.json [--min 200] [--apply]
 *
 * C'est la boucle qui rend le contenu plus juste avec l'usage, sans travail
 * humain (doc 03 §6, étape 5). Par défaut le script ne fait que proposer :
 * il écrit un rapport. `--apply` écrit dans le répertoire.
 *
 * Format de télémétrie attendu (un objet par lemme) :
 *   [{ "lemmaId": "es.salir", "attempts": 812, "successes": 402,
 *      "meanTheta": 38.4 }]
 *
 * Modèle : p(réussite) = 1 / (1 + e^((d − θ)/10)), donc la difficulté
 * observée vaut  d = θ − 10·ln(p / (1 − p)).
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

import { CEFR_SCORE, WEIGHTS, band, difficulty } from './lib/difficulty.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const arg = (n, d) => {
  const i = process.argv.indexOf(`--${n}`);
  return i === -1 ? d : process.argv[i + 1];
};

const lang = arg('lang', 'es');
const telemetryPath = arg('telemetry');
const minAttempts = Number(arg('min', '200'));
const apply = process.argv.includes('--apply');
const BLEND = 0.3; // on ne croit qu'à 30 % la mesure : elle est bruitée

if (!telemetryPath) {
  console.error('usage : node recalibrate.mjs --telemetry <fichier.json> [--min 200] [--apply]');
  process.exit(2);
}

const path = join(here, '..', 'content', lang, 'lexicon-seed.json');
const doc = JSON.parse(readFileSync(path, 'utf8'));
const byId = new Map(doc.lemmas.map((l) => [l.id, l]));
const telemetry = JSON.parse(readFileSync(telemetryPath, 'utf8'));

const rows = [];
let skipped = 0;

for (const t of telemetry) {
  const lemma = byId.get(t.lemmaId);
  if (!lemma) {
    console.warn(`⚠️  lemme inconnu, ignoré : ${t.lemmaId}`);
    continue;
  }
  if (t.attempts < minAttempts) {
    skipped++;
    continue;
  }
  // On borne le taux : 0 % et 100 % donnent une difficulté infinie.
  const p = Math.min(0.97, Math.max(0.03, t.successes / t.attempts));
  const observed = t.meanTheta - 10 * Math.log(p / (1 - p));
  const current = difficulty(lemma, WEIGHTS);
  const target = current * (1 - BLEND) + observed * BLEND;

  // Seule la fréquence absorbe la correction : le CECR, l'opacité, la
  // morphologie et le piège sont des faits, pas des estimations.
  const others =
    WEIGHTS.cefr * (CEFR_SCORE[lemma.cefr] ?? 50) +
    WEIGHTS.opacity * lemma.o +
    WEIGHTS.morphology * lemma.m +
    WEIGHTS.trap * lemma.t;
  const newF = Math.max(0, Math.min(100, (target - others) / WEIGHTS.frequency));

  rows.push({
    id: lemma.id,
    es: lemma.es,
    attempts: t.attempts,
    p: Number(p.toFixed(2)),
    current: Math.round(current),
    observed: Math.round(observed),
    target: Math.round(target),
    f: { from: lemma.f, to: Math.round(newF) },
    band: { from: band(current), to: band(target) },
  });
  if (apply) lemma.f = Math.round(newF);
}

rows.sort((a, b) => Math.abs(b.observed - b.current) - Math.abs(a.observed - a.current));

const report = {
  generatedAt: new Date().toISOString(),
  minAttempts,
  blend: BLEND,
  considered: telemetry.length,
  skippedForLackOfData: skipped,
  adjusted: rows.length,
  bandChanges: rows.filter((r) => r.band.from !== r.band.to).length,
  rows,
};
const reportPath = join(here, '..', 'content', lang, 'recalibration-report.json');
writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);

if (apply) {
  writeFileSync(path, `${JSON.stringify(doc, null, 2)}\n`);
  console.log(`✅ répertoire mis à jour — ${rows.length} lemme(s), ${report.bandChanges} changement(s) de palier`);
} else {
  console.log(`📋 proposition écrite dans ${reportPath} (aucune modification du répertoire)`);
  console.log(`   ${rows.length} lemme(s) recalibrable(s), ${skipped} sans assez de données`);
}
for (const r of rows.slice(0, 8)) {
  console.log(
    `   ${r.es.padEnd(16)} ${r.p * 100}% de réussite · ${r.current} → ${r.target}` +
      (r.band.from !== r.band.to ? ` (${r.band.from} → ${r.band.to})` : ''),
  );
}
