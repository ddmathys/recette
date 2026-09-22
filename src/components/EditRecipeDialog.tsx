"use client";

import { useState } from "react";
import { CATEGORIES } from "@/lib/categories";
import { auth } from "@/lib/firebase";
import { sanitizeNutrition } from "@/lib/nutrition";
import type { Difficulty, CategoryKey, Recipe, RecipeDraft } from "@/lib/types";
import { updateRecipeContent } from "@/lib/useRecipes";
import { Field } from "./RecipeFormFields";
import { RecipeCoreFields } from "./RecipeCoreFields";

const DIFFICULTIES: Difficulty[] = ["Facile", "Moyen", "Avancé"];

function draftFromRecipe(r: Recipe): RecipeDraft {
  return {
    name: r.name,
    cat: r.cat,
    time: r.time,
    diff: r.diff,
    servings: r.servings,
    veg: r.veg,
    ingr: r.ingr.length ? r.ingr : [{ name: "", qty: "" }],
    steps: r.steps.length ? r.steps : [""],
    nutrition: r.nutrition ?? null,
  };
}

export function EditRecipeDialog({ recipe, onClose }: { recipe: Recipe; onClose: () => void }) {
  const [draft, setDraft] = useState<RecipeDraft>(() => draftFromRecipe(recipe));
  const [instruction, setInstruction] = useState("");
  const [aiBusy, setAiBusy] = useState(false);
  const [aiError, setAiError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  async function askAi() {
    if (!instruction.trim()) {
      setAiError("Décris la modification à apporter (ex : « remplace le poulet par du tofu »).");
      return;
    }
    setAiBusy(true);
    setAiError(null);
    try {
      const idToken = await auth?.currentUser?.getIdToken();
      const res = await fetch("/api/edit-recipe", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
        },
        body: JSON.stringify({ recipe: draft, instruction: instruction.trim() }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "La modification IA a échoué.");
      const d = data.draft as Partial<RecipeDraft>;
      const validCat = CATEGORIES.some((c) => c.key === d.cat) ? (d.cat as CategoryKey) : draft.cat;
      const validDiff = DIFFICULTIES.includes(d.diff as Difficulty) ? (d.diff as Difficulty) : draft.diff;
      setDraft({
        name: d.name || draft.name,
        cat: validCat,
        time: Number(d.time) > 0 ? Number(d.time) : draft.time,
        diff: validDiff,
        servings: Number(d.servings) > 0 ? Number(d.servings) : draft.servings,
        veg: typeof d.veg === "boolean" ? d.veg : draft.veg,
        ingr: Array.isArray(d.ingr) && d.ingr.length ? d.ingr : draft.ingr,
        steps: Array.isArray(d.steps) && d.steps.length ? d.steps : draft.steps,
        nutrition: sanitizeNutrition(d.nutrition, "ai") ?? draft.nutrition,
      });
      setInstruction("");
    } catch (e) {
      setAiError(e instanceof Error ? e.message : "La modification IA a échoué.");
    } finally {
      setAiBusy(false);
    }
  }

  async function handleSave() {
    const name = draft.name.trim();
    const ingr = draft.ingr.map((i) => ({ name: i.name.trim(), qty: i.qty.trim() })).filter((i) => i.name);
    const steps = draft.steps.map((s) => s.trim()).filter(Boolean);
    if (!name || !ingr.length || !steps.length) {
      setSaveError("Nom, au moins un ingrédient et une étape sont nécessaires.");
      return;
    }
    setSaving(true);
    setSaveError(null);
    try {
      await updateRecipeContent(recipe.id, { ...draft, name, ingr, steps });
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
          <h2 className="text-[1.15rem] font-semibold">Modifier « {recipe.name} »</h2>
          <button onClick={onClose} aria-label="Fermer" className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-2 text-ink">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-4 w-4">
              <path d="M6 6l12 12M18 6 6 18" />
            </svg>
          </button>
        </div>

        <div className="flex flex-col gap-3.5 px-5 pb-6.5 pt-4.5">
          <div className="rounded-xl border border-line bg-surface-2 p-3.5">
            <Field label="Modifier avec l'IA (optionnel)">
              <textarea
                rows={2}
                value={instruction}
                onChange={(e) => setInstruction(e.target.value)}
                placeholder="ex : remplace le poulet par du tofu, double les proportions, rends-la plus épicée…"
                className="w-full resize-y rounded-lg border border-line bg-surface px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
              />
            </Field>
            <button
              type="button"
              onClick={askAi}
              disabled={aiBusy}
              className="mt-2.5 inline-flex items-center gap-1.5 rounded-xl bg-accent px-3.5 py-2 text-[0.83rem] font-medium text-accent-ink disabled:opacity-60"
            >
              {aiBusy && <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-line border-t-accent-ink" />}
              {aiBusy ? "DeepSeek réfléchit…" : "Demander à l'IA"}
            </button>
            <p className="mt-1.5 text-[0.76rem] text-ink-soft">
              L&apos;IA propose une nouvelle version ci-dessous — rien n&apos;est enregistré tant que tu n&apos;as pas cliqué sur « Enregistrer ».
            </p>
            {aiError && <p className="mt-1.5 text-[0.83rem] text-accent">{aiError}</p>}
          </div>

          <form
            onSubmit={(e) => {
              e.preventDefault();
              handleSave();
            }}
            className="flex flex-col gap-3.5"
          >
            <RecipeCoreFields draft={draft} setDraft={setDraft} />

            {saveError && <p className="text-[0.83rem] text-accent">{saveError}</p>}
            <div className="flex flex-wrap gap-2.5 pt-1">
              <button
                type="submit"
                disabled={saving}
                className="rounded-xl bg-accent px-3.5 py-2.5 text-[0.85rem] font-medium text-accent-ink disabled:opacity-60"
              >
                {saving ? "Enregistrement…" : "Enregistrer les modifications"}
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
      </div>
    </>
  );
}
