#!/usr/bin/env node
/**
 * Génère un pack de ville avec Claude, sous schéma strict.
 *
 *   ANTHROPIC_API_KEY=… node generate-pack.mjs --city valencia --tour 1
 *
 * Ce que le script NE fait pas, volontairement : publier. Il écrit dans
 * `content/{lang}/packs/{date}_draft/` avec `humanReviewed: false`. La revue
 * humaine — et celle d'un natif pour les expressions locales — reste une
 * étape obligatoire (doc 03 §6, doc 10 des risques).
 */
import Anthropic from '@anthropic-ai/sdk';
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

import { GeneratedPackSchema } from './lib/schema.mjs';
import { WEIGHTS } from './lib/difficulty.mjs';
import { systemPrompt, userPrompt, allowedLemmasFor } from './lib/prompt.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const arg = (name, fallback) => {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? fallback : process.argv[i + 1];
};

const lang = arg('lang', 'es');
const cityId = arg('city');
const tour = Number(arg('tour', '1'));
const lessons = Number(arg('lessons', '3'));
const itemsPerLesson = Number(arg('items', '5'));

if (!cityId) {
  console.error('usage : node generate-pack.mjs --city valencia [--tour 1] [--lessons 3] [--items 5]');
  process.exit(2);
}

const CITIES = {
  barcelona: { name: 'Barcelone', theme: 'la mer, l\'art et l\'accueil catalan', country: 'espana' },
  valencia: { name: 'Valence', theme: 'la cuisine, le riz et le marché central', country: 'espana' },
  granada: { name: 'Grenade', theme: 'les tapas offertes et l\'héritage andalou', country: 'espana' },
  sevilla: { name: 'Séville', theme: 'la fête, le flamenco et la chaleur', country: 'espana' },
  madrid: { name: 'Madrid', theme: 'la vie urbaine, le métro et la nuit', country: 'espana' },
  bilbao: { name: 'Bilbao', theme: 'le football, les pintxos et la pluie', country: 'espana' },
};
const CEFR_BY_TOUR = { 1: 'A1', 2: 'A2', 3: 'B1', 4: 'B2', 5: 'C1' };

const city = CITIES[cityId];
if (!city) {
  console.error(`ville inconnue : ${cityId} (${Object.keys(CITIES).join(', ')})`);
  process.exit(2);
}

const contentDir = join(here, '..', 'content');
const lemmas = JSON.parse(
  readFileSync(join(contentDir, lang, 'lexicon-seed.json'), 'utf8'),
).lemmas;
const descriptors = JSON.parse(
  readFileSync(join(contentDir, 'cefr-descriptors.json'), 'utf8'),
).descriptors;

const allowed = allowedLemmasFor(lemmas, { tour, cityId, weights: WEIGHTS });
const forTour = Object.fromEntries(
  Object.entries(descriptors).filter(([id]) => id.startsWith(CEFR_BY_TOUR[tour])),
);

console.log(
  `${city.name} · tour ${tour} · ${CEFR_BY_TOUR[tour]} — ${allowed.length} lemmes autorisés, ` +
    `${Object.keys(forTour).length} descripteurs`,
);

const client = new Anthropic();

const response = await client.messages.parse({
  model: 'claude-opus-5',
  max_tokens: 16000,
  thinking: { type: 'adaptive' },
  output_config: {
    effort: 'high',
    format: zodOutputFormat(GeneratedPackSchema),
  },
  system: [
    {
      type: 'text',
      // Le prompt système et la liste de vocabulaire sont stables d'une ville
      // à l'autre du même tour : on les met en cache, la ville suivante ne
      // repaie que sa propre requête.
      text: systemPrompt({ descriptors: forTour, allowedLemmas: allowed, weights: WEIGHTS }),
      cache_control: { type: 'ephemeral' },
    },
  ],
  messages: [
    {
      role: 'user',
      content: userPrompt({
        cityName: city.name,
        cityId,
        theme: city.theme,
        tour,
        cefr: CEFR_BY_TOUR[tour],
        lessons,
        itemsPerLesson,
      }),
    },
  ],
});

if (response.stop_reason === 'refusal') {
  console.error('Génération refusée :', response.stop_details?.explanation ?? '(sans détail)');
  process.exit(1);
}
if (!response.parsed_output) {
  console.error('Réponse non conforme au schéma — rien n\'a été écrit.');
  process.exit(1);
}

const pack = {
  ...response.parsed_output,
  review: {
    generatedBy: `${response.model} · ${new Date().toISOString().slice(0, 10)}`,
    generatedAt: new Date().toISOString(),
    humanReviewed: false,
    nativeReviewer: null,
  },
};

const outDir = join(
  contentDir,
  lang,
  'packs',
  `${new Date().toISOString().slice(0, 10)}_draft`,
);
mkdirSync(outDir, { recursive: true });
const outFile = join(outDir, `${cityId}.t${tour}.json`);
writeFileSync(outFile, `${JSON.stringify(pack, null, 2)}\n`);

const u = response.usage;
console.log(`✍️  ${outFile}`);
console.log(
  `   ${pack.lessons.length} leçons · ` +
    `${pack.lessons.reduce((a, l) => a + l.items.length, 0) + pack.stampChallenge.items.length} items · ` +
    `${u.input_tokens} in / ${u.output_tokens} out` +
    (u.cache_read_input_tokens ? ` · ${u.cache_read_input_tokens} lus en cache` : ''),
);
console.log('\nÉtapes suivantes, dans cet ordre :');
console.log('  1. npm run validate            — la forme et les règles pédagogiques');
console.log('  2. relire les phrases espagnoles, et faire relire les expressions locales par un natif');
console.log('  3. passer humanReviewed à true et déplacer le dossier en _v{n} pour publier');
