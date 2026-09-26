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
