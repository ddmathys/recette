import type { NutritionEstimate } from "./types";

/** Validates/coerces an AI (or Firestore) response into a NutritionEstimate,
 * or null if the shape is unusable — never let a malformed AI reply crash
 * the form or silently store garbage numbers. */
export function sanitizeNutrition(
  input: unknown,
  estimatedBy: NutritionEstimate["estimatedBy"] = "ai",
): NutritionEstimate | null {
  if (!input || typeof input !== "object") return null;
  const n = input as Record<string, unknown>;
  const kcal = Number(n.kcal);
  const proteinG = Number(n.proteinG);
  const carbsG = Number(n.carbsG);
  const fatG = Number(n.fatG);
  const gramsPerServing = Number(n.gramsPerServing);
  if (![kcal, proteinG, carbsG, fatG, gramsPerServing].every((v) => Number.isFinite(v) && v >= 0)) {
    return null;
  }
  return { kcal, proteinG, carbsG, fatG, gramsPerServing, estimatedBy };
}

/** Scales a per-serving nutrition estimate to an arbitrary portion size in
 * grams — used when logging a meal eaten from a recipe with a different
 * portion than the recipe's own `gramsPerServing`. */
export function scaleNutritionToGrams(nutrition: NutritionEstimate, portionGrams: number) {
  const ratio = nutrition.gramsPerServing > 0 ? portionGrams / nutrition.gramsPerServing : 1;
  return {
    kcal: Math.round(nutrition.kcal * ratio),
    proteinG: Math.round(nutrition.proteinG * ratio),
    carbsG: Math.round(nutrition.carbsG * ratio),
    fatG: Math.round(nutrition.fatG * ratio),
  };
}
