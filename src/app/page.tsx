"use client";

import { useMemo, useState } from "react";
import { CategoryTabs } from "@/components/CategoryTabs";
import { Toolbar, TimePills, TIME_BUCKETS, type TimeBucketKey } from "@/components/Toolbar";
import { IngredientPicker } from "@/components/IngredientPicker";
import { RecipeCard } from "@/components/RecipeCard";
import { RecipeDetail } from "@/components/RecipeDetail";
import { AddRecipeDialog } from "@/components/AddRecipeDialog";
import { useRecipes, saveNotes, uploadRecipePhoto } from "@/lib/useRecipes";
import { useFavorites } from "@/lib/useFavorites";
import { firebaseEnabled } from "@/lib/firebase";
import type { CategoryKey } from "@/lib/types";

export default function Home() {
  const { recipes, readOnly } = useRecipes();
  const { favs, toggle: toggleFav } = useFavorites();

  const [search, setSearch] = useState("");
  const [cat, setCat] = useState<CategoryKey | "all">("all");
  const [time, setTime] = useState<TimeBucketKey>("all");
  const [vegOnly, setVegOnly] = useState(false);
  const [favOnly, setFavOnly] = useState(false);
  const [ingredients, setIngredients] = useState<Set<string>>(new Set());
  const [openId, setOpenId] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);

  const freq = useMemo(() => {
    const f: Record<string, number> = {};
    for (const r of recipes) {
      for (const i of r.ingr) {
        const n = i.name.trim();
        if (!n) continue;
        f[n] = (f[n] || 0) + 1;
      }
    }
    return f;
  }, [recipes]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    const bucket = TIME_BUCKETS.find((b) => b.key === time);
    return recipes.filter((r) => {
      if (q) {
        const inName = r.name.toLowerCase().includes(q);
        const inIngr = r.ingr.some((i) => i.name.toLowerCase().includes(q));
        if (!inName && !inIngr) return false;
      }
      if (cat !== "all" && r.cat !== cat) return false;
      if (vegOnly && !r.veg) return false;
      if (favOnly && !favs.has(r.id)) return false;
      if (bucket) {
        if ("max" in bucket && bucket.max !== undefined && r.time > bucket.max) return false;
        if ("min" in bucket && bucket.min !== undefined && r.time < bucket.min) return false;
      }
      if (ingredients.size) {
        const names = r.ingr.map((i) => i.name);
        for (const sel of ingredients) if (!names.includes(sel)) return false;
      }
      return true;
    });
  }, [recipes, search, cat, time, vegOnly, favOnly, favs, ingredients]);

  const openRecipe = recipes.find((r) => r.id === openId) || null;

  function toggleIngredient(name: string) {
    setIngredients((prev) => {
      const next = new Set(prev);
      if (next.has(name)) next.delete(name);
      else next.add(name);
      return next;
    });
  }

  function surprise() {
    const pool = filtered.length ? filtered : recipes;
    if (!pool.length) return;
    const pick = pool[Math.floor(Math.random() * pool.length)];
    setOpenId(pick.id);
  }

  const filterBits: string[] = [];
  if (cat !== "all") filterBits.push(cat);
  if (time !== "all") filterBits.push(TIME_BUCKETS.find((b) => b.key === time)?.label ?? "");
  if (vegOnly) filterBits.push("végétarien");
  if (favOnly) filterBits.push("favoris");
  if (ingredients.size) filterBits.push(`${ingredients.size} ingrédient(s) choisi(s)`);

  return (
    <div className="flex min-h-full flex-col">
      <header className="sticky top-0 z-30 border-b border-line bg-bg pb-3 pt-4" style={{ paddingTop: "max(1rem, env(safe-area-inset-top, 0px))" }}>
        <div className="mx-auto max-w-[1180px] px-5">
          <div className="mb-3.5 flex items-baseline gap-3.5">
            <div className="flex items-center gap-2.5">
              <div className="flex h-8.5 w-8.5 shrink-0 items-center justify-center rounded-lg bg-accent text-accent-ink shadow-[0_1px_2px_rgba(41,39,31,.06),0_8px_20px_-12px_rgba(41,39,31,.25)]">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round" className="h-4.5 w-4.5">
                  <rect x="4" y="3" width="16" height="18" rx="2" />
                  <path d="M8 8h8M8 12h8M8 16h5" />
                </svg>
              </div>
              <div>
                <h1 className="text-[1.5rem] font-semibold tracking-tight">Recettes du Tiroir</h1>
                <p className="text-[0.85rem] text-ink-soft">
                  {recipes.length} recettes de la famille, triées par temps &amp; par ce qu&apos;il reste au frigo
                </p>
              </div>
            </div>
          </div>

          <Toolbar
            search={search}
            onSearch={setSearch}
            veg={vegOnly}
            onVeg={() => setVegOnly((v) => !v)}
            fav={favOnly}
            onFav={() => setFavOnly((v) => !v)}
            onSurprise={surprise}
            onAdd={() => setAddOpen(true)}
            addAvailable={firebaseEnabled}
          />
          {!firebaseEnabled && (
            <p className="mt-2 text-[0.76rem] text-ink-soft">
              Firebase n&apos;est pas configuré — bibliothèque en lecture seule avec les recettes de base.
            </p>
          )}
          {firebaseEnabled && readOnly && (
            <p className="mt-2 text-[0.76rem] text-ink-soft">
              Bibliothèque pas encore initialisée (lance <code>npm run seed</code>) — les recettes de base sont affichées en lecture seule.
            </p>
          )}

          <CategoryTabs active={cat} onChange={setCat} />

          <div className="flex flex-wrap items-center gap-2.5 border-b border-line py-3">
            <TimePills active={time} onChange={setTime} />
          </div>
          <IngredientPicker freq={freq} selected={ingredients} onToggle={toggleIngredient} />
        </div>
      </header>

      <main className="mx-auto w-full max-w-[1180px] flex-1 px-5">
        <div className="flex flex-wrap items-baseline justify-between gap-2.5 py-3.5">
          <span className="text-[0.85rem] text-ink-soft">
            <strong className="font-semibold text-ink">{filtered.length}</strong> recettes
          </span>
          <span className="text-[0.85rem] text-ink-soft">{filterBits.join(" · ")}</span>
        </div>

        {filtered.length === 0 ? (
          <div className="mb-8 rounded-2xl border border-dashed border-line px-5 py-12 text-center text-ink-soft">
            <p className="mb-3">Aucune recette ne correspond à ces filtres.</p>
            <button
              onClick={() => {
                setSearch("");
                setCat("all");
                setTime("all");
                setVegOnly(false);
                setFavOnly(false);
                setIngredients(new Set());
              }}
              className="rounded-xl border border-line bg-surface px-3.5 py-2 text-[0.85rem] text-ink hover:bg-surface-2"
            >
              Réinitialiser les filtres
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-[repeat(auto-fill,minmax(232px,1fr))] gap-4.5 pb-10">
            {filtered.map((r) => (
              <RecipeCard
                key={r.id}
                recipe={r}
                isFav={favs.has(r.id)}
                onOpen={() => setOpenId(r.id)}
                onToggleFav={() => toggleFav(r.id)}
              />
            ))}
          </div>
        )}
      </main>

      <footer className="mx-auto w-full max-w-[1180px] border-t border-line px-5 py-7 text-center text-[0.78rem] text-ink-soft">
        Bibliothèque de recettes familiale — pense à ajouter les vôtres.
      </footer>

      {openRecipe && (
        <RecipeDetail
          key={openRecipe.id}
          recipe={openRecipe}
          isFav={favs.has(openRecipe.id)}
          onToggleFav={() => toggleFav(openRecipe.id)}
          onClose={() => setOpenId(null)}
          onSaveNotes={(text) => saveNotes(openRecipe.id, text)}
          onPhotoFile={(file) => uploadRecipePhoto(openRecipe.id, file)}
          readOnly={readOnly}
        />
      )}

      {addOpen && <AddRecipeDialog onClose={() => setAddOpen(false)} />}
    </div>
  );
}
