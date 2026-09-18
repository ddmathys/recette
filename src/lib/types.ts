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
}
