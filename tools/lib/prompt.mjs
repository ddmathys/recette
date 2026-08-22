import { band, bandIndex, difficulty } from './difficulty.mjs';

/**
 * Le prompt de génération. Volontairement dans un fichier à part : c'est le
 * paramètre le plus sensible du pipeline, et il doit être relu comme du code.
 *
 * Principe : on ne demande pas à Claude d'« inventer une leçon d'espagnol ».
 * On lui donne le vocabulaire autorisé, les descripteurs à couvrir, les
 * contraintes de forme, et on lui interdit tout le reste. La qualité vient de
 * la contrainte, pas de la créativité.
 */
export function systemPrompt({ descriptors, allowedLemmas, weights }) {
  const vocab = allowedLemmas
    .map((l) => `${l.id} · ${l.term} = ${l.fr} [${band(difficulty(l, weights))}]${l.note ? ` — ${l.note}` : ''}`)
    .join('\n');
  const cando = Object.entries(descriptors)
    .map(([id, text]) => `${id} : ${text}`)
    .join('\n');

  return `Tu écris le contenu pédagogique de Kameo, une application qui enseigne une langue en faisant voyager l'utilisateur de ville en ville. Le public est francophone (Suisse romande et France), de 8 à 99 ans, familial.

# Ce qui rend Kameo différent
Chaque ville enseigne ses spécificités culturelles et linguistiques. On n'apprend pas des listes de mots : on apprend à commander, à acheter, à dire que c'est bon. Le contenu doit sentir le lieu — un exercice de Valence parle de paella et du marché, pas de « la maison de mon oncle ».

# Contraintes absolues
1. **Vocabulaire fermé.** Tu n'utilises QUE les lemmes de la liste ci-dessous dans les phrases espagnoles. Les mots grammaticaux courants (articles, prépositions, pronoms, conjugaisons des verbes listés) sont autorisés. Tout autre mot de contenu est interdit — c'est ce qui garantit qu'un débutant comprend.
2. **Chaque leçon travaille les trois compétences** : au moins un exercice \`ecrire\`, un \`parler\`, un \`ecouter\`.
3. **Cohérence compétence / type** : \`parler\` → kind \`speak\` ou \`dialogue\` ; \`ecouter\` → kind \`listen\` ; \`ecrire\` → \`translate\`, \`gap\` ou \`mcq\`.
4. **Tout exercice oral ou d'écoute porte un \`audioText\`** : la phrase espagnole exacte à faire dire par la synthèse vocale, avec ses accents et sa ponctuation (¿ ¡ inclus).
5. **Les QCM ont au moins trois propositions**, dont la bonne réponse, et les mauvaises doivent être plausibles — jamais absurdes.
6. **Les exercices \`translate\` avec banque de mots** listent dans \`wordBank\` tous les mots de la réponse plus au moins deux distracteurs crédibles.
7. **\`note\` explique le piège ou la règle**, en une phrase, en français, sans jargon. C'est ce que l'utilisateur lit après s'être trompé : elle doit apprendre quelque chose, pas répéter la correction.
8. **\`canDo\`** ne contient que des descripteurs de la liste ci-dessous.
9. **Identifiants** : \`{lang}.{ville}.t{tour}.{theme}.{NN}\`, numérotés en continu sur tout le pack.
10. **Espagnol d'Espagne** (castillan), registre courant, tutoiement quand c'est naturel. Jamais de calque du français.

# Descripteurs disponibles
${cando}

# Vocabulaire autorisé
${vocab}

# Ce qu'on ne veut pas
- Des phrases scolaires sans contexte (« El libro está en la mesa »).
- Des traductions mot à mot du français.
- Des notes qui répètent la réponse au lieu d'expliquer.
- Des exercices où la bonne réponse est devinable par élimination sans connaître l'espagnol.`;
}

export function userPrompt({ cityName, cityId, theme, tour, cefr, lessons, itemsPerLesson }) {
  return `Écris le pack de ${cityName} (\`${cityId}\`), tour ${tour}, niveau ${cefr}.

Spécificité de la ville : ${theme}.

Il faut :
- ${lessons} leçons thématiques de ${itemsPerLesson} exercices chacune, liées à la spécificité de la ville ;
- une expression locale authentique, avec sa traduction et une note qui explique quand on l'emploie sur place ;
- une épreuve de tampon de 3 à 5 exercices, mélangeant au moins deux compétences dont un oral, qui rejoue ce que les leçons ont enseigné.

Chaque exercice doit pouvoir servir dans une vraie situation à ${cityName}.`;
}

export function allowedLemmasFor(lemmas, { tour, cityId, weights, max = 120 }) {
  const maxBand = Math.min(5, tour + 1);
  return lemmas
    .filter((l) => bandIndex(band(difficulty(l, weights))) <= maxBand)
    .filter((l) => !l.city || l.city === cityId)
    .sort((a, b) => difficulty(a, weights) - difficulty(b, weights))
    .slice(0, max);
}
