"use client";

import { useMemo, useState } from "react";
import { Toolbar, TIME_BUCKETS, type TimeBucketKey } from "@/components/Toolbar";
import { FilterDrawer } from "@/components/FilterDrawer";
import { RecipeCard } from "@/components/RecipeCard";
import { RecipeDetail } from "@/components/RecipeDetail";
import { AddRecipeDialog } from "@/components/AddRecipeDialog";
import { useRecipes, saveNotes, uploadRecipePhoto, deleteRecipe, addEatenDate, removeEatenDate } from "@/lib/useRecipes";
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
  const [filtersOpen, setFiltersOpen] = useState(false);

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
  const activeFilterCount =
    (cat !== "all" ? 1 : 0) + (time !== "all" ? 1 : 0) + (vegOnly ? 1 : 0) + (favOnly ? 1 : 0) + (ingredients.size ? 1 : 0);

  return (
    <div className="flex min-h-full flex-col">
      <header className="sticky top-0 z-30 bg-bg pb-2.5 pt-3" style={{ paddingTop: "max(0.75rem, env(safe-area-inset-top, 0px))" }}>
        <div className="mx-auto max-w-[1180px] px-4">
          <div className="mb-2.5 flex items-center gap-2">
            <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-accent text-accent-ink">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4">
                <path d="M18 8h1a4 4 0 0 1 0 8h-1M6 8h12v9a3 3 0 0 1-3 3H9a3 3 0 0 1-3-3V8Z" />
                <path d="M6 1v3M10 1v3M14 1v3" />
              </svg>
            </div>
            <h1 className="text-[1.15rem] font-extrabold tracking-tight text-ink">Recettes du Tiroir</h1>
            <span className="text-[0.78rem] font-semibold text-ink-soft">{recipes.length} recette{recipes.length > 1 ? "s" : ""}</span>
          </div>

          <Toolbar
            search={search}
            onSearch={setSearch}
            onOpenFilters={() => setFiltersOpen(true)}
            activeFilterCount={activeFilterCount}
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

          <FilterDrawer
            open={filtersOpen}
            onClose={() => setFiltersOpen(false)}
            cat={cat}
            onCat={setCat}
            time={time}
            onTime={setTime}
            veg={vegOnly}
            onVeg={() => setVegOnly((v) => !v)}
            fav={favOnly}
            onFav={() => setFavOnly((v) => !v)}
            onSurprise={() => {
              surprise();
              setFiltersOpen(false);
            }}
            freq={freq}
            ingredients={ingredients}
            onToggleIngredient={toggleIngredient}
          />
        </div>
      </header>

      <main className="mx-auto w-full max-w-[1180px] flex-1 px-4">
        <div className="flex flex-wrap items-baseline justify-between gap-2.5 py-3">
          <span className="text-[0.8rem] font-semibold text-ink-soft">
            <strong className="text-ink">{filtered.length}</strong> recette{filtered.length > 1 ? "s" : ""}
          </span>
          <span className="text-[0.8rem] text-ink-soft">{filterBits.join(" · ")}</span>
        </div>

        {filtered.length === 0 ? (
          <div className="mb-8 rounded-2xl border-2 border-dashed border-line px-5 py-12 text-center text-ink-soft">
            <p className="mb-3">
              {recipes.length === 0
                ? "Aucune recette pour l'instant — ajoutez la première !"
                : "Aucune recette ne correspond à ces filtres."}
            </p>
            {recipes.length > 0 && (
              <button
                onClick={() => {
                  setSearch("");
                  setCat("all");
                  setTime("all");
                  setVegOnly(false);
                  setFavOnly(false);
                  setIngredients(new Set());
                }}
                className="rounded-full border-2 border-line bg-surface px-4 py-2 text-[0.85rem] font-semibold text-ink hover:border-accent hover:text-accent"
              >
                Réinitialiser les filtres
              </button>
            )}
          </div>
        ) : (
          <div className="grid grid-cols-[repeat(auto-fill,minmax(148px,1fr))] gap-3 pb-10">
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

      <footer className="mx-auto w-full max-w-[1180px] px-4 py-6 text-center text-[0.76rem] text-ink-soft">
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
          onDelete={() => {
            setOpenId(null);
            return deleteRecipe(openRecipe.id, openRecipe.photoUrl);
          }}
          onAddEatenDate={(date) => addEatenDate(openRecipe.id, date)}
          onRemoveEatenDate={(date) => removeEatenDate(openRecipe.id, date)}
          readOnly={readOnly}
        />
      )}

      {addOpen && <AddRecipeDialog onClose={() => setAddOpen(false)} />}
    </div>
  );
}
