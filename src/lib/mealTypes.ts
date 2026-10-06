import type { CategoryKey, MealType } from "./types";

/** Les 4 moments de la journée, dans l'ordre d'affichage du dashboard.
 * `emoji`/`color` servent à l'anneau segmenté et aux cartes de créneau,
 * `cats` aux recettes mises en avant quand on remplit ce créneau. */
export const MEAL_TYPES: {
  key: MealType;
  label: string;
  short: string;
  emoji: string;
  color: string;
  cats: CategoryKey[];
}[] = [
  { key: "petit-dej", label: "Petit-déjeuner", short: "Petit-déj", emoji: "☕", color: "#F2A600", cats: ["petit-dejeuner"] },
  { key: "dejeuner", label: "Déjeuner", short: "Déjeuner", emoji: "🍽️", color: "#FF5A36", cats: ["salade", "sandwich", "pates-riz", "soupe"] },
  { key: "diner", label: "Dîner", short: "Dîner", emoji: "🌙", color: "#17A2B8", cats: ["viande", "poisson", "vegetarien", "pates-riz", "soupe"] },
  { key: "collation", label: "Collation", short: "En-cas", emoji: "🍎", color: "#1FA876", cats: ["apero", "dessert"] },
];

export function mealTypeLabel(key: string): string {
  return MEAL_TYPES.find((m) => m.key === key)?.label ?? "Repas";
}

export function mealTypeMeta(key: MealType) {
  return MEAL_TYPES.find((m) => m.key === key) ?? MEAL_TYPES[1];
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
