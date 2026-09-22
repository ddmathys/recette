"use client";

import type { RecipeDraft } from "@/lib/types";
import { Field } from "./RecipeFormFields";

/** Kcal/macros/poids par portion — extrait de RecipeCoreFields pour être
 * réutilisable seul dans CaptureDialog.tsx quand on ne veut pas afficher
 * tout le formulaire recette (ex : juste logguer un repas sans l'ajouter
 * à la bibliothèque). */
export function NutritionFields({
  draft,
  setDraft,
}: {
  draft: Pick<RecipeDraft, "nutrition">;
  setDraft: (updater: (d: RecipeDraft) => RecipeDraft) => void;
}) {
  function updateNutrition(field: "kcal" | "proteinG" | "carbsG" | "fatG" | "gramsPerServing", value: number) {
    setDraft((d) => ({
      ...d,
      nutrition: {
        kcal: d.nutrition?.kcal ?? 0,
        proteinG: d.nutrition?.proteinG ?? 0,
        carbsG: d.nutrition?.carbsG ?? 0,
        fatG: d.nutrition?.fatG ?? 0,
        gramsPerServing: d.nutrition?.gramsPerServing ?? 0,
        [field]: value,
        estimatedBy: "manual",
      },
    }));
  }

  return (
    <div>
      <p className="mb-2.5 text-[0.72rem] font-semibold uppercase tracking-wider text-ink-soft">
        Nutrition (par portion)
        {draft.nutrition?.estimatedBy === "ai" && (
          <span className="ml-1.5 normal-case tracking-normal text-ink-soft/80">— estimation IA, modifiable</span>
        )}
      </p>
      <div className="flex flex-wrap gap-3">
        <Field label="Poids (g)" className="flex-1 basis-24">
          <input
            type="number"
            min={0}
            value={draft.nutrition?.gramsPerServing ?? ""}
            onChange={(e) => updateNutrition("gramsPerServing", Number(e.target.value) || 0)}
            className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
          />
        </Field>
        <Field label="Kcal" className="flex-1 basis-24">
          <input
            type="number"
            min={0}
            value={draft.nutrition?.kcal ?? ""}
            onChange={(e) => updateNutrition("kcal", Number(e.target.value) || 0)}
            className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
          />
        </Field>
        <Field label="Protéines (g)" className="flex-1 basis-24">
          <input
            type="number"
            min={0}
            value={draft.nutrition?.proteinG ?? ""}
            onChange={(e) => updateNutrition("proteinG", Number(e.target.value) || 0)}
            className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
          />
        </Field>
        <Field label="Glucides (g)" className="flex-1 basis-24">
          <input
            type="number"
            min={0}
            value={draft.nutrition?.carbsG ?? ""}
            onChange={(e) => updateNutrition("carbsG", Number(e.target.value) || 0)}
            className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
          />
        </Field>
        <Field label="Lipides (g)" className="flex-1 basis-24">
          <input
            type="number"
            min={0}
            value={draft.nutrition?.fatG ?? ""}
            onChange={(e) => updateNutrition("fatG", Number(e.target.value) || 0)}
            className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
          />
        </Field>
      </div>
    </div>
  );
}
