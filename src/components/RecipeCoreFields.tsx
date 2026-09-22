"use client";

import { CATEGORIES } from "@/lib/categories";
import type { CategoryKey, Difficulty, RecipeDraft } from "@/lib/types";
import { AddRowButton, Field, RemoveButton } from "./RecipeFormFields";

const DIFFICULTIES: Difficulty[] = ["Facile", "Moyen", "Avancé"];

/** Name/category/time/difficulty/servings/veg/ingredients/steps — the part
 * of the recipe form shared between AddRecipeDialog and EditRecipeDialog.
 * Photo handling stays in each caller since the two flows attach it
 * differently (new doc vs. existing one). */
export function RecipeCoreFields({
  draft,
  setDraft,
}: {
  draft: RecipeDraft;
  setDraft: (updater: (d: RecipeDraft) => RecipeDraft) => void;
}) {
  function updateIngr(idx: number, field: "name" | "qty", value: string) {
    setDraft((d) => ({
      ...d,
      ingr: d.ingr.map((row, i) => (i === idx ? { ...row, [field]: value } : row)),
    }));
  }
  function updateStep(idx: number, value: string) {
    setDraft((d) => ({ ...d, steps: d.steps.map((s, i) => (i === idx ? value : s)) }));
  }
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
    <>
      <Field label="Nom du plat">
        <input
          required
          value={draft.name}
          onChange={(e) => setDraft((d) => ({ ...d, name: e.target.value }))}
          className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
        />
      </Field>

      <div className="flex flex-wrap gap-3">
        <Field label="Catégorie" className="flex-1 basis-35">
          <select
            value={draft.cat}
            onChange={(e) => setDraft((d) => ({ ...d, cat: e.target.value as CategoryKey }))}
            className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
          >
            {CATEGORIES.map((c) => (
              <option key={c.key} value={c.key}>
                {c.label}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Temps (min)" className="flex-1 basis-35">
          <input
            type="number"
            min={1}
            max={600}
            value={draft.time}
            onChange={(e) => setDraft((d) => ({ ...d, time: Number(e.target.value) || 1 }))}
            className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
          />
        </Field>
      </div>

      <div className="flex flex-wrap gap-3">
        <Field label="Difficulté" className="flex-1 basis-35">
          <select
            value={draft.diff}
            onChange={(e) => setDraft((d) => ({ ...d, diff: e.target.value as Difficulty }))}
            className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
          >
            {DIFFICULTIES.map((d) => (
              <option key={d} value={d}>
                {d}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Personnes" className="flex-1 basis-35">
          <input
            type="number"
            min={1}
            max={20}
            value={draft.servings}
            onChange={(e) => setDraft((d) => ({ ...d, servings: Number(e.target.value) || 1 }))}
            className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
          />
        </Field>
      </div>

      <label className="flex items-center gap-2 text-[0.88rem]">
        <input
          type="checkbox"
          checked={draft.veg}
          onChange={(e) => setDraft((d) => ({ ...d, veg: e.target.checked }))}
        />
        Recette végétarienne
      </label>

      <div>
        <p className="mb-2.5 text-[0.72rem] font-semibold uppercase tracking-wider text-ink-soft">Ingrédients</p>
        <div className="flex flex-col gap-2">
          {draft.ingr.map((row, idx) => (
            <div key={idx} className="flex items-center gap-2">
              <input
                placeholder="ingrédient"
                value={row.name}
                onChange={(e) => updateIngr(idx, "name", e.target.value)}
                className="flex-2 rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
              />
              <input
                placeholder="quantité"
                value={row.qty}
                onChange={(e) => updateIngr(idx, "qty", e.target.value)}
                className="flex-1 rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
              />
              <RemoveButton onClick={() => setDraft((d) => ({ ...d, ingr: d.ingr.filter((_, i) => i !== idx) }))} />
            </div>
          ))}
        </div>
        <AddRowButton onClick={() => setDraft((d) => ({ ...d, ingr: [...d.ingr, { name: "", qty: "" }] }))}>
          + ajouter un ingrédient
        </AddRowButton>
      </div>

      <div>
        <p className="mb-2.5 text-[0.72rem] font-semibold uppercase tracking-wider text-ink-soft">Étapes</p>
        <div className="flex flex-col gap-2">
          {draft.steps.map((s, idx) => (
            <div key={idx} className="flex items-start gap-2">
              <span className="flex h-8.5 w-5.5 shrink-0 items-center justify-center font-mono text-[0.75rem] text-ink-soft">
                {idx + 1}
              </span>
              <textarea
                rows={1}
                value={s}
                onChange={(e) => updateStep(idx, e.target.value)}
                placeholder="étape de préparation"
                className="min-h-9.5 flex-1 rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
              />
              <RemoveButton onClick={() => setDraft((d) => ({ ...d, steps: d.steps.filter((_, i) => i !== idx) }))} />
            </div>
          ))}
        </div>
        <AddRowButton onClick={() => setDraft((d) => ({ ...d, steps: [...d.steps, ""] }))}>
          + ajouter une étape
        </AddRowButton>
      </div>

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
    </>
  );
}
