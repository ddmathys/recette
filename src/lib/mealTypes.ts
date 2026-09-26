import type { MealType } from "./types";

export const MEAL_TYPES: { key: MealType; label: string }[] = [
  { key: "petit-dej", label: "Petit-déjeuner" },
  { key: "dejeuner", label: "Déjeuner" },
  { key: "diner", label: "Dîner" },
  { key: "collation", label: "Collation" },
];

export function mealTypeLabel(key: string): string {
  return MEAL_TYPES.find((m) => m.key === key)?.label ?? "Repas";
}

/** Devine un type de repas plausible à partir de l'heure actuelle, pour
 * pré-remplir le formulaire sans forcer l'utilisateur à y penser. */
export function guessMealType(date: Date = new Date()): MealType {
  const h = date.getHours();
  if (h < 10) return "petit-dej";
  if (h < 15) return "dejeuner";
  if (h < 21) return "diner";
  return "collation";
}

const TYPICAL_HOUR: Record<MealType, [number, number]> = {
  "petit-dej": [8, 0],
  dejeuner: [12, 30],
  collation: [16, 0],
  diner: [19, 30],
};

/** Moment à enregistrer pour un repas ajouté sur le jour affiché au
 * dashboard : maintenant si c'est aujourd'hui, sinon ce jour-là à une heure
 * typique du type de repas (ex. "hier, dîner" → hier 19:30). */
export function eatenAtFor(day: Date, mealType: MealType): Date {
  const now = new Date();
  if (day.toDateString() === now.toDateString()) return now;
  const [h, m] = TYPICAL_HOUR[mealType];
  const d = new Date(day);
  d.setHours(h, m, 0, 0);
  return d;
}

/** "Aujourd'hui", "Hier" ou "jeu. 24 sept." */
export function dayLabel(day: Date): string {
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);
  if (day.toDateString() === today.toDateString()) return "Aujourd'hui";
  if (day.toDateString() === yesterday.toDateString()) return "Hier";
  return day.toLocaleDateString("fr-CH", { weekday: "short", day: "numeric", month: "short" });
}

export function localDayKey(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}
