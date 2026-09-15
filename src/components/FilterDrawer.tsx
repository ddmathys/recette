"use client";

import { CategoryTabs } from "./CategoryTabs";
import { TimePills, ToggleButton, type TimeBucketKey } from "./Toolbar";
import { IngredientPicker } from "./IngredientPicker";
import type { CategoryKey } from "@/lib/types";

/**
 * On phone (below md): a slide-in panel from the left, opened by the
 * "Filtres" button in the Toolbar, holding everything that isn't the
 * recipe grid itself — category, time, végé/favoris, surprise, ingredients.
 * On md and up: the same content renders inline in the page flow, no
 * drawer chrome, exactly as before.
 */
export function FilterDrawer({
  open,
  onClose,
  cat,
  onCat,
  time,
  onTime,
  veg,
  onVeg,
  fav,
  onFav,
  onSurprise,
  freq,
  ingredients,
  onToggleIngredient,
}: {
  open: boolean;
  onClose: () => void;
  cat: CategoryKey | "all";
  onCat: (c: CategoryKey | "all") => void;
  time: TimeBucketKey;
  onTime: (t: TimeBucketKey) => void;
  veg: boolean;
  onVeg: () => void;
  fav: boolean;
  onFav: () => void;
  onSurprise: () => void;
  freq: Record<string, number>;
  ingredients: Set<string>;
  onToggleIngredient: (name: string) => void;
}) {
  return (
    <>
      {open && <div className="fixed inset-0 z-40 bg-black/40 md:hidden" onClick={onClose} />}
      <div
        className={`fixed inset-y-0 left-0 z-41 w-[85vw] max-w-[320px] overflow-y-auto rounded-r-[24px] bg-surface p-5 shadow-[12px_0_30px_-10px_rgba(0,0,0,.35)] transition-transform duration-200 md:static md:z-auto md:w-auto md:max-w-none md:translate-x-0 md:overflow-visible md:rounded-none md:bg-transparent md:p-0 md:shadow-none ${
          open ? "translate-x-0" : "-translate-x-full"
        }`}
        style={{ paddingTop: "max(1.25rem, env(safe-area-inset-top, 0px))" }}
      >
        <div className="mb-4 flex items-center justify-between md:hidden">
          <h2 className="text-[1.05rem] font-bold">Filtres</h2>
          <button onClick={onClose} aria-label="Fermer" className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-2 text-ink">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-4 w-4">
              <path d="M6 6l12 12M18 6 6 18" />
            </svg>
          </button>
        </div>

        <div className="mb-3.5 flex flex-wrap gap-2">
          <ToggleButton pressed={veg} onClick={onVeg} label="Végétarien" icon={
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4">
              <path d="M12 21V11" />
              <path d="M12 11C12 6 8 5 5 5c0 4 2 6 7 6z" />
              <path d="M12 14c0-4 4-5 7-5 0 4-2 6-7 5z" />
            </svg>
          } />
          <ToggleButton pressed={fav} onClick={onFav} label="Favoris" icon={
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4">
              <path d="M12 20s-7-4.35-9.5-8.5C.8 8.1 2.4 5 5.6 5 7.6 5 9 6 12 8.5 15 6 16.4 5 18.4 5c3.2 0 4.8 3.1 3.1 6.5C19 15.65 12 20 12 20z" />
            </svg>
          } />
          <button
            onClick={onSurprise}
            className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border-2 border-transparent bg-gold px-3.5 py-2 text-[0.83rem] font-bold text-white transition hover:brightness-105 active:scale-95"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.9} strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4">
              <path d="M12 3v3M12 18v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M3 12h3M18 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1" />
              <circle cx="12" cy="12" r="3.2" />
            </svg>
            Surprends-moi
          </button>
        </div>

        <CategoryTabs active={cat} onChange={onCat} />

        <div className="flex flex-wrap items-center gap-2.5 border-t border-line py-3">
          <TimePills active={time} onChange={onTime} />
        </div>

        <IngredientPicker freq={freq} selected={ingredients} onToggle={onToggleIngredient} />
      </div>
    </>
  );
}
