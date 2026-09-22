export type CategoryKey =
  | "petit-dejeuner"
  | "apero"
  | "salade"
  | "soupe"
  | "pates-riz"
  | "viande"
  | "poisson"
  | "vegetarien"
  | "dessert"
  | "sandwich";

export type Difficulty = "Facile" | "Moyen" | "Avancé";

export interface Ingredient {
  name: string;
  qty: string;
}

/** Estimation nutritionnelle pour une portion (une part servie, pas toute la
 * recette). Calculée par DeepSeek au moment du parse/edit — approximative
 * par nature, donc toujours éditable à la main (`estimatedBy` distingue
 * les deux origines, purement informatif). */
export interface NutritionEstimate {
  kcal: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  gramsPerServing: number;
  estimatedBy: "ai" | "manual";
}

export interface Recipe {
  id: string;
  name: string;
  cat: CategoryKey;
  time: number;
  diff: Difficulty;
  servings: number;
  veg: boolean;
  ingr: Ingredient[];
  steps: string[];
  note?: string | null;
  source?: string | null;
  photoUrl?: string | null;
  notes?: string;
  createdAt?: string;
  eatenDates?: string[];
  nutrition?: NutritionEstimate | null;
  /** Shared-library scope — see src/lib/useHousehold.ts. Recipes are only
   * visible to members of this household. Optional in the type only to
   * cover pre-migration data read by old cached code; every doc has it. */
  householdId?: string;
  ownerId?: string;
  /** Denormalized at write time so the "created by" badge doesn't need a
   * lookup per recipe. */
  ownerName?: string;
}

/** users/{uid} — one per account. householdId points at the shared pool
 * this account currently sees (its own uid by default, or another
 * member's uid once "sharing" is activated — see useHousehold.ts). */
export interface UserProfile {
  email: string;
  displayName: string;
  householdId: string;
  /** Objectif de kilocalories par jour, affiché sur le dashboard. Absent
   * pour les profils créés avant cette feature — 2000 est utilisé comme
   * valeur par défaut côté client dans ce cas (voir Dashboard.tsx). */
  dailyKcalGoal?: number;
}

/** households/{ownerId} — one per household, keyed by its creator's uid. */
export interface Household {
  ownerId: string;
  ownerEmail: string;
  members: string[];
}

export interface RecipeDraft {
  name: string;
  cat: CategoryKey;
  time: number;
  diff: Difficulty;
  servings: number;
  veg: boolean;
  ingr: Ingredient[];
  steps: string[];
  nutrition?: NutritionEstimate | null;
}

/** Repas mangé, éventuellement lié à une recette — journal alimentaire
 * indépendant de `Recipe.eatenDates` (qui n'est qu'une case à cocher par
 * recette, sans quantité ni valeurs nutritionnelles). Collection Firestore
 * top-level `mealLogs`, scopée par householdId comme `recipes`. */
export type MealType = "petit-dej" | "dejeuner" | "diner" | "collation";
export type MealSource = "manual" | "recipe" | "photo";

export interface MealLog {
  id: string;
  householdId: string;
  ownerId: string;
  ownerName: string;
  recipeId?: string | null;
  label: string;
  mealType: MealType;
  eatenAt: string;
  portionGrams: number;
  kcal: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  photoUrl?: string | null;
  source: MealSource;
  createdAt: string;
}

export interface MealLogDraft {
  recipeId?: string | null;
  label: string;
  mealType: MealType;
  eatenAt: string;
  portionGrams: number;
  kcal: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
}
