#!/usr/bin/env node
/**
 * Annote un lot de lemmes bruts issus d'une liste de fréquence.
 *
 *   ANTHROPIC_API_KEY=… node annotate-lexicon.mjs --input frequences-es.txt --from 0 --size 40
 *
 * L'opacité n'est PAS demandée à l'IA : elle se calcule (normalize-lexicon).
 * On ne demande à un modèle que ce qu'un calcul ne sait pas faire.
 *
 * La sortie va dans `content/{lang}/lexicon-draft-{n}.json`, jamais
 * directement dans le répertoire : la revue humaine est une étape du
 * pipeline, pas une option.
 */
import Anthropic from '@anthropic-ai/sdk';
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { z } from 'zod';

import { opacity } from './lib/difficulty.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const arg = (n, d) => {
  const i = process.argv.indexOf(`--${n}`);
  return i === -1 ? d : process.argv[i + 1];
};

const lang = arg('lang', 'es');
const input = arg('input');
const from = Number(arg('from', '0'));
const size = Number(arg('size', '40'));

if (!input || !existsSync(input)) {
  console.error('usage : node annotate-lexicon.mjs --input <liste.txt> [--from 0] [--size 40]');
  process.exit(2);
}

const words = readFileSync(input, 'utf8')
  .split('\n')
  .map((l) => l.trim())
  .filter(Boolean)
  .slice(from, from + size);

const Annotated = z.object({
  lemmas: z.array(
    z.object({
      es: z.string(),
      fr: z.string(),
      pos: z.enum(['nom', 'verbe', 'adj', 'adv', 'interj', 'conj', 'prep', 'loc', 'pron']),
      cefr: z.enum(['A1', 'A2', 'B1', 'B2', 'C1']),
      f: z.number().min(0).max(100),
      m: z.number().min(0).max(100),
      t: z.number().min(0).max(100),
      themes: z.array(z.string()),
      city: z.string().nullable(),
      note: z.string().nullable(),
    }),
  ),
});

const client = new Anthropic();

const response = await client.messages.parse({
  model: 'claude-opus-5',
  max_tokens: 16000,
  thinking: { type: 'adaptive' },
  output_config: { effort: 'high', format: zodOutputFormat(Annotated) },
  system: [
    {
      type: 'text',
      text: `Tu annotes un répertoire de vocabulaire espagnol destiné à des apprenants FRANCOPHONES. Pour chaque mot :

- \`fr\` : la traduction la plus courante, en une ou deux formulations séparées par « / ».
- \`pos\` : la nature grammaticale.
- \`cefr\` : le niveau où ce mot devient utile (A1 = survie, C1 = subtilité).
- \`f\` : difficulté de fréquence, 0 = parmi les 100 mots les plus fréquents, 100 = rare. Fie-toi à l'ordre de la liste fournie, qui est un classement de fréquence.
- \`m\` : irrégularité morphologique (verbe irrégulier, genre inattendu, pluriel piégeux). 0 = parfaitement régulier.
- \`t\` : piège pour un francophone. 0 = aucun. 70 ou plus UNIQUEMENT pour un vrai faux-ami ou une construction qui inverse la logique française (gustar, doler). Sois strict : marquer trop de pièges les rend invisibles.
- \`themes\` : un à trois thèmes en français, minuscules, sans accent (restaurant, marche, transport, sport, sante, abstrait…).
- \`city\` : \`valencia\`, \`madrid\`, \`sevilla\`, \`granada\`, \`bilbao\` ou \`barcelona\` si le mot est vraiment caractéristique de cette ville ; \`null\` sinon. Sois avare : la plupart des mots sont \`null\`.
- \`note\` : obligatoire si \`t\` ≥ 70, sinon \`null\`. Une phrase en français qui explique le piège à un apprenant, sans jargon.

Ne calcule pas l'opacité orthographique : elle est calculée ailleurs.
Réponds pour tous les mots, dans l'ordre reçu.`,
      cache_control: { type: 'ephemeral' },
    },
  ],
  messages: [
    { role: 'user', content: `Annote ces ${words.length} mots :\n\n${words.join('\n')}` },
  ],
});

if (!response.parsed_output) {
  console.error('Réponse non conforme au schéma — rien n\'a été écrit.');
  process.exit(1);
}

const slug = (es) => `${lang}.${es.toLowerCase().normalize('NFD').replace(/[^a-z0-9]/g, '')}`;
const lemmas = response.parsed_output.lemmas.map((l) => ({
  id: slug(l.es),
  ...l,
  o: opacity(l.es, l.fr), // calculé, pas annoté
}));

const out = join(here, '..', 'content', lang, `lexicon-draft-${from}.json`);
writeFileSync(out, `${JSON.stringify({ lemmas }, null, 2)}\n`);

const traps = lemmas.filter((l) => l.t >= 70);
console.log(`✍️  ${out} — ${lemmas.length} lemmes, ${traps.length} piège(s)`);
if (traps.length) console.log(`   à relire en priorité : ${traps.map((l) => l.es).join(', ')}`);
console.log('   puis : relire 5 % au hasard, fusionner dans lexicon-seed.json, npm run validate');
