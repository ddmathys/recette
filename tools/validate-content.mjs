#!/usr/bin/env node
/**
 * Valide tout ce qui vit dans /content avant publication.
 *
 * Le schéma attrape les fautes de forme ; les règles sémantiques ci-dessous
 * attrapent les fautes qui coûtent cher : un item qui référence un mot
 * inexistant, une leçon qui ne travaille qu'une compétence, un exercice
 * d'écoute sans audio, ou du vocabulaire trop dur pour le tour.
 *
 *   node validate-content.mjs [--content ../content]
 */
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';

import { CityPackSchema } from './lib/schema.mjs';
import { band, bandIndex, difficulty, fold, opacity } from './lib/difficulty.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const contentDir =
  process.argv.includes('--content')
    ? process.argv[process.argv.indexOf('--content') + 1]
    : join(here, '..', 'content');

const problems = [];
const warnings = [];
const fail = (where, msg) => problems.push(`${where} — ${msg}`);
const warn = (where, msg) => warnings.push(`${where} — ${msg}`);

/* ------------------------------------------------------------------ */
/* 1. Le répertoire                                                     */
/* ------------------------------------------------------------------ */

function loadLexicon(lang) {
  const path = join(contentDir, lang, 'lexicon-seed.json');
  const raw = JSON.parse(readFileSync(path, 'utf8'));
  const seen = new Set();
  for (const l of raw.lemmas) {
    const where = `${relative(process.cwd(), path)} · ${l.id}`;
    if (seen.has(l.id)) fail(where, 'identifiant en double');
    seen.add(l.id);
    for (const f of ['f', 'o', 'm', 't']) {
      if (typeof l[f] !== 'number' || l[f] < 0 || l[f] > 100) {
        fail(where, `champ ${f} hors de [0, 100]`);
      }
    }
    if (!l.term || !l.fr || !l.cefr) fail(where, 'es, fr et cefr sont obligatoires');
    // L'opacité se calcule : si la valeur annotée s'en écarte trop, c'est
    // qu'elle a été saisie à la main ou hallucinée.
    const computed = opacity(l.term, l.fr);
    if (Math.abs(computed - l.o) > 35) {
      warn(where, `opacité annotée ${l.o}, calculée ${computed} — à revoir`);
    }
    if (l.t >= 70 && !l.note) {
      fail(where, 'un piège doit porter une note qui explique le piège');
    }
  }
  return raw.lemmas;
}

/* ------------------------------------------------------------------ */
/* 2. Les packs de ville                                                */
/* ------------------------------------------------------------------ */

function validatePack(path, pack, lexById, descriptors) {
  const rel = relative(process.cwd(), path);
  const parsed = CityPackSchema.safeParse(pack);
  if (!parsed.success) {
    for (const issue of parsed.error.issues) {
      fail(rel, `${issue.path.join('.') || '(racine)'} : ${issue.message}`);
    }
    return;
  }
  const p = parsed.data;
  const allItems = [
    ...p.lessons.flatMap((l) => l.items.map((i) => [l, i])),
    ...p.stampChallenge.items.map((i) => [p.stampChallenge, i]),
  ];

  const ids = new Set();
  for (const [, item] of allItems) {
    const where = `${rel} · ${item.id}`;
    if (ids.has(item.id)) fail(where, 'identifiant d item en double');
    ids.add(item.id);

    if (item.city !== p.cityId) fail(where, `city ${item.city} ≠ ${p.cityId}`);
    if (item.tour !== p.tour) fail(where, `tour ${item.tour} ≠ ${p.tour}`);
    if (!item.id.startsWith(`${p.lang}.${p.cityId}.t${p.tour}.`)) {
      fail(where, 'l identifiant doit refléter langue, ville et tour');
    }

    for (const c of item.canDo) {
      if (!descriptors.has(c)) fail(where, `descripteur inconnu : ${c}`);
    }

    // Un item ne peut pas s'appuyer sur un mot qui n'existe pas.
    for (const lex of item.lexemes) {
      const lemma = lexById.get(lex);
      if (!lemma) {
        fail(where, `lexème inconnu du répertoire : ${lex}`);
        continue;
      }
      // Contrôle du vocabulaire : on enseigne au-dessus du niveau, pas
      // deux paliers au-dessus (zone proximale, doc 03 §2.1).
      const maxBand = Math.min(5, p.tour + 1);
      if (bandIndex(band(difficulty(lemma))) > maxBand) {
        fail(
          where,
          `« ${lemma.term} » est en ${band(difficulty(lemma))}, trop dur pour le tour ${p.tour}`,
        );
      }
    }

    // Cohérence de la difficulté annoncée avec celle des mots utilisés.
    const lex = item.lexemes.map((id) => lexById.get(id)).filter(Boolean);
    if (lex.length) {
      const mean = lex.reduce((a, l) => a + difficulty(l), 0) / lex.length;
      if (Math.abs(mean - item.difficulty) > 30) {
        warn(
          where,
          `difficulté annoncée ${item.difficulty}, moyenne des lexèmes ${Math.round(mean)}`,
        );
      }
    }

    if (['listen', 'speak', 'dialogue'].includes(item.kind)) {
      if (!item.audioRef) fail(where, `un exercice ${item.kind} a besoin d un audioRef`);
      const spoken = item.audioText ?? (item.kind === 'speak' ? item.answer : null);
      if (!spoken) {
        fail(where, 'audioText manquant : rien à envoyer à la synthèse vocale');
      } else if (!/[áéíóúñü¿¡]|^[A-Za-z¿¡]/.test(spoken)) {
        warn(where, 'audioText ne ressemble pas à de l espagnol');
      }
    }
    if (item.audioText && item.kind === 'listen' && fold(item.audioText) === fold(item.answer)) {
      warn(where, 'l audio donne littéralement la réponse');
    }
    if (['mcq', 'listen'].includes(item.kind)) {
      if (item.options.length < 3) fail(where, 'au moins 3 propositions');
      if (!item.options.includes(item.answer)) {
        fail(where, 'la bonne réponse doit figurer dans les propositions');
      }
      const uniques = new Set(item.options.map(fold));
      if (uniques.size !== item.options.length) {
        fail(where, 'deux propositions identiques une fois normalisées');
      }
    }
    if (item.wordBank.length) {
      const bank = item.wordBank.map(fold);
      for (const token of item.answer.split(/\s+/).map(fold)) {
        if (!bank.includes(token)) {
          fail(where, `« ${token} » manque dans la banque de mots`);
        }
      }
      const distractors = item.wordBank.length - item.answer.split(/\s+/).length;
      if (distractors < 2) {
        warn(where, `seulement ${distractors} distracteur(s) — trop facile`);
      }
    }
    for (const alt of item.alternates) {
      if (fold(alt) === fold(item.answer)) {
        warn(where, 'une variante est identique à la réponse');
      }
    }
    if (item.skill === 'parler' && !['speak', 'dialogue'].includes(item.kind)) {
      fail(where, `compétence parler incompatible avec kind ${item.kind}`);
    }
    if (item.skill === 'ecouter' && item.kind !== 'listen') {
      fail(where, `compétence écouter incompatible avec kind ${item.kind}`);
    }
  }

  // Chaque leçon travaille les trois compétences (doc 02 §6).
  for (const lesson of p.lessons) {
    const where = `${rel} · ${lesson.id}`;
    const skills = new Set(lesson.items.map((i) => i.skill));
    for (const s of ['ecrire', 'parler', 'ecouter']) {
      if (!skills.has(s)) fail(where, `aucun exercice de compétence « ${s} »`);
    }
    const covered = new Set(lesson.items.flatMap((i) => i.canDo));
    for (const c of lesson.canDo) {
      if (!covered.has(c)) {
        fail(where, `le descripteur ${c} est annoncé mais aucun item ne le couvre`);
      }
    }
  }

  // L'épreuve de tampon est un vrai boss : au moins un oral.
  const stamp = p.stampChallenge.items;
  if (!stamp.some((i) => i.skill === 'parler')) {
    fail(`${rel} · épreuve`, 'une épreuve de tampon doit contenir un oral');
  }
  if (new Set(stamp.map((i) => i.skill)).size < 2) {
    fail(`${rel} · épreuve`, 'une épreuve doit mélanger au moins deux compétences');
  }
  if (!p.review.humanReviewed) {
    warn(rel, 'pack non relu par un humain — interdit en publication');
  }
  return p;
}

/* ------------------------------------------------------------------ */

function walk(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir).flatMap((name) => {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) return walk(full);
    // Seuls les packs sont validés ici : les brouillons d'annotation et les
    // fichiers générés (témoin de parité, rapports) suivent d'autres règles.
    return name.endsWith('.json') && full.includes(`${sep}packs${sep}`)
      ? [full]
      : [];
  });
}

const langs = readdirSync(contentDir).filter((n) =>
  statSync(join(contentDir, n)).isDirectory(),
);

const descriptorsPath = join(contentDir, 'cefr-descriptors.json');
const descriptors = new Set(
  Object.keys(JSON.parse(readFileSync(descriptorsPath, 'utf8')).descriptors),
);

let packCount = 0;
let itemCount = 0;
for (const lang of langs) {
  const lemmas = loadLexicon(lang);
  const byId = new Map(lemmas.map((l) => [l.id, l]));
  for (const file of walk(join(contentDir, lang))) {
    const pack = JSON.parse(readFileSync(file, 'utf8'));
    const ok = validatePack(file, pack, byId, descriptors);
    packCount++;
    if (ok) {
      itemCount +=
        ok.lessons.reduce((a, l) => a + l.items.length, 0) +
        ok.stampChallenge.items.length;
    }
  }
}

for (const w of warnings) console.warn(`⚠️  ${w}`);
for (const p of problems) console.error(`❌ ${p}`);

const summary = `${langs.length} langue(s) · ${packCount} pack(s) · ${itemCount} items`;
if (problems.length) {
  console.error(`\n${problems.length} erreur(s) · ${summary}`);
  process.exit(1);
}
console.log(`✅ Contenu valide — ${summary}${warnings.length ? ` · ${warnings.length} avertissement(s)` : ''}`);
