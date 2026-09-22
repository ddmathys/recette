"use client";

import { useState } from "react";
import { CATEGORIES } from "@/lib/categories";
import { compressImageIfNeeded } from "@/lib/compressImage";
import { auth } from "@/lib/firebase";
import { MEAL_TYPES, guessMealType } from "@/lib/mealTypes";
import { sanitizeNutrition, scaleNutritionToGrams } from "@/lib/nutrition";
import { addRecipe, uploadRecipePhoto } from "@/lib/useRecipes";
import { addMealLog, uploadMealPhoto } from "@/lib/useMealLogs";
import type { CategoryKey, Difficulty, Ingredient, MealType, Recipe, RecipeDraft } from "@/lib/types";
import { Field } from "./RecipeFormFields";
import { RecipeCoreFields } from "./RecipeCoreFields";
import { NutritionFields } from "./NutritionFields";

const DIFFICULTIES: Difficulty[] = ["Facile", "Moyen", "Avancé"];
const MAX_PHOTO_BYTES = 10 * 1024 * 1024;

type SourceMode = "photo" | "text" | "manual";
type Stage = "source" | "review";

const BLANK_DRAFT: RecipeDraft = {
  name: "",
  cat: "viande",
  time: 30,
  diff: "Facile",
  servings: 4,
  veg: false,
  ingr: [{ name: "", qty: "" }],
  steps: [""],
  nutrition: null,
};

/**
 * Point d'entrée unique pour "j'ai un repas" — remplace AddRecipeDialog et
 * LogMealDialog. Deux issues possibles, combinables : logguer le repas du
 * jour (mealLogs) et/ou l'ajouter à la bibliothèque (recipes). Trois
 * sources possibles à l'étape 1 : photo (Gemini), texte/lien (DeepSeek),
 * ou manuel. `initialRecipe` saute l'étape 1 (cas "Manger ce repas" depuis
 * la fiche recette : la recette existe déjà, on va direct à la review).
 */
export function CaptureDialog({
  recipes,
  owner,
  initialRecipe,
  defaultLogMeal,
  defaultAddToLibrary,
  onClose,
}: {
  recipes: Recipe[];
  owner: { uid: string; name: string; householdId: string };
  initialRecipe?: Recipe | null;
  defaultLogMeal: boolean;
  defaultAddToLibrary: boolean;
  onClose: () => void;
}) {
  const [stage, setStage] = useState<Stage>(initialRecipe ? "review" : "source");
  const [sourceMode, setSourceMode] = useState<SourceMode>("photo");

  // Stage "source" — texte/lien
  const [text, setText] = useState("");
  const [name, setName] = useState("");
  const [link, setLink] = useState("");
  const [aiBusy, setAiBusy] = useState(false);
  const [aiError, setAiError] = useState<string | null>(null);
  const [suggestedPhoto, setSuggestedPhoto] = useState<string | null>(null);

  // Photo (partagée entre l'étape source-photo et la review)
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
  const [uploadedPhotoUrl, setUploadedPhotoUrl] = useState<string | null>(null);
  const [photoBusy, setPhotoBusy] = useState(false);
  const [analyzing, setAnalyzing] = useState(false);
  const [photoError, setPhotoError] = useState<string | null>(null);

  // Review
  const [draft, setDraft] = useState<RecipeDraft>(() =>
    initialRecipe
      ? {
          name: initialRecipe.name,
          cat: initialRecipe.cat,
          time: initialRecipe.time,
          diff: initialRecipe.diff,
          servings: initialRecipe.servings,
          veg: initialRecipe.veg,
          ingr: initialRecipe.ingr,
          steps: initialRecipe.steps,
          nutrition: initialRecipe.nutrition ?? null,
        }
      : BLANK_DRAFT,
  );
  const [matchedRecipeId, setMatchedRecipeId] = useState<string | null>(initialRecipe?.id ?? null);
  const [logMeal, setLogMeal] = useState(defaultLogMeal);
  const [addToLibrary, setAddToLibrary] = useState(initialRecipe ? false : defaultAddToLibrary);
  const [mealType, setMealType] = useState<MealType>(guessMealType());
  const [eatenAt, setEatenAt] = useState(() => toDatetimeLocal(new Date()));
  const [portionGrams, setPortionGrams] = useState(initialRecipe?.nutrition?.gramsPerServing ?? 250);
  const [kcal, setKcal] = useState(initialRecipe?.nutrition?.kcal ?? 0);
  const [proteinG, setProteinG] = useState(initialRecipe?.nutrition?.proteinG ?? 0);
  const [carbsG, setCarbsG] = useState(initialRecipe?.nutrition?.carbsG ?? 0);
  const [fatG, setFatG] = useState(initialRecipe?.nutrition?.fatG ?? 0);

  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  const matchedRecipe = matchedRecipeId ? recipes.find((r) => r.id === matchedRecipeId) ?? null : null;

  function applyPortion(grams: number, nutrition = draft.nutrition) {
    setPortionGrams(grams);
    if (nutrition) {
      const scaled = scaleNutritionToGrams(nutrition, grams);
      setKcal(scaled.kcal);
      setProteinG(scaled.proteinG);
      setCarbsG(scaled.carbsG);
      setFatG(scaled.fatG);
    }
  }

  async function handlePhotoInput(f: File) {
    setPhotoError(null);
    setPhotoBusy(true);
    try {
      const toUse = await compressImageIfNeeded(f, MAX_PHOTO_BYTES);
      if (toUse.size > MAX_PHOTO_BYTES) {
        setPhotoError("Photo trop lourde (max 10 Mo), même après compression.");
        return;
      }
      setPhotoFile(toUse);
      setPhotoPreview(URL.createObjectURL(toUse));
      setUploadedPhotoUrl(null);
    } finally {
      setPhotoBusy(false);
    }
  }

  async function analyzePhoto() {
    if (!photoFile) return;
    setAnalyzing(true);
    setPhotoError(null);
    try {
      const url = await uploadMealPhoto(owner.uid, photoFile);
      setUploadedPhotoUrl(url);
      const idToken = await auth?.currentUser?.getIdToken();
      const res = await fetch("/api/analyze-meal-photo", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
        },
        body: JSON.stringify({ photoUrl: url, recipes: recipes.map((r) => ({ id: r.id, name: r.name })) }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "La reconnaissance photo a échoué.");
      const d = data.draft as Record<string, unknown>;

      const matched = typeof d.matchedRecipeId === "string" ? recipes.find((r) => r.id === d.matchedRecipeId) : null;
      const label = typeof d.label === "string" && d.label.trim() ? d.label.trim() : "Repas";
      const analyzedNutrition = sanitizeNutrition(
        {
          kcal: d.kcal,
          proteinG: d.proteinG,
          carbsG: d.carbsG,
          fatG: d.fatG,
          gramsPerServing: d.portionGrams,
        },
        "ai",
      );

      if (matched) {
        setMatchedRecipeId(matched.id);
        setAddToLibrary(false);
        setDraft({ ...BLANK_DRAFT, name: matched.name, nutrition: matched.nutrition ?? analyzedNutrition });
        applyPortion(Number(d.portionGrams) > 0 ? Number(d.portionGrams) : (matched.nutrition?.gramsPerServing ?? 250), matched.nutrition ?? analyzedNutrition);
      } else {
        setMatchedRecipeId(null);
        setDraft((prev) => ({ ...prev, name: label, nutrition: analyzedNutrition ?? prev.nutrition }));
        applyPortion(Number(d.portionGrams) > 0 ? Number(d.portionGrams) : portionGrams, analyzedNutrition ?? draft.nutrition);
      }
      if (MEAL_TYPES.some((m) => m.key === d.mealType)) setMealType(d.mealType as MealType);
      setStage("review");
    } catch (e) {
      setPhotoError(e instanceof Error ? e.message : "La reconnaissance photo a échoué. Tu peux remplir manuellement.");
    } finally {
      setAnalyzing(false);
    }
  }

  async function generateWithAi() {
    if (!text.trim() && !name.trim() && !link.trim()) {
      setAiError("Écris un nom de plat, colle un texte, ou donne un lien avant de générer.");
      return;
    }
    setAiBusy(true);
    setAiError(null);
    try {
      const idToken = await auth?.currentUser?.getIdToken();
      const res = await fetch("/api/parse-recipe", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
        },
        body: JSON.stringify({ text, name, link }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "La génération IA a échoué.");
      const d = data.draft as Partial<RecipeDraft>;
      const validCat = CATEGORIES.some((c) => c.key === d.cat) ? (d.cat as CategoryKey) : "viande";
      const validDiff = DIFFICULTIES.includes(d.diff as Difficulty) ? (d.diff as Difficulty) : "Facile";
      const nutrition = sanitizeNutrition(d.nutrition, "ai");
      setDraft({
        name: d.name || name.trim() || "",
        cat: validCat,
        time: Number(d.time) > 0 ? Number(d.time) : 30,
        diff: validDiff,
        servings: Number(d.servings) > 0 ? Number(d.servings) : 4,
        veg: Boolean(d.veg),
        ingr: Array.isArray(d.ingr) && d.ingr.length ? (d.ingr as Ingredient[]) : [{ name: "", qty: "" }],
        steps: Array.isArray(d.steps) && d.steps.length ? (d.steps as string[]) : [""],
        nutrition,
      });
      if (nutrition) applyPortion(nutrition.gramsPerServing, nutrition);
      if (data.ogImage) setSuggestedPhoto(data.ogImage);
      setStage("review");
    } catch (e) {
      setAiError(e instanceof Error ? e.message : "La génération IA a échoué. Tu peux remplir manuellement.");
    } finally {
      setAiBusy(false);
    }
  }

  function startManual() {
    setDraft({ ...BLANK_DRAFT, name: name.trim() });
    setStage("review");
  }

  async function handleSave() {
    const trimmedName = draft.name.trim();
    if (!trimmedName) {
      setSaveError("Donne un nom à ce repas.");
      return;
    }
    if (!logMeal && !addToLibrary) {
      setSaveError("Choisis au moins une option : repas mangé, ou ajouter à la bibliothèque.");
      return;
    }
    if (logMeal && (!portionGrams || portionGrams <= 0)) {
      setSaveError("Indique une quantité en grammes pour le repas.");
      return;
    }
    setSaving(true);
    setSaveError(null);
    try {
      let recipeIdForLog = matchedRecipeId;
      const recipePhotoUrl = uploadedPhotoUrl || (photoFile ? null : suggestedPhoto);

      if (addToLibrary && !matchedRecipeId) {
        const ingr = draft.ingr.map((i) => ({ name: i.name.trim(), qty: i.qty.trim() })).filter((i) => i.name);
        const steps = draft.steps.map((s) => s.trim()).filter(Boolean);
        const finalDraft: RecipeDraft = { ...draft, name: trimmedName, ingr, steps };
        recipeIdForLog = await addRecipe(finalDraft, link.trim() || null, photoFile ? null : recipePhotoUrl, owner);
        if (photoFile && !uploadedPhotoUrl) {
          // Photo prise dans l'onglet texte/manuel (pas encore uploadée pour l'analyse) — l'attacher à la recette.
          try {
            await uploadRecipePhoto(recipeIdForLog, photoFile);
          } catch {
            // Best effort : la recette existe déjà, une photo ratée n'est qu'un avertissement.
          }
        }
      }

      if (logMeal) {
        const eatenAtDate = new Date(eatenAt);
        await addMealLog(
          {
            recipeId: recipeIdForLog,
            label: trimmedName,
            mealType,
            eatenAt: (Number.isNaN(eatenAtDate.getTime()) ? new Date() : eatenAtDate).toISOString(),
            portionGrams,
            kcal,
            proteinG,
            carbsG,
            fatG,
          },
          uploadedPhotoUrl,
          uploadedPhotoUrl ? "photo" : recipeIdForLog ? "recipe" : "manual",
          owner,
        );
      }
      onClose();
    } catch {
      setSaveError("L'enregistrement a échoué, réessaie.");
      setSaving(false);
    }
  }

  return (
    <>
      <div className="fixed inset-0 z-42 bg-black/40" onClick={onClose} />
      <div className="fixed left-1/2 top-1/2 z-43 max-h-[90dvh] w-[min(640px,calc(100vw-32px))] -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-[20px] bg-surface shadow-[-4px_12px_40px_-10px_rgba(0,0,0,.4)]">
        <div className="sticky top-0 z-10 flex items-center justify-between gap-2.5 rounded-t-[20px] border-b border-line bg-surface px-5 py-4.5">
          <h2 className="text-[1.15rem] font-semibold">{stage === "source" ? "Nouveau repas" : "Vérifier et enregistrer"}</h2>
          <button onClick={onClose} aria-label="Fermer" className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-2 text-ink">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-4 w-4">
              <path d="M6 6l12 12M18 6 6 18" />
            </svg>
          </button>
        </div>

        <div className="flex flex-col gap-3.5 px-5 pb-6.5 pt-4.5">
          {stage === "source" && (
            <>
              <div className="flex gap-2">
                {(
                  [
                    ["photo", "Photo"],
                    ["text", "Texte ou lien"],
                    ["manual", "Manuel"],
                  ] as [SourceMode, string][]
                ).map(([key, label]) => (
                  <button
                    key={key}
                    onClick={() => setSourceMode(key)}
                    className={`flex-1 rounded-lg border-2 px-3 py-2 text-[0.85rem] font-semibold ${
                      sourceMode === key ? "border-accent bg-accent/10 text-accent" : "border-line text-ink-soft"
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>

              {sourceMode === "photo" && (
                <div className="flex flex-col gap-2.5">
                  <div className="flex flex-wrap items-center gap-3">
                    {photoPreview && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={photoPreview} alt="" className="h-16 w-16 rounded-[10px] border border-line object-cover" />
                    )}
                    <label className="cursor-pointer rounded-xl border border-line bg-surface px-3.5 py-2 text-[0.85rem] text-ink hover:bg-surface-2">
                      {photoBusy ? "Compression…" : photoFile ? "Changer la photo" : "Prendre / choisir une photo"}
                      <input
                        type="file"
                        accept="image/png,image/jpeg,image/webp,image/gif"
                        capture="environment"
                        hidden
                        disabled={photoBusy || analyzing}
                        onChange={(e) => {
                          const f = e.target.files?.[0];
                          if (f) handlePhotoInput(f);
                          e.target.value = "";
                        }}
                      />
                    </label>
                    {photoFile && (
                      <button
                        onClick={analyzePhoto}
                        disabled={analyzing}
                        className="inline-flex items-center gap-1.5 rounded-xl bg-accent px-3.5 py-2 text-[0.83rem] font-medium text-accent-ink disabled:opacity-60"
                      >
                        {analyzing && <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-line border-t-accent-ink" />}
                        {analyzing ? "Analyse…" : "Analyser (Gemini)"}
                      </button>
                    )}
                  </div>
                  {photoError && <p className="text-[0.76rem] text-accent">{photoError}</p>}
                  <p className="text-[0.76rem] text-ink-soft">
                    L&apos;IA propose un titre, une portion et des calories à partir de la photo — tu vérifies et corriges à l&apos;étape suivante.
                  </p>
                  <button
                    onClick={startManual}
                    className="self-start text-[0.8rem] font-semibold text-ink-soft underline decoration-dotted underline-offset-2 hover:text-accent"
                  >
                    Passer, remplir à la main
                  </button>
                </div>
              )}

              {sourceMode === "text" && (
                <div className="flex flex-col gap-3">
                  <Field label="Ta recette, en texte libre">
                    <textarea
                      rows={5}
                      value={text}
                      onChange={(e) => setText(e.target.value)}
                      placeholder="Colle ou tape ce que tu as : le nom du plat, les ingrédients, les étapes — l'IA range tout. Même juste un nom de plat suffit."
                      className="w-full resize-y rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
                    />
                  </Field>
                  <div className="flex flex-wrap gap-3">
                    <Field label="Nom du plat (si tu veux le préciser)" className="flex-1 basis-35">
                      <input
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        placeholder="ex : Tarte aux poireaux"
                        className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
                      />
                    </Field>
                    <Field label="Lien source (optionnel)" className="flex-1 basis-35">
                      <input
                        type="url"
                        value={link}
                        onChange={(e) => setLink(e.target.value)}
                        placeholder="https://..."
                        className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
                      />
                    </Field>
                  </div>
                  <button
                    onClick={generateWithAi}
                    disabled={aiBusy}
                    className="inline-flex items-center gap-1.5 self-start rounded-xl bg-accent px-3.5 py-2.5 text-[0.85rem] font-medium text-accent-ink disabled:opacity-60"
                  >
                    {aiBusy && <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-line border-t-accent-ink" />}
                    {aiBusy ? "DeepSeek réfléchit…" : "Générer avec l'IA (DeepSeek)"}
                  </button>
                  {aiError && <p className="text-[0.83rem] text-accent">{aiError}</p>}
                </div>
              )}

              {sourceMode === "manual" && (
                <button
                  onClick={startManual}
                  className="self-start rounded-xl bg-accent px-3.5 py-2.5 text-[0.85rem] font-medium text-accent-ink"
                >
                  Remplir manuellement
                </button>
              )}
            </>
          )}

          {stage === "review" && (
            <form
              onSubmit={(e) => {
                e.preventDefault();
                handleSave();
              }}
              className="flex flex-col gap-3.5"
            >
              {matchedRecipe && (
                <div className="rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-[0.82rem] text-ink">
                  Reconnu comme <strong>{matchedRecipe.name}</strong>, déjà dans ta bibliothèque.{" "}
                  <button
                    type="button"
                    onClick={() => setMatchedRecipeId(null)}
                    className="font-semibold text-accent underline decoration-dotted underline-offset-2"
                  >
                    Ce n&apos;est pas la bonne recette
                  </button>
                </div>
              )}

              {!initialRecipe && !matchedRecipeId && (
                <div className="flex flex-col gap-2 rounded-xl border border-line bg-surface-2 px-3.5 py-3">
                  <label className="flex items-center gap-2 text-[0.86rem] font-semibold text-ink">
                    <input type="checkbox" checked={logMeal} onChange={(e) => setLogMeal(e.target.checked)} />
                    Repas mangé (compte dans le journal du jour)
                  </label>
                  <label className="flex items-center gap-2 text-[0.86rem] font-semibold text-ink">
                    <input type="checkbox" checked={addToLibrary} onChange={(e) => setAddToLibrary(e.target.checked)} />
                    Ajouter à ma bibliothèque de recettes
                  </label>
                </div>
              )}
              {initialRecipe && (
                <label className="flex items-center gap-2 text-[0.86rem] font-semibold text-ink">
                  <input type="checkbox" checked={logMeal} onChange={(e) => setLogMeal(e.target.checked)} />
                  Repas mangé (compte dans le journal du jour)
                </label>
              )}

              {addToLibrary && !matchedRecipeId ? (
                <RecipeCoreFields draft={draft} setDraft={setDraft} />
              ) : (
                <>
                  <Field label="Nom du repas">
                    <input
                      value={draft.name}
                      onChange={(e) => setDraft((d) => ({ ...d, name: e.target.value }))}
                      className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none"
                    />
                  </Field>
                  {!matchedRecipeId && <NutritionFields draft={draft} setDraft={setDraft} />}
                </>
              )}

              {logMeal && (
                <div className="flex flex-col gap-3 rounded-xl border border-line bg-surface-2 px-3.5 py-3.5">
                  <p className="text-[0.72rem] font-semibold uppercase tracking-wider text-ink-soft">Ce que tu as vraiment mangé</p>
                  <div className="flex flex-wrap gap-3">
                    <Field label="Type de repas" className="flex-1 basis-35">
                      <select
                        value={mealType}
                        onChange={(e) => setMealType(e.target.value as MealType)}
                        className="w-full rounded-lg border border-line bg-surface px-2.5 py-2 text-[0.9rem] text-ink outline-none"
                      >
                        {MEAL_TYPES.map((m) => (
                          <option key={m.key} value={m.key}>
                            {m.label}
                          </option>
                        ))}
                      </select>
                    </Field>
                    <Field label="Mangé le" className="flex-1 basis-35">
                      <input
                        type="datetime-local"
                        value={eatenAt}
                        onChange={(e) => setEatenAt(e.target.value)}
                        className="w-full rounded-lg border border-line bg-surface px-2.5 py-2 text-[0.9rem] text-ink outline-none"
                      />
                    </Field>
                  </div>
                  <div className="flex flex-wrap gap-3">
                    <Field label="Portion mangée (g)" className="flex-1 basis-24">
                      <input
                        type="number"
                        min={0}
                        value={portionGrams}
                        onChange={(e) => applyPortion(Number(e.target.value) || 0, matchedRecipe?.nutrition ?? draft.nutrition)}
                        className="w-full rounded-lg border border-line bg-surface px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
                      />
                    </Field>
                    <Field label="Kcal" className="flex-1 basis-24">
                      <input
                        type="number"
                        min={0}
                        value={kcal}
                        onChange={(e) => setKcal(Number(e.target.value) || 0)}
                        className="w-full rounded-lg border border-line bg-surface px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
                      />
                    </Field>
                    <Field label="Protéines (g)" className="flex-1 basis-24">
                      <input
                        type="number"
                        min={0}
                        value={proteinG}
                        onChange={(e) => setProteinG(Number(e.target.value) || 0)}
                        className="w-full rounded-lg border border-line bg-surface px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
                      />
                    </Field>
                    <Field label="Glucides (g)" className="flex-1 basis-24">
                      <input
                        type="number"
                        min={0}
                        value={carbsG}
                        onChange={(e) => setCarbsG(Number(e.target.value) || 0)}
                        className="w-full rounded-lg border border-line bg-surface px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
                      />
                    </Field>
                    <Field label="Lipides (g)" className="flex-1 basis-24">
                      <input
                        type="number"
                        min={0}
                        value={fatG}
                        onChange={(e) => setFatG(Number(e.target.value) || 0)}
                        className="w-full rounded-lg border border-line bg-surface px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
                      />
                    </Field>
                  </div>
                </div>
              )}

              {saveError && <p className="text-[0.83rem] text-accent">{saveError}</p>}
              <div className="flex flex-wrap gap-2.5 pt-1">
                <button
                  type="submit"
                  disabled={saving}
                  className="rounded-xl bg-accent px-3.5 py-2.5 text-[0.85rem] font-medium text-accent-ink disabled:opacity-60"
                >
                  {saving ? "Enregistrement…" : "Enregistrer"}
                </button>
                <button
                  type="button"
                  onClick={onClose}
                  className="rounded-xl border border-line bg-surface px-3.5 py-2.5 text-[0.85rem] font-medium text-ink hover:bg-surface-2"
                >
                  Annuler
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
    </>
  );
}

function toDatetimeLocal(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
