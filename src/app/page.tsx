"use client";

import { useMemo, useState } from "react";
import { Toolbar, TIME_BUCKETS, type TimeBucketKey } from "@/components/Toolbar";
import { FilterDrawer } from "@/components/FilterDrawer";
import { RecipeCard } from "@/components/RecipeCard";
import { RecipeDetail } from "@/components/RecipeDetail";
import { EditRecipeDialog } from "@/components/EditRecipeDialog";
import { ShareSettings } from "@/components/ShareSettings";
import { AddMealFlow } from "@/components/AddMealFlow";
import { Dashboard } from "@/components/Dashboard";
import {
  useRecipes,
  saveNotes,
  uploadRecipePhoto,
  deleteRecipe,
  addEatenDate,
  removeEatenDate,
} from "@/lib/useRecipes";
import { useMealLogs } from "@/lib/useMealLogs";
import { useFavorites } from "@/lib/useFavorites";
import { firebaseEnabled } from "@/lib/firebase";
import { useAuth, signOut } from "@/lib/useAuth";
import { useHousehold, setDailyKcalGoal } from "@/lib/useHousehold";
import { AuthLanding } from "@/components/AuthGate";
import type { CategoryKey } from "@/lib/types";

export default function Home() {
  const { user, checking } = useAuth();

  // Firebase pas configuré : mode démo en lecture seule, pas de mur de
  // connexion (rien à protéger). Firebase configuré : compte obligatoire.
  if (firebaseEnabled && checking) {
    return (
      <div className="flex min-h-full flex-1 items-center justify-center">
        <span className="h-6 w-6 animate-spin rounded-full border-2 border-line border-t-accent" />
      </div>
    );
  }
  if (firebaseEnabled && !user) {
    return <AuthLanding />;
  }

  return <RecipeLibrary uid={user?.uid ?? null} />;
}

function RecipeLibrary({ uid }: { uid: string | null }) {
  const { profile, household, loading: householdLoading } = useHousehold(uid);
  const { recipes, readOnly } = useRecipes(profile?.householdId ?? null);
  const { logs: mealLogs } = useMealLogs(profile?.householdId ?? null);
  const { favs, toggle: toggleFav } = useFavorites();

  const [search, setSearch] = useState("");
  const [cat, setCat] = useState<CategoryKey | "all">("all");
  const [time, setTime] = useState<TimeBucketKey>("all");
  const [vegOnly, setVegOnly] = useState(false);
  const [favOnly, setFavOnly] = useState(false);
  const [ingredients, setIngredients] = useState<Set<string>>(new Set());
  const [openId, setOpenId] = useState<string | null>(null);
  const [editOpen, setEditOpen] = useState(false);
  const [shareOpen, setShareOpen] = useState(false);
  const [filtersOpen, setFiltersOpen] = useState(false);
  // Accueil (état du jour + 2 actions) ou écran bibliothèque. Le parcours
  // "Ajouter un repas" s'ouvre par-dessus en plein écran.
  const [view, setView] = useState<"home" | "recipes">("home");
  const [addFlow, setAddFlow] = useState<"none" | "new" | "recipe">("none");

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

  const canAdd = firebaseEnabled && Boolean(uid && profile);

  return (
    <div className="flex min-h-full flex-col">
      <header className="sticky top-0 z-30 bg-bg pb-2.5 pt-3" style={{ paddingTop: "max(0.75rem, env(safe-area-inset-top, 0px))" }}>
        <div className="mx-auto max-w-[1180px] px-4">
          {view === "home" ? (
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-accent text-accent-ink">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4">
                  <path d="M18 8h1a4 4 0 0 1 0 8h-1M6 8h12v9a3 3 0 0 1-3 3H9a3 3 0 0 1-3-3V8Z" />
                  <path d="M6 1v3M10 1v3M14 1v3" />
                </svg>
              </div>
              <h1 className="text-[1.15rem] font-extrabold tracking-tight text-ink">Recettes du Tiroir</h1>
              {firebaseEnabled && (
                <div className="ml-auto flex shrink-0 items-center gap-2">
                  {profile && (
                    <button
                      onClick={() => setShareOpen(true)}
                      className="rounded-full border border-line bg-surface px-3 py-1.5 text-[0.76rem] font-semibold text-ink-soft hover:border-accent hover:text-accent"
                    >
                      {profile.householdId === uid ? "Partage" : "Bibliothèque partagée"}
                    </button>
                  )}
                  <button
                    onClick={() => signOut()}
                    className="rounded-full border border-line bg-surface px-3 py-1.5 text-[0.76rem] font-semibold text-ink-soft hover:border-accent hover:text-accent"
                  >
                    Déconnexion
                  </button>
                </div>
              )}
            </div>
          ) : (
            <>
              <div className="mb-2.5 flex items-center gap-3">
                <button
                  onClick={() => setView("home")}
                  aria-label="Retour à l'accueil"
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-surface text-ink shadow-[0_1px_3px_rgba(43,42,38,.08)]"
                >
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" className="h-4.5 w-4.5">
                    <path d="M15 18l-6-6 6-6" />
                  </svg>
                </button>
                <h1 className="text-[1.15rem] font-extrabold tracking-tight text-ink">Mes recettes</h1>
                <span className="text-[0.78rem] font-semibold text-ink-soft">{recipes.length}</span>
              </div>
              <Toolbar
                search={search}
                onSearch={setSearch}
                onOpenFilters={() => setFiltersOpen(true)}
                activeFilterCount={activeFilterCount}
              />
            </>
          )}
          {!firebaseEnabled && (
            <p className="mt-2 text-[0.76rem] text-ink-soft">
              Firebase n&apos;est pas configuré — bibliothèque en lecture seule avec les recettes de base.
            </p>
          )}
          {firebaseEnabled && !householdLoading && readOnly && (
            <p className="mt-2 text-[0.76rem] text-ink-soft">
              Bibliothèque pas encore initialisée (lance <code>npm run seed</code>) — les recettes de base sont affichées en lecture seule.
            </p>
          )}

          {view === "recipes" && (
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
          )}
        </div>
      </header>

      <main className="mx-auto w-full max-w-[1180px] flex-1 px-4">
        {view === "home" && (
          <div className="flex flex-col gap-3 pb-10 pt-3">
            {firebaseEnabled && profile ? (
              <Dashboard
                logs={mealLogs}
                dailyKcalGoal={profile.dailyKcalGoal}
                onSetGoal={(v) => setDailyKcalGoal(uid!, v)}
                readOnly={readOnly}
              >
                <div className="mt-4 grid grid-cols-2 gap-2.5">
                  {canAdd && (
                    <button
                      onClick={() => setAddFlow("new")}
                      className="flex flex-col items-start gap-1.5 rounded-2xl bg-accent p-4 text-left text-accent-ink shadow-[0_6px_20px_-6px_rgba(255,90,54,.7)] transition active:scale-[.98]"
                    >
                      <span className="text-[1.8rem] leading-none">🍽️</span>
                      <span className="text-[1rem] font-extrabold">Ajouter un repas</span>
                      <span className="text-[0.76rem] text-accent-ink/85">Photo ou texte</span>
                    </button>
                  )}
                  <button
                    onClick={() => setView("recipes")}
                    className={`flex flex-col items-start gap-1.5 rounded-2xl bg-surface-2 p-4 text-left text-ink transition active:scale-[.98] ${canAdd ? "" : "col-span-2"}`}
                  >
                    <span className="text-[1.8rem] leading-none">📖</span>
                    <span className="text-[1rem] font-extrabold">Mes recettes</span>
                    <span className="text-[0.76rem] text-ink-soft">
                      {recipes.length} recette{recipes.length > 1 ? "s" : ""}
                    </span>
                  </button>
                </div>
              </Dashboard>
            ) : (
              <button
                onClick={() => setView("recipes")}
                className="rounded-2xl bg-surface p-5 text-left text-[1rem] font-extrabold text-ink shadow-[0_1px_3px_rgba(43,42,38,.08)]"
              >
                📖 Voir les recettes ({recipes.length})
              </button>
            )}
          </div>
        )}

        {view === "recipes" && (
          <>
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
          </>
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
          onEdit={() => setEditOpen(true)}
          onLogMeal={() => setAddFlow("recipe")}
          readOnly={readOnly}
        />
      )}

      {editOpen && openRecipe && <EditRecipeDialog recipe={openRecipe} onClose={() => setEditOpen(false)} />}

      {shareOpen && uid && profile && (
        <ShareSettings uid={uid} profile={profile} household={household} onClose={() => setShareOpen(false)} />
      )}

      {addFlow !== "none" && uid && profile && (
        <AddMealFlow
          recipes={recipes}
          owner={{ uid, name: profile.displayName, householdId: profile.householdId }}
          initialRecipe={addFlow === "recipe" ? openRecipe : null}
          onClose={() => {
            setAddFlow("none");
            if (addFlow === "new") setView("home");
          }}
        />
      )}
    </div>
  );
}
