import type { MealLog, MealLogDraft, MealType } from "./types";

/** Un repas déjà noté, reproposé "à l'unité" pour le renoter en un tap. */
export interface Habit {
  label: string;
  mealType: MealType;
  recipeId: string | null;
  /** Valeurs pour 1 unité (le repas noté divisé par son `count`). */
  portionGrams: number;
  kcal: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  times: number;
  lastAt: string;
}

/** Les repas notés le plus souvent (puis le plus récemment) par cet
 * utilisateur, éventuellement filtrés par type — base des raccourcis
 * "Tes habituels". Les estimations de journée sont exclues. */
export function computeHabits(logs: MealLog[], ownerId: string, mealType?: MealType, limit = 8): Habit[] {
  const byLabel = new Map<string, Habit>();
  // logs arrive du plus récent au plus ancien (orderBy eatenAt desc) : la
  // première occurrence d'un libellé donne les valeurs les plus récentes.
  for (const l of logs) {
    if (l.ownerId !== ownerId || l.source === "estimate") continue;
    if (mealType && l.mealType !== mealType) continue;
    const key = l.label.trim().toLowerCase();
    const existing = byLabel.get(key);
    if (existing) {
      existing.times += 1;
      continue;
    }
    const c = l.count && l.count > 0 ? l.count : 1;
    byLabel.set(key, {
      label: l.label.trim(),
      mealType: l.mealType,
      recipeId: l.recipeId ?? null,
      portionGrams: Math.round(l.portionGrams / c),
      kcal: Math.round(l.kcal / c),
      proteinG: Math.round(l.proteinG / c),
      carbsG: Math.round(l.carbsG / c),
      fatG: Math.round(l.fatG / c),
      times: 1,
      lastAt: l.eatenAt,
    });
  }
  return [...byLabel.values()].sort((a, b) => b.times - a.times || b.lastAt.localeCompare(a.lastAt)).slice(0, limit);
}

/** Toutes les habitudes de l'utilisateur, quel que soit le créneau où elles
 * ont été notées (un yaourt noté en collation reste proposé au petit-déj),
 * celles déjà mangées dans `slot` d'abord. `inSlot` = fois dans ce créneau. */
export function slotHabits(logs: MealLog[], ownerId: string, slot: MealType): (Habit & { inSlot: number })[] {
  const inSlot = new Map<string, number>();
  for (const l of logs) {
    if (l.ownerId !== ownerId || l.source === "estimate" || l.mealType !== slot) continue;
    const key = l.label.trim().toLowerCase();
    inSlot.set(key, (inSlot.get(key) ?? 0) + 1);
  }
  return computeHabits(logs, ownerId, undefined, Infinity)
    .map((h) => ({ ...h, inSlot: inSlot.get(h.label.toLowerCase()) ?? 0 }))
    .sort((a, b) => b.inSlot - a.inSlot || b.times - a.times || b.lastAt.localeCompare(a.lastAt));
}

/** Brouillon de repas pour `count` unités d'un habituel. */
export function habitToDraft(h: Habit, count: number, mealType: MealType, eatenAt: Date): MealLogDraft {
  return {
    recipeId: h.recipeId,
    label: h.label,
    mealType,
    eatenAt: eatenAt.toISOString(),
    portionGrams: Math.round(h.portionGrams * count),
    kcal: Math.round(h.kcal * count),
    proteinG: Math.round(h.proteinG * count),
    carbsG: Math.round(h.carbsG * count),
    fatG: Math.round(h.fatG * count),
    ...(count !== 1 ? { count } : {}),
  };
}

/** Totaux par jour (clé YYYY-MM-DD locale), pour l'évolution et
 * l'estimation d'une journée. */
export function dailyTotals(logs: MealLog[], dayKey: (d: Date) => string) {
  const days = new Map<string, { kcal: number; proteinG: number; carbsG: number; fatG: number; estimated: number }>();
  for (const l of logs) {
    const k = dayKey(new Date(l.eatenAt));
    const t = days.get(k) ?? { kcal: 0, proteinG: 0, carbsG: 0, fatG: 0, estimated: 0 };
    t.kcal += l.kcal;
    t.proteinG += l.proteinG;
    t.carbsG += l.carbsG;
    t.fatG += l.fatG;
    if (l.source === "estimate") t.estimated += l.kcal;
    days.set(k, t);
  }
  return days;
}
