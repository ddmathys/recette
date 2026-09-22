"use client";

import { useState } from "react";
import { compressImageIfNeeded } from "@/lib/compressImage";
import { auth } from "@/lib/firebase";
import { MEAL_TYPES, guessMealType } from "@/lib/mealTypes";
import { scaleNutritionToGrams } from "@/lib/nutrition";
import { addMealLog, uploadMealPhoto } from "@/lib/useMealLogs";
import type { MealType, Recipe } from "@/lib/types";
import { Field } from "./RecipeFormFields";

const MAX_PHOTO_BYTES = 10 * 1024 * 1024;

type Mode = "recipe" | "manual";

/** ISO datetime (local, no timezone) truncated to the minute, as required by
 * <input type="datetime-local">. */
function toDatetimeLocal(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function LogMealDialog({
  recipes,
  initialRecipe,
  owner,
  onClose,
}: {
  recipes: Recipe[];
  initialRecipe: Recipe | null;
  owner: { uid: string; name: string; householdId: string };
  onClose: () => void;
}) {
  const [mode, setMode] = useState<Mode>(initialRecipe ? "recipe" : "manual");
  const [recipeId, setRecipeId] = useState<string | null>(initialRecipe?.id ?? null);
  const [label, setLabel] = useState(initialRecipe?.name ?? "");
  const [mealType, setMealType] = useState<MealType>(guessMealType());
  const [eatenAt, setEatenAt] = useState(() => toDatetimeLocal(new Date()));
  const [portionGrams, setPortionGrams] = useState(initialRecipe?.nutrition?.gramsPerServing ?? 250);
  const [kcal, setKcal] = useState(initialRecipe?.nutrition?.kcal ?? 0);
  const [proteinG, setProteinG] = useState(initialRecipe?.nutrition?.proteinG ?? 0);
  const [carbsG, setCarbsG] = useState(initialRecipe?.nutrition?.carbsG ?? 0);
  const [fatG, setFatG] = useState(initialRecipe?.nutrition?.fatG ?? 0);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
  const [uploadedPhotoUrl, setUploadedPhotoUrl] = useState<string | null>(null);
  const [photoBusy, setPhotoBusy] = useState(false);
  const [analyzing, setAnalyzing] = useState(false);
  const [photoError, setPhotoError] = useState<string | null>(null);

  const selectedRecipe = recipeId ? recipes.find((r) => r.id === recipeId) ?? null : null;

  function applyRecipe(r: Recipe | null) {
    setRecipeId(r?.id ?? null);
    if (!r) return;
    setLabel(r.name);
    if (r.nutrition) {
      setPortionGrams(r.nutrition.gramsPerServing);
      const scaled = scaleNutritionToGrams(r.nutrition, r.nutrition.gramsPerServing);
      setKcal(scaled.kcal);
      setProteinG(scaled.proteinG);
      setCarbsG(scaled.carbsG);
      setFatG(scaled.fatG);
    }
  }

  function applyPortion(grams: number) {
    setPortionGrams(grams);
    if (selectedRecipe?.nutrition) {
      const scaled = scaleNutritionToGrams(selectedRecipe.nutrition, grams);
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
      const compressed = await compressImageIfNeeded(f, MAX_PHOTO_BYTES);
      if (compressed.size > MAX_PHOTO_BYTES) {
        setPhotoError("Photo trop lourde (max 10 Mo), même après compression.");
        return;
      }
      setPhotoFile(compressed);
      setPhotoPreview(URL.createObjectURL(compressed));
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
      if (matched) {
        applyRecipe(matched);
      } else {
        setMode("manual");
        setRecipeId(null);
      }
      if (typeof d.label === "string" && d.label.trim()) setLabel(d.label.trim());
      if (Number(d.portionGrams) > 0) setPortionGrams(Number(d.portionGrams));
      if (Number.isFinite(Number(d.kcal))) setKcal(Number(d.kcal));
      if (Number.isFinite(Number(d.proteinG))) setProteinG(Number(d.proteinG));
      if (Number.isFinite(Number(d.carbsG))) setCarbsG(Number(d.carbsG));
      if (Number.isFinite(Number(d.fatG))) setFatG(Number(d.fatG));
      if (MEAL_TYPES.some((m) => m.key === d.mealType)) setMealType(d.mealType as MealType);
    } catch (e) {
      setPhotoError(e instanceof Error ? e.message : "La reconnaissance photo a échoué. Tu peux remplir manuellement.");
    } finally {
      setAnalyzing(false);
    }
  }

  async function handleSave() {
    const trimmed = label.trim();
    if (!trimmed) {
      setError("Donne un nom à ce repas.");
      return;
    }
    if (!portionGrams || portionGrams <= 0) {
      setError("Indique une quantité en grammes.");
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const eatenAtDate = new Date(eatenAt);
      const source: "photo" | "recipe" | "manual" = uploadedPhotoUrl ? "photo" : mode === "recipe" && recipeId ? "recipe" : "manual";
      await addMealLog(
        {
          recipeId: mode === "recipe" ? recipeId : null,
          label: trimmed,
          mealType,
          eatenAt: (Number.isNaN(eatenAtDate.getTime()) ? new Date() : eatenAtDate).toISOString(),
          portionGrams,
          kcal,
          proteinG,
          carbsG,
          fatG,
        },
        uploadedPhotoUrl,
        source,
        owner,
      );
      onClose();
    } catch {
      setError("L'enregistrement a échoué, réessaie.");
      setSaving(false);
    }
  }

  return (
    <>
      <div className="fixed inset-0 z-42 bg-black/40" onClick={onClose} />
      <div className="fixed left-1/2 top-1/2 z-43 max-h-[90dvh] w-[min(520px,calc(100vw-32px))] -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-[20px] bg-surface shadow-[-4px_12px_40px_-10px_rgba(0,0,0,.4)]">
        <div className="sticky top-0 z-10 flex items-center justify-between gap-2.5 rounded-t-[20px] border-b border-line bg-surface px-5 py-4.5">
          <h2 className="text-[1.15rem] font-semibold">Repas mangé</h2>
          <button onClick={onClose} aria-label="Fermer" className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-2 text-ink">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-4 w-4">
              <path d="M6 6l12 12M18 6 6 18" />
            </svg>
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault();
            handleSave();
          }}
          className="flex flex-col gap-3.5 px-5 pb-6.5 pt-4.5"
        >
          <Field label="Photo (optionnel)">
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
                  type="button"
                  onClick={analyzePhoto}
                  disabled={analyzing}
                  className="inline-flex items-center gap-1.5 rounded-xl bg-accent px-3.5 py-2 text-[0.83rem] font-medium text-accent-ink disabled:opacity-60"
                >
                  {analyzing && <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-line border-t-accent-ink" />}
                  {analyzing ? "Analyse…" : "Analyser (Gemini)"}
                </button>
              )}
            </div>
            {photoError && <p className="mt-1.5 text-[0.76rem] text-accent">{photoError}</p>}
            <p className="mt-1.5 text-[0.76rem] text-ink-soft">
              La photo permet de pré-remplir le repas automatiquement — vérifie et corrige les valeurs avant d&apos;enregistrer.
            </p>
          </Field>

          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setMode("recipe")}
              className={`flex-1 rounded-lg border-2 px-3 py-2 text-[0.85rem] font-semibold ${mode === "recipe" ? "border-accent bg-accent/10 text-accent" : "border-line text-ink-soft"}`}
            >
              Depuis une recette
            </button>
            <button
              type="button"
              onClick={() => {
                setMode("manual");
                setRecipeId(null);
              }}
              className={`flex-1 rounded-lg border-2 px-3 py-2 text-[0.85rem] font-semibold ${mode === "manual" ? "border-accent bg-accent/10 text-accent" : "border-line text-ink-soft"}`}
            >
              Libre
            </button>
          </div>

          {mode === "recipe" && (
            <Field label="Recette">
              <select
                value={recipeId ?? ""}
                onChange={(e) => applyRecipe(recipes.find((r) => r.id === e.target.value) ?? null)}
                className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none"
              >
                <option value="">— choisir —</option>
                {recipes.map((r) => (
                  <option key={r.id} value={r.id}>
                    {r.name}
                  </option>
                ))}
              </select>
              {recipeId && !selectedRecipe?.nutrition && (
                <p className="mt-1.5 text-[0.76rem] text-ink-soft">
                  Cette recette n&apos;a pas d&apos;estimation nutritionnelle — renseigne les valeurs à la main ci-dessous.
                </p>
              )}
            </Field>
          )}

          <Field label="Nom du repas">
            <input
              value={label}
              onChange={(e) => setLabel(e.target.value)}
              className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none"
            />
          </Field>

          <div className="flex flex-wrap gap-3">
            <Field label="Type de repas" className="flex-1 basis-35">
              <select
                value={mealType}
                onChange={(e) => setMealType(e.target.value as MealType)}
                className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none"
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
                className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none"
              />
            </Field>
          </div>

          <div className="flex flex-wrap gap-3">
            <Field label="Portion (g)" className="flex-1 basis-24">
              <input
                type="number"
                min={0}
                value={portionGrams}
                onChange={(e) => applyPortion(Number(e.target.value) || 0)}
                className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
              />
            </Field>
            <Field label="Kcal" className="flex-1 basis-24">
              <input
                type="number"
                min={0}
                value={kcal}
                onChange={(e) => setKcal(Number(e.target.value) || 0)}
                className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
              />
            </Field>
            <Field label="Protéines (g)" className="flex-1 basis-24">
              <input
                type="number"
                min={0}
                value={proteinG}
                onChange={(e) => setProteinG(Number(e.target.value) || 0)}
                className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
              />
            </Field>
            <Field label="Glucides (g)" className="flex-1 basis-24">
              <input
                type="number"
                min={0}
                value={carbsG}
                onChange={(e) => setCarbsG(Number(e.target.value) || 0)}
                className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
              />
            </Field>
            <Field label="Lipides (g)" className="flex-1 basis-24">
              <input
                type="number"
                min={0}
                value={fatG}
                onChange={(e) => setFatG(Number(e.target.value) || 0)}
                className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
              />
            </Field>
          </div>

          {error && <p className="text-[0.83rem] text-accent">{error}</p>}
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
      </div>
    </>
  );
}
