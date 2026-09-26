"use client";

import { useRef, useState } from "react";
import { CATEGORIES } from "@/lib/categories";
import { compressImageIfNeeded } from "@/lib/compressImage";
import { auth } from "@/lib/firebase";
import { MEAL_TYPES, dayLabel, eatenAtFor, guessMealType } from "@/lib/mealTypes";
import { sanitizeNutrition } from "@/lib/nutrition";
import { addRecipe, uploadRecipePhoto } from "@/lib/useRecipes";
import { addMealLog, uploadMealPhoto } from "@/lib/useMealLogs";
import { computeHabits, habitToDraft, type Habit } from "@/lib/habits";
import { HabitsList } from "./HabitsList";
import type { CategoryKey, Difficulty, Ingredient, MealLog, MealType, Recipe, RecipeDraft } from "@/lib/types";

const DIFFICULTIES: Difficulty[] = ["Facile", "Moyen", "Avancé"];
const MAX_PHOTO_BYTES = 10 * 1024 * 1024;

/** "meal" = assiette photographiée (1 personne, pas d'étapes) ; "recipe" =
 * recette écrite ou existante (N personnes, étapes). Les deux arrivent sur
 * le même écran de résultat. */
type Kind = "meal" | "recipe";
type Stage = "choose" | "describe" | "text" | "loading" | "result";

const TEXT_SUGGESTIONS = ["Version plus légère", "Sans gluten", "Végétarien", "Plus rapide"];
const SNACK_IDEAS = ["Une pomme", "Un yaourt nature", "Un carré de chocolat", "Une poignée d'amandes", "Une banane", "Un café au lait", "Un biscuit", "Une barre de céréales"];
const MEAL_SUGGESTIONS = ["Portion plus petite", "Sans la sauce", "J'en ai mangé 2", "Il y avait aussi du pain"];

/**
 * Parcours "Ajouter un repas" en plein écran : choix photo / texte, puis un
 * écran de résultat commun (calories réparties + ingrédients, et la recette
 * si écrite) qu'on peut itérer par IA avant de le noter comme mangé et/ou
 * de le garder dans la bibliothèque. Remplace CaptureDialog.
 * `initialRecipe` saute directement au résultat ("Manger ce repas").
 * `day` = jour affiché au dashboard : le repas est noté ce jour-là.
 * `preset` ("snack" / "breakfast") ouvre directement "Décrire" avec le
 * type Collation / Petit-déjeuner et les habituels de ce type en premier.
 */
export function AddMealFlow({
  recipes,
  owner,
  initialRecipe,
  day,
  preset,
  logs,
  onClose,
}: {
  recipes: Recipe[];
  owner: { uid: string; name: string; householdId: string };
  initialRecipe?: Recipe | null;
  day: Date;
  preset?: "snack" | "breakfast";
  /** Journal de l'utilisateur, pour proposer ses habituels. */
  logs: MealLog[];
  onClose: () => void;
}) {
  const snack = preset === "snack";
  const presetType: MealType | undefined = preset === "snack" ? "collation" : preset === "breakfast" ? "petit-dej" : undefined;
  const habits = computeHabits(logs, owner.uid, presetType, presetType ? 8 : 5);
  const [stage, setStage] = useState<Stage>(initialRecipe ? "result" : preset ? "describe" : "choose");
  const isToday = day.toDateString() === new Date().toDateString();
  const [kind, setKind] = useState<Kind>("recipe");
  const [error, setError] = useState<string | null>(null);
  const [loadingLabel, setLoadingLabel] = useState("");

  // Saisie texte
  const [query, setQuery] = useState("");
  const [description, setDescription] = useState("");
  const [persons, setPersons] = useState(2);

  // Photo
  const photoInput = useRef<HTMLInputElement>(null);
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);
  const [suggestedPhoto, setSuggestedPhoto] = useState<string | null>(null);
  const [source, setSource] = useState<string | null>(null);

  // Résultat
  const [draft, setDraft] = useState<RecipeDraft | null>(() => (initialRecipe ? recipeToDraft(initialRecipe) : null));
  const [matchedRecipeId, setMatchedRecipeId] = useState<string | null>(initialRecipe?.id ?? null);
  const [savedRecipeId, setSavedRecipeId] = useState<string | null>(initialRecipe?.id ?? null);
  const [instruction, setInstruction] = useState("");
  const [iterating, setIterating] = useState(false);
  const [lastChange, setLastChange] = useState<string | null>(null);
  const scroller = useRef<HTMLDivElement>(null);
  const [mealType, setMealType] = useState<MealType>(presetType ?? guessMealType());
  const [portions, setPortions] = useState(1);
  const [logged, setLogged] = useState(false);
  const [busyAction, setBusyAction] = useState<"log" | "save" | null>(null);

  const matchedRecipe = matchedRecipeId ? recipes.find((r) => r.id === matchedRecipeId) ?? null : null;

  async function authHeaders() {
    const idToken = await auth?.currentUser?.getIdToken();
    return {
      "Content-Type": "application/json",
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    };
  }

  async function handlePhoto(f: File) {
    setError(null);
    setKind("meal");
    setStage("loading");
    setLoadingLabel("J'analyse ton assiette…");
    try {
      const file = await compressImageIfNeeded(f, MAX_PHOTO_BYTES);
      if (file.size > MAX_PHOTO_BYTES) throw new Error("Photo trop lourde (max 10 Mo), même après compression.");
      setPhotoFile(file);
      setPhotoPreview(URL.createObjectURL(file));
      const url = await uploadMealPhoto(owner.uid, file);
      setPhotoUrl(url);
      const res = await fetch("/api/analyze-meal-photo", {
        method: "POST",
        headers: await authHeaders(),
        body: JSON.stringify({ photoUrl: url, recipes: recipes.map((r) => ({ id: r.id, name: r.name })) }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "La reconnaissance photo a échoué.");
      const d = data.draft as Record<string, unknown>;
      const nutrition = sanitizeNutrition(
        { kcal: d.kcal, proteinG: d.proteinG, carbsG: d.carbsG, fatG: d.fatG, gramsPerServing: d.portionGrams },
        "ai",
      );
      const matched = typeof d.matchedRecipeId === "string" ? recipes.find((r) => r.id === d.matchedRecipeId) : null;
      setMatchedRecipeId(matched?.id ?? null);
      setSavedRecipeId(matched?.id ?? null);
      setDraft({
        name: typeof d.label === "string" && d.label.trim() ? d.label.trim() : "Mon repas",
        cat: validCat(d.cat),
        time: 0,
        diff: "Facile",
        servings: 1,
        veg: Boolean(d.veg),
        ingr: cleanIngredients(d.ingr),
        steps: [],
        nutrition,
      });
      if (MEAL_TYPES.some((m) => m.key === d.mealType)) setMealType(d.mealType as MealType);
      setStage("result");
    } catch (e) {
      setError(e instanceof Error ? e.message : "La reconnaissance photo a échoué.");
      setStage("choose");
    }
  }

  async function searchRecipe() {
    const q = query.trim();
    if (!q) {
      setError("Écris le repas que tu veux, par exemple « crêpes ».");
      return;
    }
    setError(null);
    setKind("recipe");
    setStage("loading");
    setLoadingLabel(`Je prépare la recette pour ${persons} personne${persons > 1 ? "s" : ""}…`);
    const isLink = /^https?:\/\/\S+$/i.test(q);
    try {
      const res = await fetch("/api/parse-recipe", {
        method: "POST",
        headers: await authHeaders(),
        body: JSON.stringify(isLink ? { link: q, servings: persons } : { text: q, servings: persons }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "La recherche de recette a échoué.");
      setDraft(normalizeDraft(data.draft, q));
      setSource(isLink ? q : null);
      if (data.ogImage) setSuggestedPhoto(data.ogImage);
      setMatchedRecipeId(null);
      setSavedRecipeId(null);
      setStage("result");
    } catch (e) {
      setError(e instanceof Error ? e.message : "La recherche de recette a échoué.");
      setStage("text");
    }
  }

  async function logHabit(h: Habit, count: number) {
    const type = presetType ?? h.mealType;
    await addMealLog(habitToDraft(h, count, type, eatenAtFor(day, type)), null, h.recipeId ? "recipe" : "manual", owner);
  }

  async function describeMeal() {
    const q = description.trim();
    if (!q) {
      setError(snack ? "Écris ce que tu as pris, par exemple « une pomme »." : "Écris ce que tu as mangé, par exemple « crêpes et poulet sauce soja ».");
      return;
    }
    setError(null);
    setKind("meal");
    setStage("loading");
    setLoadingLabel("J'estime ce que tu as mangé…");
    try {
      const res = await fetch("/api/parse-recipe", {
        method: "POST",
        headers: await authHeaders(),
        body: JSON.stringify({ text: q, kind: "meal" }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "L'estimation a échoué.");
      const next = normalizeDraft(data.draft, q);
      setDraft({ ...next, servings: 1, steps: [] });
      setMatchedRecipeId(null);
      setSavedRecipeId(null);
      setStage("result");
    } catch (e) {
      setError(e instanceof Error ? e.message : "L'estimation a échoué.");
      setStage("describe");
    }
  }

  async function iterate(text: string) {
    const instr = text.trim();
    if (!instr || !draft) return;
    setIterating(true);
    setError(null);
    try {
      const res = await fetch("/api/edit-recipe", {
        method: "POST",
        headers: await authHeaders(),
        body: JSON.stringify({ recipe: draft, instruction: instr, kind }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "L'adaptation a échoué.");
      const next = normalizeDraft(data.draft, draft.name);
      setDraft(kind === "meal" ? { ...next, servings: 1, steps: [] } : next);
      // Le contenu a changé : ce n'est plus la recette enregistrée/reconnue.
      setSavedRecipeId(null);
      setMatchedRecipeId(null);
      setLogged(false);
      setInstruction("");
      setLastChange(instr);
      scroller.current?.scrollTo({ top: 0, behavior: "smooth" });
    } catch (e) {
      setError(e instanceof Error ? e.message : "L'adaptation a échoué.");
    } finally {
      setIterating(false);
    }
  }

  async function logMeal() {
    if (!draft) return;
    setBusyAction("log");
    setError(null);
    try {
      const n = draft.nutrition;
      await addMealLog(
        {
          recipeId: savedRecipeId,
          label: draft.name,
          mealType,
          eatenAt: eatenAtFor(day, mealType).toISOString(),
          portionGrams: Math.round((n?.gramsPerServing ?? 0) * portions),
          kcal: Math.round((n?.kcal ?? 0) * portions),
          proteinG: Math.round((n?.proteinG ?? 0) * portions),
          carbsG: Math.round((n?.carbsG ?? 0) * portions),
          fatG: Math.round((n?.fatG ?? 0) * portions),
          ...(portions !== 1 ? { count: portions } : {}),
        },
        photoUrl,
        photoUrl ? "photo" : savedRecipeId ? "recipe" : "manual",
        owner,
      );
      setLogged(true);
    } catch {
      setError("L'enregistrement du repas a échoué, réessaie.");
    } finally {
      setBusyAction(null);
    }
  }

  async function saveRecipe() {
    if (!draft) return;
    setBusyAction("save");
    setError(null);
    try {
      const ingr = draft.ingr.filter((i) => i.name.trim());
      const id = await addRecipe({ ...draft, ingr, time: draft.time || 15 }, source, photoFile ? null : suggestedPhoto, owner);
      if (photoFile) {
        // Copie propre de la photo pour la recette : la photo du journal a
        // son propre cycle de vie (supprimée avec le repas).
        try {
          await uploadRecipePhoto(id, photoFile);
        } catch {
          /* best effort */
        }
      }
      setSavedRecipeId(id);
    } catch {
      setError("L'enregistrement de la recette a échoué, réessaie.");
    } finally {
      setBusyAction(null);
    }
  }

  const title =
    stage === "choose"
      ? "Ajouter un repas"
      : stage === "describe"
        ? snack
          ? "Ajouter un en-cas"
          : preset === "breakfast"
            ? "Ajouter un petit-déj"
            : "Ce que j'ai mangé"
        : stage === "text"
          ? "Trouver une recette"
          : stage === "loading"
            ? "Un instant…"
            : draft?.name || "Résultat";

  return (
    <div ref={scroller} className="fixed inset-0 z-50 overflow-y-auto bg-bg">
      <header
        className="sticky top-0 z-10 border-b border-line bg-bg/95 backdrop-blur"
        style={{ paddingTop: "env(safe-area-inset-top, 0px)" }}
      >
        <div className="mx-auto flex max-w-[640px] items-center gap-3 px-4 py-3">
          <button
            onClick={() => {
              if ((stage === "text" || stage === "describe") && !preset) setStage("choose");
              else onClose();
            }}
            aria-label="Retour"
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-surface text-ink shadow-[0_1px_3px_rgba(43,42,38,.08)]"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" className="h-4.5 w-4.5">
              <path d="M15 18l-6-6 6-6" />
            </svg>
          </button>
          <h2 className="min-w-0 truncate text-[1.1rem] font-extrabold tracking-tight text-ink">{title}</h2>
          {!isToday && (
            <span className="ml-auto shrink-0 rounded-full bg-gold/15 px-3 py-1 text-[0.78rem] font-bold text-gold">📅 {dayLabel(day)}</span>
          )}
        </div>
      </header>

      <main className="mx-auto flex max-w-[640px] flex-col gap-4 px-4 pb-16 pt-5">
        {error && <p className="rounded-xl bg-accent/10 px-3.5 py-2.5 text-[0.85rem] font-medium text-accent">{error}</p>}

        {stage === "choose" && (
          <>
            <input
              ref={photoInput}
              type="file"
              accept="image/png,image/jpeg,image/webp,image/gif"
              capture="environment"
              hidden
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) handlePhoto(f);
                e.target.value = "";
              }}
            />
            <BigChoice
              emoji="📸"
              title="Prendre une photo"
              subtitle="Ton assiette (1 personne) → calories détaillées et ingrédients"
              onClick={() => photoInput.current?.click()}
              primary
            />
            <BigChoice
              emoji="✍️"
              title="Décrire ce que j'ai mangé"
              subtitle="Un ou plusieurs plats, ex. « crêpes et poulet sauce soja » → calories et ingrédients"
              onClick={() => {
                setError(null);
                setStage("describe");
              }}
            />
            <HabitsList habits={habits} onLog={logHabit} showType />
            <BigChoice
              emoji="📖"
              title="Trouver une recette"
              subtitle="Un plat, pour le nombre de personnes choisi → recette complète et ingrédients"
              onClick={() => {
                setError(null);
                setStage("text");
              }}
            />
          </>
        )}

        {stage === "describe" && preset && <HabitsList habits={habits} onLog={logHabit} />}

        {stage === "describe" && (
          <form
            onSubmit={(e) => {
              e.preventDefault();
              describeMeal();
            }}
            className="flex flex-col gap-5"
          >
            <label className="flex flex-col gap-2">
              <span className="text-[0.9rem] font-bold text-ink">
                {preset && habits.length ? "Autre chose ? " : ""}
                {snack ? "Qu'as-tu pris ?" : "Qu'as-tu mangé ?"}
              </span>
              <textarea
                autoFocus={!habits.length || !preset}
                rows={3}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder={
                  snack
                    ? "ex : une pomme et 3 carrés de chocolat"
                    : preset === "breakfast"
                      ? "ex : café au lait, 2 tartines beurre-confiture"
                      : "ex : 2 crêpes et du poulet sauce soja avec du riz"
                }
                className="w-full resize-none rounded-2xl border-2 border-line bg-surface px-4 py-3.5 text-[1.05rem] text-ink outline-none focus:border-accent"
              />
            </label>
            {snack && (
              <div className="flex flex-col gap-2">
                <span className="text-[0.8rem] font-semibold text-ink-soft">Idées — touche pour ajouter</span>
                <div className="flex flex-wrap gap-1.5">
                  {SNACK_IDEAS.map((idea) => (
                    <button
                      key={idea}
                      type="button"
                      onClick={() => setDescription((d) => (d.trim() ? `${d.trim()}, ${idea.toLowerCase()}` : idea))}
                      className="rounded-full border-2 border-line bg-surface px-3 py-1.5 text-[0.8rem] font-semibold text-ink-soft hover:border-accent hover:text-accent"
                    >
                      + {idea}
                    </button>
                  ))}
                </div>
              </div>
            )}
            <button
              type="submit"
              className="rounded-2xl bg-accent px-4 py-4 text-[1rem] font-bold text-accent-ink shadow-[0_2px_10px_-2px_rgba(255,90,54,.65)] active:scale-[.98]"
            >
              Estimer les calories
            </button>
          </form>
        )}

        {stage === "text" && (
          <form
            onSubmit={(e) => {
              e.preventDefault();
              searchRecipe();
            }}
            className="flex flex-col gap-5"
          >
            <label className="flex flex-col gap-2">
              <span className="text-[0.9rem] font-bold text-ink">Quel repas ?</span>
              <input
                autoFocus
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="ex : crêpes, lasagnes, un lien de recette…"
                className="w-full rounded-2xl border-2 border-line bg-surface px-4 py-3.5 text-[1.05rem] text-ink outline-none focus:border-accent"
              />
            </label>
            <div className="flex flex-col gap-2">
              <span className="text-[0.9rem] font-bold text-ink">Pour combien de personnes ?</span>
              <Stepper value={persons} onChange={setPersons} min={1} max={20} step={1} suffix={persons > 1 ? "personnes" : "personne"} />
            </div>
            <button
              type="submit"
              className="rounded-2xl bg-accent px-4 py-4 text-[1rem] font-bold text-accent-ink shadow-[0_2px_10px_-2px_rgba(255,90,54,.65)] active:scale-[.98]"
            >
              Trouver la recette
            </button>
          </form>
        )}

        {stage === "loading" && (
          <div className="flex flex-col items-center gap-4 py-16 text-center">
            {photoPreview && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={photoPreview} alt="" className="h-40 w-40 rounded-3xl object-cover shadow" />
            )}
            <span className="h-8 w-8 animate-spin rounded-full border-3 border-line border-t-accent" />
            <p className="text-[0.95rem] font-semibold text-ink">{loadingLabel}</p>
          </div>
        )}

        {stage === "result" && draft && (
          <>
            {(photoPreview || suggestedPhoto) && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={photoPreview || suggestedPhoto || ""} alt="" className="h-48 w-full rounded-3xl object-cover" />
            )}

            <p className="-mb-1 text-[0.8rem] font-semibold uppercase tracking-wider text-ink-soft">
              {kind === "meal" ? "Ce que tu as mangé · 1 personne" : `Recette pour ${draft.servings} personne${draft.servings > 1 ? "s" : ""}`}
            </p>

            {lastChange && (
              <p className="rounded-xl bg-herb/10 px-3.5 py-2.5 text-[0.84rem] font-semibold text-herb">✓ Adapté : « {lastChange} »</p>
            )}

            {matchedRecipe && (
              <p className="rounded-xl bg-surface px-3.5 py-2.5 text-[0.84rem] text-ink">
                Ça ressemble à <strong>{matchedRecipe.name}</strong>, déjà dans tes recettes.
              </p>
            )}

            <NutritionCard draft={draft} perLabel={kind === "meal" ? "dans ton assiette" : "par personne"} />

            <Section title={kind === "meal" ? "Ce que tu as mangé" : "Ingrédients"}>
              {draft.ingr.length ? (
                <ul className="flex flex-col divide-y divide-line">
                  {draft.ingr.map((i, idx) => (
                    <li key={idx} className="flex items-baseline justify-between gap-3 py-2 text-[0.92rem]">
                      <span className="text-ink">{i.name}</span>
                      <span className="shrink-0 font-mono text-[0.84rem] text-ink-soft">{i.qty}</span>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="text-[0.85rem] text-ink-soft">Aucun ingrédient détecté.</p>
              )}
            </Section>

            {draft.steps.length > 0 && (
              <Section title="Préparation">
                <ol className="flex flex-col gap-2.5">
                  {draft.steps.map((s, idx) => (
                    <li key={idx} className="flex gap-3 text-[0.92rem] leading-relaxed text-ink">
                      <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-accent text-[0.75rem] font-bold text-accent-ink">
                        {idx + 1}
                      </span>
                      {s}
                    </li>
                  ))}
                </ol>
              </Section>
            )}

            <Section title="Adapter">
              <div className="mb-2.5 flex flex-wrap gap-1.5">
                {(kind === "meal" ? MEAL_SUGGESTIONS : [`Pour ${draft.servings + 2} personnes`, ...TEXT_SUGGESTIONS]).map((s) => (
                  <button
                    key={s}
                    disabled={iterating}
                    onClick={() => iterate(s)}
                    className="rounded-full border-2 border-line bg-surface px-3 py-1.5 text-[0.8rem] font-semibold text-ink-soft hover:border-accent hover:text-accent disabled:opacity-50"
                  >
                    {s}
                  </button>
                ))}
              </div>
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  iterate(instruction);
                }}
                className="flex gap-2"
              >
                <input
                  value={instruction}
                  onChange={(e) => setInstruction(e.target.value)}
                  disabled={iterating}
                  placeholder={kind === "meal" ? "ex : c'était du riz complet" : "ex : remplace le lait par du lait d'avoine"}
                  className="min-w-0 flex-1 rounded-xl border-2 border-line bg-surface-2 px-3 py-2.5 text-[0.9rem] text-ink outline-none focus:border-accent"
                />
                <button
                  type="submit"
                  disabled={iterating || !instruction.trim()}
                  className="inline-flex shrink-0 items-center gap-1.5 rounded-xl bg-ink px-4 py-2.5 text-[0.85rem] font-bold text-bg disabled:opacity-40"
                >
                  {iterating && <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-bg/40 border-t-bg" />}
                  {iterating ? "…" : "Adapter"}
                </button>
              </form>
            </Section>

            <Section title="Et maintenant ?">
              <div className="flex flex-col gap-3">
                <div className="flex flex-wrap gap-1.5">
                  {MEAL_TYPES.map((m) => (
                    <button
                      key={m.key}
                      onClick={() => setMealType(m.key)}
                      className={`rounded-full border-2 px-3 py-1.5 text-[0.8rem] font-semibold ${
                        mealType === m.key ? "border-accent bg-accent text-accent-ink" : "border-line bg-surface text-ink-soft"
                      }`}
                    >
                      {m.label}
                    </button>
                  ))}
                </div>
                <div className="flex flex-wrap items-center gap-3">
                  <span className="text-[0.85rem] font-semibold text-ink-soft">{kind === "meal" ? "Assiettes mangées" : "Portions mangées"}</span>
                  <Stepper value={portions} onChange={setPortions} min={0.5} max={10} step={0.5} />
                  <span className="font-mono text-[0.85rem] text-ink">{Math.round((draft.nutrition?.kcal ?? 0) * portions)} kcal</span>
                </div>
                <button
                  onClick={logMeal}
                  disabled={logged || busyAction !== null}
                  className={`rounded-2xl px-4 py-3.5 text-[0.95rem] font-bold ${
                    logged ? "bg-herb text-white" : "bg-accent text-accent-ink shadow-[0_2px_10px_-2px_rgba(255,90,54,.65)]"
                  } disabled:cursor-default`}
                >
                  {logged
                    ? `✓ Ajouté à ${isToday ? "ta journée" : dayLabel(day).toLowerCase()}`
                    : busyAction === "log"
                      ? "Enregistrement…"
                      : isToday
                        ? "J'ai mangé ça"
                        : `J'ai mangé ça ${dayLabel(day).toLowerCase()}`}
                </button>
                <button
                  onClick={saveRecipe}
                  disabled={Boolean(savedRecipeId) || busyAction !== null}
                  className={`rounded-2xl border-2 px-4 py-3.5 text-[0.95rem] font-bold ${
                    savedRecipeId ? "border-herb text-herb" : "border-line bg-surface text-ink hover:border-accent"
                  } disabled:cursor-default`}
                >
                  {savedRecipeId ? "✓ Dans mes recettes" : busyAction === "save" ? "Enregistrement…" : "Garder dans mes recettes"}
                </button>
                <button onClick={onClose} className="py-2 text-[0.88rem] font-semibold text-ink-soft underline decoration-dotted underline-offset-4">
                  Terminé
                </button>
              </div>
            </Section>
          </>
        )}
      </main>
    </div>
  );
}

function BigChoice({
  emoji,
  title,
  subtitle,
  onClick,
  primary,
}: {
  emoji: string;
  title: string;
  subtitle: string;
  onClick: () => void;
  primary?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      className={`flex items-center gap-4 rounded-3xl p-5 text-left transition active:scale-[.98] ${
        primary ? "bg-accent text-accent-ink shadow-[0_6px_20px_-6px_rgba(255,90,54,.7)]" : "bg-surface text-ink shadow-[0_1px_3px_rgba(43,42,38,.08)]"
      }`}
    >
      <span className="text-[2.4rem] leading-none">{emoji}</span>
      <span className="flex flex-col gap-1">
        <span className="text-[1.15rem] font-extrabold">{title}</span>
        <span className={`text-[0.85rem] ${primary ? "text-accent-ink/85" : "text-ink-soft"}`}>{subtitle}</span>
      </span>
    </button>
  );
}

function Stepper({
  value,
  onChange,
  min,
  max,
  step,
  suffix,
}: {
  value: number;
  onChange: (v: number) => void;
  min: number;
  max: number;
  step: number;
  suffix?: string;
}) {
  const btn = "flex h-10 w-10 items-center justify-center rounded-full bg-surface text-[1.3rem] font-bold text-ink shadow-[0_1px_3px_rgba(43,42,38,.12)] disabled:opacity-40";
  return (
    <div className="flex items-center gap-3">
      <button type="button" className={btn} disabled={value <= min} onClick={() => onChange(Math.max(min, value - step))} aria-label="Moins">
        −
      </button>
      <span className="min-w-8 text-center text-[1.2rem] font-extrabold text-ink">{value}</span>
      <button type="button" className={btn} disabled={value >= max} onClick={() => onChange(Math.min(max, value + step))} aria-label="Plus">
        +
      </button>
      {suffix && <span className="text-[0.9rem] text-ink-soft">{suffix}</span>}
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="rounded-3xl bg-surface p-4.5 shadow-[0_1px_3px_rgba(43,42,38,.08)]">
      <h3 className="mb-3 text-[0.78rem] font-bold uppercase tracking-wider text-ink-soft">{title}</h3>
      {children}
    </section>
  );
}

/** Calories + répartition protéines/glucides/lipides (en grammes et en part
 * des calories) — le "split" demandé, identique pour photo et texte. */
function NutritionCard({ draft, perLabel }: { draft: RecipeDraft; perLabel: string }) {
  const n = draft.nutrition;
  if (!n) {
    return (
      <Section title="Calories">
        <p className="text-[0.85rem] text-ink-soft">Pas d&apos;estimation disponible — utilise « Adapter » pour la demander.</p>
      </Section>
    );
  }
  const macros = [
    { label: "Protéines", g: n.proteinG, kcal: n.proteinG * 4, color: "#E5484D" },
    { label: "Glucides", g: n.carbsG, kcal: n.carbsG * 4, color: "#FFC93C" },
    { label: "Lipides", g: n.fatG, kcal: n.fatG * 9, color: "#17A2B8" },
  ];
  const total = macros.reduce((a, m) => a + m.kcal, 0) || 1;
  return (
    <section className="rounded-3xl bg-surface p-4.5 shadow-[0_1px_3px_rgba(43,42,38,.08)]">
      <div className="flex items-baseline gap-2">
        <span className="font-mono text-[2.2rem] font-extrabold leading-none text-ink">{Math.round(n.kcal)}</span>
        <span className="text-[0.9rem] font-semibold text-ink-soft">kcal {perLabel}</span>
        {n.gramsPerServing > 0 && <span className="ml-auto text-[0.8rem] text-ink-soft">≈ {n.gramsPerServing} g</span>}
      </div>
      <div className="mt-3.5 flex h-3 overflow-hidden rounded-full bg-surface-2">
        {macros.map((m) => (
          <div key={m.label} style={{ width: `${(m.kcal / total) * 100}%`, backgroundColor: m.color }} />
        ))}
      </div>
      <div className="mt-3 grid grid-cols-3 gap-2">
        {macros.map((m) => (
          <div key={m.label} className="rounded-2xl bg-surface-2 px-3 py-2.5">
            <div className="flex items-center gap-1.5 text-[0.74rem] font-semibold text-ink-soft">
              <span className="h-2 w-2 rounded-full" style={{ backgroundColor: m.color }} />
              {m.label}
            </div>
            <div className="mt-1 font-mono text-[1.05rem] font-bold text-ink">{Math.round(m.g)} g</div>
            <div className="text-[0.72rem] text-ink-soft">{Math.round((m.kcal / total) * 100)} %</div>
          </div>
        ))}
      </div>
    </section>
  );
}

function validCat(c: unknown): CategoryKey {
  return CATEGORIES.some((x) => x.key === c) ? (c as CategoryKey) : "viande";
}

function cleanIngredients(v: unknown): Ingredient[] {
  if (!Array.isArray(v)) return [];
  return v
    .filter((i): i is { name: unknown; qty: unknown } => Boolean(i) && typeof i === "object")
    .map((i) => ({ name: String(i.name ?? "").trim(), qty: String(i.qty ?? "").trim() }))
    .filter((i) => i.name);
}

function normalizeDraft(raw: unknown, fallbackName: string): RecipeDraft {
  const d = (raw && typeof raw === "object" ? raw : {}) as Partial<Record<keyof RecipeDraft, unknown>>;
  return {
    name: typeof d.name === "string" && d.name.trim() ? d.name.trim() : fallbackName,
    cat: validCat(d.cat),
    time: Number(d.time) > 0 ? Math.round(Number(d.time)) : 30,
    diff: DIFFICULTIES.includes(d.diff as Difficulty) ? (d.diff as Difficulty) : "Facile",
    servings: Number(d.servings) > 0 ? Math.round(Number(d.servings)) : 1,
    veg: Boolean(d.veg),
    ingr: cleanIngredients(d.ingr),
    steps: Array.isArray(d.steps) ? d.steps.map((s) => String(s).trim()).filter(Boolean) : [],
    nutrition: sanitizeNutrition(d.nutrition, "ai"),
  };
}

function recipeToDraft(r: Recipe): RecipeDraft {
  return {
    name: r.name,
    cat: r.cat,
    time: r.time,
    diff: r.diff,
    servings: r.servings,
    veg: r.veg,
    ingr: r.ingr,
    steps: r.steps,
    nutrition: r.nutrition ?? null,
  };
}
