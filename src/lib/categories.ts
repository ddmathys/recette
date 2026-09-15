import type { CategoryKey } from "./types";

export interface CategoryMeta {
  key: CategoryKey;
  label: string;
  color: string;
  /** Inner SVG path markup for the category icon (viewBox 0 0 24 24). */
  icon: string;
}

export const CATEGORIES: CategoryMeta[] = [
  {
    key: "petit-dejeuner",
    label: "Petit-déjeuner",
    color: "#C98A3E",
    icon: '<path d="M5 10h11v5a4 4 0 0 1-4 4H9a4 4 0 0 1-4-4v-5z"/><path d="M16 11h1.5a2 2 0 1 1 0 4H16"/><path d="M8 6c0-.8.6-1 .6-1.8M12 6c0-.8.6-1 .6-1.8"/>',
  },
  {
    key: "apero",
    label: "Apéro & snack",
    color: "#B2562F",
    icon: '<path d="M4 11h16a8 8 0 0 1-16 0z"/><circle cx="9" cy="9" r="1" fill="currentColor" stroke="none"/><circle cx="12" cy="7.6" r="1" fill="currentColor" stroke="none"/><circle cx="15" cy="9" r="1" fill="currentColor" stroke="none"/>',
  },
  {
    key: "salade",
    label: "Salade",
    color: "#5B7A3A",
    icon: '<path d="M6 18C6 10 12 5 19 5c0 7-5 13-13 13z"/><path d="M8 16 17 7"/>',
  },
  {
    key: "soupe",
    label: "Soupe",
    color: "#A8462E",
    icon: '<path d="M4 11h16v3a6 6 0 0 1-6 6h-4a6 6 0 0 1-6-6v-3z"/><path d="M2 11h20"/><path d="M8 8c0-1 1-1 1-2M12 8c0-1 1-1 1-2M16 8c0-1 1-1 1-2"/>',
  },
  {
    key: "pates-riz",
    label: "Pâtes & riz",
    color: "#C9A227",
    icon: '<path d="M12 4a8 8 0 1 0 8 8 6 6 0 1 0-6 6 4 4 0 1 0 4-4"/>',
  },
  {
    key: "viande",
    label: "Viande",
    color: "#8B3A3A",
    icon: '<path d="M3 12h18"/><rect x="5.5" y="9" width="3.4" height="6" rx="1.2"/><circle cx="13" cy="12" r="2.3"/><rect x="15.1" y="9" width="3.4" height="6" rx="1.2"/>',
  },
  {
    key: "poisson",
    label: "Poisson",
    color: "#3E7C8A",
    icon: '<path d="M3 12c3-4 8-6 12-4-1 2-1 6 0 8-4 2-9 0-12-4z"/><circle cx="7" cy="11" r=".7" fill="currentColor" stroke="none"/><path d="M15 10l4-2v8l-4-2"/>',
  },
  {
    key: "vegetarien",
    label: "Végétarien",
    color: "#6B8E4E",
    icon: '<path d="M12 21V11"/><path d="M12 11C12 6 8 5 5 5c0 4 2 6 7 6z"/><path d="M12 14c0-4 4-5 7-5 0 4-2 6-7 5z"/>',
  },
  {
    key: "dessert",
    label: "Dessert",
    color: "#A9567A",
    icon: '<path d="M4 18 12 6l8 12z"/><path d="M4 18h16"/><path d="M9 13h6"/><circle cx="12" cy="6" r="1" fill="currentColor" stroke="none"/>',
  },
  {
    key: "sandwich",
    label: "Sandwich & wrap",
    color: "#8A6A3E",
    icon: '<path d="M4 19 12 5l8 14z"/><path d="M6.5 14.5h11"/><path d="M8 11.5h8" stroke-dasharray="1.6 1.6"/>',
  },
];

export const CATEGORY_BY_KEY: Record<CategoryKey, CategoryMeta> = CATEGORIES.reduce(
  (acc, c) => {
    acc[c.key] = c;
    return acc;
  },
  {} as Record<CategoryKey, CategoryMeta>,
);
