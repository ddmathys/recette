"use client";

import { useMemo, useState } from "react";
import { addMealLog } from "@/lib/useMealLogs";
import { computeHabits, habitToDraft, type Habit } from "@/lib/habits";
import { dayLabel, eatenAtFor, mealTypeMeta } from "@/lib/mealTypes";
import { HabitsList } from "./HabitsList";
import type { MealLog, MealType, Recipe } from "@/lib/types";

/**
 * Écran « + » d'un créneau du dashboard (petit-déj, déjeuner, dîner,
 * collation) : tout ce qu'on peut y mettre, du plus rapide au plus long —
 * les habituels déjà notés (1 tap), les recettes de la bibliothèque
 * (recherche + portion), puis photo / description pour un plat inconnu.
 * Chaque ajout est noté sur le jour affiché au dashboard et dans ce créneau.
 */
export function AddToSlotSheet({
  slot,
  day,
  recipes,
  logs,
  owner,
  onClose,
  onPhoto,
  onDescribe,
  onOpenRecipe,
  onOpenLibrary,
}: {
  slot: MealType;
  day: Date;
  recipes: Recipe[];
  logs: MealLog[];
  owner: { uid: string; name: string; householdId: string };
  onClose: () => void;
  /** Photo d'assiette → analyse IA, notée dans ce créneau. */
  onPhoto: () => void;
  /** Description libre → estimation IA, notée dans ce créneau. */
  onDescribe: () => void;
  /** Recette sans estimation nutritionnelle : on passe par l'écran complet. */
  onOpenRecipe: (recipe: Recipe) => void;
  onOpenLibrary: () => void;
}) {
  const meta = mealTypeMeta(slot);
  const habits = useMemo(() => computeHabits(logs, owner.uid, slot, 6), [logs, owner.uid, slot]);
  const [search, setSearch] = useState("");
  const [added, setAdded] = useState<{ label: string; kcal: number }[]>([]);
  const [showAll, setShowAll] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);

  // Les recettes du créneau d'abord (petit-déjeuner le matin, apéro/dessert
  // pour une collation…), puis les plus récentes — on retrouve d'un coup
  // d'œil ce qu'on mange d'habitude à ce moment-là.
  const list = useMemo(() => {
    const q = search.trim().toLowerCase();
    const scored = recipes
      .filter((r) => {
        if (!q) return true;
        return r.name.toLowerCase().includes(q) || r.ingr.some((i) => i.name.toLowerCase().includes(q));
      })
      .map((r) => ({
        r,
        score: (meta.cats.includes(r.cat) ? 0 : 1) + (r.nutrition ? 0 : 0.5),
      }));
    scored.sort((a, b) => a.score - b.score || a.r.name.localeCompare(b.r.name, "fr"));
    return scored.map((s) => s.r);
  }, [recipes, search, meta]);

  async function logHabit(h: Habit, count: number) {
    await addMealLog(habitToDraft(h, count, slot, eatenAtFor(day, slot)), null, h.recipeId ? "recipe" : "manual", owner);
    setAdded((a) => [...a, { label: h.label, kcal: Math.round(h.kcal * count) }]);
  }

  async function logRecipe(r: Recipe, portions: number) {
    const n = r.nutrition;
    if (!n) {
      onOpenRecipe(r);
      return;
    }
    setBusy(r.id);
    try {
      await addMealLog(
        {
          recipeId: r.id,
          label: r.name,
          mealType: slot,
          eatenAt: eatenAtFor(day, slot).toISOString(),
          portionGrams: Math.round(n.gramsPerServing * portions),
          kcal: Math.round(n.kcal * portions),
          proteinG: Math.round(n.proteinG * portions),
          carbsG: Math.round(n.carbsG * portions),
          fatG: Math.round(n.fatG * portions),
          ...(portions !== 1 ? { count: portions } : {}),
        },
        null,
        "recipe",
        owner,
      );
      setAdded((a) => [...a, { label: r.name, kcal: Math.round(n.kcal * portions) }]);
    } finally {
      setBusy(null);
    }
  }

  const totalAdded = added.reduce((a, x) => a + x.kcal, 0);
  const isToday = day.toDateString() === new Date().toDateString();

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-bg">
      <header className="sticky top-0 z-10 border-b border-line bg-bg/95 backdrop-blur" style={{ paddingTop: "env(safe-area-inset-top, 0px)" }}>
        <div className="mx-auto flex max-w-[640px] items-center gap-3 px-4 py-3">
          <button
            onClick={onClose}
            aria-label="Fermer"
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-surface text-ink shadow-[0_1px_3px_rgba(43,42,38,.08)]"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" className="h-4.5 w-4.5">
              <path d="M15 18l-6-6 6-6" />
            </svg>
          </button>
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-[1.1rem]" style={{ backgroundColor: `${meta.color}22` }}>
            {meta.emoji}
          </span>
          <h2 className="min-w-0 flex-1 truncate text-[1.1rem] font-extrabold tracking-tight text-ink">{meta.label}</h2>
          {!isToday && <span className="shrink-0 rounded-full bg-gold/15 px-3 py-1 text-[0.76rem] font-bold text-gold">📅 {dayLabel(day)}</span>}
        </div>
      </header>

      <main className="mx-auto flex max-w-[640px] flex-col gap-3.5 px-4 pb-32 pt-4">
        {habits.length > 0 && <HabitsList habits={habits} onLog={logHabit} />}

        <section className="rounded-3xl bg-surface p-4 shadow-[0_1px_3px_rgba(43,42,38,.08)]">
          <div className="mb-2.5 flex items-baseline justify-between gap-2">
            <h3 className="text-[0.78rem] font-bold uppercase tracking-wider text-ink-soft">Depuis mes recettes</h3>
            <button onClick={onOpenLibrary} className="text-[0.76rem] font-bold text-accent">
              Tout voir ›
            </button>
          </div>
          <label className="mb-3 flex items-center gap-2 rounded-full border-2 border-transparent bg-surface-2 px-4 py-2.5 transition focus-within:border-accent">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" className="h-4 w-4 shrink-0 text-accent">
              <circle cx="11" cy="11" r="7" />
              <path d="m21 21-4.3-4.3" />
            </svg>
            <input
              type="search"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Chercher une recette, un ingrédient…"
              className="w-full bg-transparent text-[0.92rem] text-ink outline-none placeholder:text-ink-soft"
            />
          </label>

          {list.length === 0 ? (
            <p className="py-3 text-center text-[0.84rem] text-ink-soft">
              {recipes.length === 0 ? "Aucune recette encore — ajoute-les depuis « Mes recettes »." : "Aucune recette ne correspond."}
            </p>
          ) : (
            <ul className="flex flex-col divide-y divide-line">
              {(showAll ? list : list.slice(0, 6)).map((r) => {
                const n = r.nutrition;
                const done = added.filter((a) => a.label === r.name).length;
                return (
                  <li key={r.id} className="flex flex-wrap items-center justify-between gap-2 py-2.5">
                    <div className="min-w-0 flex-1">
                      <p className="line-clamp-2 text-[0.9rem] font-semibold leading-tight text-ink">{r.name}</p>
                      <p className="truncate text-[0.72rem] text-ink-soft">
                        {n ? (
                          <>
                            <span className="font-mono font-bold text-ink">{Math.round(n.kcal)} kcal</span> / portion · P {Math.round(n.proteinG)} · G{" "}
                            {Math.round(n.carbsG)} · L {Math.round(n.fatG)}
                          </>
                        ) : (
                          "pas encore d'estimation — touche pour la calculer"
                        )}
                      </p>
                    </div>
                    {done > 0 && !busy ? (
                      <span className="rounded-full bg-herb/12 px-3 py-1.5 text-[0.78rem] font-bold text-herb">✓ Ajouté{done > 1 ? ` ×${done}` : ""}</span>
                    ) : n ? (
                      <div className="flex shrink-0 gap-1">
                        {[0.5, 1, 2].map((p) => (
                          <button
                            key={p}
                            disabled={busy !== null}
                            onClick={() => logRecipe(r, p)}
                            className="h-9 min-w-9 rounded-full border-2 border-line bg-surface px-1.5 text-[0.78rem] font-bold text-ink transition hover:border-accent hover:text-accent disabled:opacity-50"
                          >
                            {p === 0.5 ? "½" : `×${p}`}
                          </button>
                        ))}
                      </div>
                    ) : (
                      <button
                        onClick={() => onOpenRecipe(r)}
                        className="h-9 shrink-0 rounded-full border-2 border-line bg-surface px-3.5 text-[0.8rem] font-bold text-ink-soft hover:border-accent hover:text-accent"
                      >
                        Ouvrir
                      </button>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
          {!showAll && list.length > 6 && (
            <button
              onClick={() => setShowAll(true)}
              className="mt-2.5 w-full rounded-xl bg-surface-2 py-2.5 text-[0.82rem] font-bold text-ink-soft hover:text-accent"
            >
              Voir les {list.length - 6} autres
            </button>
          )}
        </section>

        <section className="rounded-3xl bg-surface p-4 shadow-[0_1px_3px_rgba(43,42,38,.08)]">
          <h3 className="mb-2.5 text-[0.78rem] font-bold uppercase tracking-wider text-ink-soft">Autre chose</h3>
          <div className="grid grid-cols-2 gap-2.5">
            <button
              onClick={onPhoto}
              className="flex flex-col items-start gap-1 rounded-2xl bg-accent p-3.5 text-left text-accent-ink shadow-[0_6px_18px_-8px_rgba(255,90,54,.8)] transition active:scale-[.97]"
            >
              <span className="text-[1.5rem] leading-none">📸</span>
              <span className="text-[0.92rem] font-extrabold">Photo</span>
              <span className="text-[0.72rem] text-accent-ink/85">de mon assiette</span>
            </button>
            <button
              onClick={onDescribe}
              className="flex flex-col items-start gap-1 rounded-2xl bg-accent-2/12 p-3.5 text-left text-ink transition active:scale-[.97]"
            >
              <span className="text-[1.5rem] leading-none">✍️</span>
              <span className="text-[0.92rem] font-extrabold">Décrire</span>
              <span className="text-[0.72rem] text-ink-soft">« 2 crêpes, un café »</span>
            </button>
          </div>
        </section>
      </main>

      {/* Récapitulatif collant : ce que ce passage a ajouté. */}
      <div
        className="fixed bottom-0 left-0 right-0 z-10 border-t border-line bg-bg/95 px-4 py-3 backdrop-blur"
        style={{ paddingBottom: "max(0.75rem, env(safe-area-inset-bottom, 0px))" }}
      >
        <div className="mx-auto flex max-w-[640px] items-center gap-3">
          <p className="min-w-0 flex-1 text-[0.82rem] text-ink-soft">
            {added.length === 0 ? (
              "Touche une quantité : c'est noté tout de suite."
            ) : (
              <>
                <strong className="text-herb">✓ {added.length} ajout{added.length > 1 ? "s" : ""}</strong> ·{" "}
                <span className="font-mono font-bold text-ink">{totalAdded} kcal</span>
              </>
            )}
          </p>
          <button
            onClick={onClose}
            className={`shrink-0 rounded-2xl px-5 py-3 text-[0.9rem] font-bold transition active:scale-[.97] ${
              added.length ? "bg-herb text-white" : "bg-surface text-ink shadow-[0_1px_3px_rgba(43,42,38,.1)]"
            }`}
          >
            {added.length ? "Terminé" : "Fermer"}
          </button>
        </div>
      </div>
    </div>
  );
}
