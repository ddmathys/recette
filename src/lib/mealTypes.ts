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
