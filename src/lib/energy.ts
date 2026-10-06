/** Besoin énergétique quotidien estimé à partir des mesures du profil.
 * Formule de Mifflin-St Jeor (celle utilisée par la plupart des trackers),
 * multipliée par un facteur d'activité, puis ajustée selon l'objectif de
 * poids. Le résultat est une *proposition* : l'objectif réellement utilisé
 * reste `UserProfile.dailyKcalGoal`, que l'utilisateur peut fixer à la main
 * à tout moment. */

export type Sex = "f" | "h";
export type ActivityKey = "sedentaire" | "leger" | "modere" | "actif" | "tres-actif";
export type AimKey = "perdre-vite" | "perdre" | "maintenir" | "prendre" | "prendre-vite";

export const ACTIVITIES: { key: ActivityKey; label: string; hint: string; factor: number }[] = [
  { key: "sedentaire", label: "Sédentaire", hint: "bureau, peu de marche", factor: 1.2 },
  { key: "leger", label: "Légère", hint: "un peu de marche, 1–2 séances/sem.", factor: 1.375 },
  { key: "modere", label: "Modérée", hint: "3–5 séances/sem.", factor: 1.55 },
  { key: "actif", label: "Soutenue", hint: "6–7 séances/sem.", factor: 1.725 },
  { key: "tres-actif", label: "Très intense", hint: "métier physique ou 2×/jour", factor: 1.9 },
];

export const AIMS: { key: AimKey; label: string; hint: string; delta: number }[] = [
  { key: "perdre-vite", label: "Perdre vite", hint: "≈ −0,7 kg/sem.", delta: -500 },
  { key: "perdre", label: "Perdre", hint: "≈ −0,3 kg/sem.", delta: -250 },
  { key: "maintenir", label: "Maintenir", hint: "stabiliser mon poids", delta: 0 },
  { key: "prendre", label: "Prendre", hint: "≈ +0,3 kg/sem.", delta: 250 },
  { key: "prendre-vite", label: "Prendre vite", hint: "≈ +0,7 kg/sem.", delta: 500 },
];

/** Planchers de sécurité usuels : on ne propose jamais un objectif sous ces
 * valeurs, même si l'objectif de perte le voudrait. */
const FLOOR: Record<Sex, number> = { f: 1200, h: 1500 };

export interface BodyMetrics {
  sex: Sex;
  birthYear: number;
  heightCm: number;
  weightKg: number;
  activity: ActivityKey;
  aim: AimKey;
}

export function activityMeta(key: ActivityKey | undefined) {
  return ACTIVITIES.find((a) => a.key === key) ?? ACTIVITIES[2];
}

export function aimMeta(key: AimKey | undefined) {
  return AIMS.find((a) => a.key === key) ?? AIMS[2];
}

export function ageFrom(birthYear: number, now: Date = new Date()): number {
  return now.getFullYear() - birthYear;
}

export interface EnergyResult {
  /** Métabolisme de base (au repos). */
  bmr: number;
  /** Dépense totale estimée, activité comprise. */
  tdee: number;
  /** Objectif proposé = tdee + ajustement de l'objectif de poids. */
  suggested: number;
  /** true si l'objectif a été relevé au plancher de sécurité. */
  floored: boolean;
}

/** Les mesures sont-elles complètes et plausibles ? (Un profil incomplet
 * n'affiche pas de proposition plutôt que d'afficher un chiffre faux.) */
export function metricsComplete(m: Partial<BodyMetrics> | null | undefined): m is BodyMetrics {
  if (!m) return false;
  const year = new Date().getFullYear();
  return (
    (m.sex === "f" || m.sex === "h") &&
    typeof m.birthYear === "number" &&
    m.birthYear >= year - 110 &&
    m.birthYear <= year - 10 &&
    typeof m.heightCm === "number" &&
    m.heightCm >= 100 &&
    m.heightCm <= 230 &&
    typeof m.weightKg === "number" &&
    m.weightKg >= 25 &&
    m.weightKg <= 400 &&
    ACTIVITIES.some((a) => a.key === m.activity) &&
    AIMS.some((a) => a.key === m.aim)
  );
}

export function computeEnergy(m: BodyMetrics, now: Date = new Date()): EnergyResult {
  const age = ageFrom(m.birthYear, now);
  const base = 10 * m.weightKg + 6.25 * m.heightCm - 5 * age + (m.sex === "h" ? 5 : -161);
  const bmr = Math.round(base);
  const tdee = Math.round(bmr * activityMeta(m.activity).factor);
  const raw = tdee + aimMeta(m.aim).delta;
  const floor = FLOOR[m.sex];
  return { bmr, tdee, suggested: Math.max(floor, Math.round(raw / 10) * 10), floored: raw < floor };
}
