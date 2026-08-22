/**
 * La formule de difficulté du doc 03 §2.
 *
 * Elle est dupliquée ici et dans packages/kameo_engine/lib/src/models.dart —
 * c'est volontaire : le pipeline Node ne doit pas dépendre du SDK Dart. Le
 * test `parite_formule` du moteur vérifie que les deux donnent le même
 * résultat sur le fichier semence, donc la duplication ne peut pas dériver
 * en silence.
 */
export const WEIGHTS = {
  frequency: 0.45,
  cefr: 0.2,
  opacity: 0.15,
  morphology: 0.1,
  trap: 0.1,
};

export const CEFR_SCORE = { A1: 0, A2: 30, B1: 60, B2: 80, C1: 100 };

export const BANDS = [
  ['P1', 0, 20],
  ['P2', 20, 35],
  ['P3', 35, 50],
  ['P4', 50, 65],
  ['P5', 65, 80],
  ['P6', 80, 101],
];

export function difficulty(lemma, weights = WEIGHTS) {
  return (
    weights.frequency * lemma.f +
    weights.cefr * (CEFR_SCORE[lemma.cefr] ?? 50) +
    weights.opacity * lemma.o +
    weights.morphology * lemma.m +
    weights.trap * lemma.t
  );
}

export function band(value) {
  for (const [name, min, max] of BANDS) {
    if (value >= min && value < max) return name;
  }
  return value < 0 ? 'P1' : 'P6';
}

export function bandIndex(name) {
  return BANDS.findIndex(([n]) => n === name);
}

/**
 * Opacité orthographique : distance de Levenshtein normalisée entre le mot
 * espagnol et sa traduction française, accents pliés.
 *
 * Ce champ n'est PAS annoté par l'IA — il se calcule. Une valeur calculée ne
 * peut pas être fausse, une valeur annotée si (doc 03 §6, étape 3).
 */
export function opacity(es, fr) {
  const a = fold(es);
  const b = fold(fr.split(/[/,(]/)[0].trim());
  if (!a.length || !b.length) return 100;
  const d = levenshtein(a, b);
  return Math.round((d / Math.max(a.length, b.length)) * 100);
}

const FOLD = {
  á: 'a', à: 'a', â: 'a', ä: 'a', é: 'e', è: 'e', ê: 'e', ë: 'e',
  í: 'i', ì: 'i', î: 'i', ï: 'i', ó: 'o', ò: 'o', ô: 'o', ö: 'o',
  ú: 'u', ù: 'u', û: 'u', ü: 'u', ñ: 'n', ç: 'c', œ: 'oe',
};

export function fold(s) {
  return s
    .toLowerCase()
    .split('')
    .map((c) => FOLD[c] ?? c)
    .join('')
    .replace(/[^a-z0-9 ]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function levenshtein(a, b) {
  let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const row = [i];
    for (let j = 1; j <= b.length; j++) {
      row[j] = Math.min(
        prev[j] + 1,
        row[j - 1] + 1,
        prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    }
    prev = row;
  }
  return prev[b.length];
}
