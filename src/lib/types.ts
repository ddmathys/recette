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
