"use client";

import { useState } from "react";
import { MEAL_TYPES } from "@/lib/mealTypes";
import { deleteMealLog, updateMealLog } from "@/lib/useMealLogs";
import type { MealLog, MealType } from "@/lib/types";

/**
 * Modifier (ou supprimer) un repas déjà noté, depuis la liste du dashboard.
 * Changer la quantité en grammes recalcule proportionnellement calories et
 * macros ; chaque valeur reste modifiable à la main ensuite.
 */
export function EditMealLogDialog({ log, onClose }: { log: MealLog; onClose: () => void }) {
  const [label, setLabel] = useState(log.label);
  const [mealType, setMealType] = useState<MealType>(log.mealType);
  const [eatenAt, setEatenAt] = useState(() => toDatetimeLocal(new Date(log.eatenAt)));
  const [grams, setGrams] = useState(log.portionGrams);
  const [kcal, setKcal] = useState(log.kcal);
  const [proteinG, setProteinG] = useState(log.proteinG);
  const [carbsG, setCarbsG] = useState(log.carbsG);
  const [fatG, setFatG] = useState(log.fatG);
  const originalCount = log.count && log.count > 0 ? log.count : 1;
  const [count, setCount] = useState(originalCount);
  const [busy, setBusy] = useState<"save" | "delete" | null>(null);
  const [error, setError] = useState<string | null>(null);

  /** Passe à `n` unités (×1 à ×4), à partir de la valeur d'une unité. */
  function setUnits(n: number) {
    const f = n / originalCount;
    setCount(n);
    setGrams(Math.round(log.portionGrams * f));
    setKcal(Math.round(log.kcal * f));
    setProteinG(Math.round(log.proteinG * f));
    setCarbsG(Math.round(log.carbsG * f));
    setFatG(Math.round(log.fatG * f));
  }

  function scaleTo(nextGrams: number) {
    // Proportionnel aux valeurs d'origine du repas, pour ne pas accumuler
    // d'arrondis quand on tape plusieurs valeurs de suite.
    const ratio = log.portionGrams > 0 ? nextGrams / log.portionGrams : 1;
    setGrams(nextGrams);
    // Quantité libre en grammes : on considère que c'est 1 unité.
    setCount(1);
    setKcal(Math.round(log.kcal * ratio));
    setProteinG(Math.round(log.proteinG * ratio));
    setCarbsG(Math.round(log.carbsG * ratio));
    setFatG(Math.round(log.fatG * ratio));
  }

  async function save() {
    if (!label.trim()) {
      setError("Donne un nom à ce repas.");
      return;
    }
    setBusy("save");
    setError(null);
    try {
      const d = new Date(eatenAt);
      await updateMealLog(log.id, {
        recipeId: log.recipeId ?? null,
        label: label.trim(),
        mealType,
        eatenAt: (Number.isNaN(d.getTime()) ? new Date(log.eatenAt) : d).toISOString(),
        portionGrams: grams,
        kcal,
        proteinG,
        carbsG,
        fatG,
        count,
      });
      onClose();
    } catch {
      setError("L'enregistrement a échoué, réessaie.");
      setBusy(null);
    }
  }

  async function remove() {
    setBusy("delete");
    try {
      await deleteMealLog(log.id, log.photoUrl);
      onClose();
    } catch {
      setError("La suppression a échoué, réessaie.");
      setBusy(null);
    }
  }

  const input = "w-full rounded-xl border-2 border-line bg-surface-2 px-3 py-2 text-[0.92rem] text-ink outline-none focus:border-accent";

  return (
    <>
      <div className="fixed inset-0 z-50 bg-black/40" onClick={onClose} />
      <div className="fixed inset-x-0 bottom-0 z-51 mx-auto max-h-[92dvh] w-full max-w-[520px] overflow-y-auto rounded-t-3xl bg-surface p-5 pb-8 shadow-[0_-10px_40px_-10px_rgba(0,0,0,.4)] sm:bottom-auto sm:top-1/2 sm:-translate-y-1/2 sm:rounded-3xl">
        <div className="mb-4 flex items-center justify-between gap-3">
          <h2 className="text-[1.1rem] font-extrabold text-ink">Modifier le repas</h2>
          <button onClick={onClose} aria-label="Fermer" className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-2 text-ink">
            ✕
          </button>
        </div>

        {log.photoUrl && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={log.photoUrl} alt="" className="mb-4 h-32 w-full rounded-2xl object-cover" />
        )}

        <div className="flex flex-col gap-4">
          <label className="flex flex-col gap-1.5">
            <span className="text-[0.78rem] font-bold text-ink-soft">Nom</span>
            <input value={label} onChange={(e) => setLabel(e.target.value)} className={input} />
          </label>

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

          <label className="flex flex-col gap-1.5">
            <span className="text-[0.78rem] font-bold text-ink-soft">Quand</span>
            <input type="datetime-local" value={eatenAt} onChange={(e) => setEatenAt(e.target.value)} className={input} />
          </label>

          <div className="flex flex-col gap-1.5">
            <span className="text-[0.78rem] font-bold text-ink-soft">Quantité mangée</span>
            <div className="flex flex-wrap items-center gap-2">
              <input
                type="number"
                min={0}
                value={grams}
                onChange={(e) => scaleTo(Number(e.target.value) || 0)}
                className={`${input} w-28`}
              />
              <span className="text-[0.85rem] text-ink-soft">g</span>
              {[1, 2, 3, 4].map((n) => (
                <button
                  key={n}
                  onClick={() => setUnits(n)}
                  className={`h-9 min-w-9 rounded-full border-2 px-2 text-[0.82rem] font-bold ${
                    count === n ? "border-accent bg-accent text-accent-ink" : "border-line text-ink-soft hover:border-accent hover:text-accent"
                  }`}
                >
                  ×{n}
                </button>
              ))}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
            {(
              [
                ["Kcal", kcal, setKcal],
                ["Protéines g", proteinG, setProteinG],
                ["Glucides g", carbsG, setCarbsG],
                ["Lipides g", fatG, setFatG],
              ] as [string, number, (v: number) => void][]
            ).map(([l, v, set]) => (
              <label key={l} className="flex flex-col gap-1">
                <span className="text-[0.72rem] font-bold text-ink-soft">{l}</span>
                <input type="number" min={0} value={v} onChange={(e) => set(Number(e.target.value) || 0)} className={input} />
              </label>
            ))}
          </div>

          {error && <p className="text-[0.85rem] font-medium text-accent">{error}</p>}

          <button
            onClick={save}
            disabled={busy !== null}
            className="rounded-2xl bg-accent px-4 py-3.5 text-[0.95rem] font-bold text-accent-ink disabled:opacity-60"
          >
            {busy === "save" ? "Enregistrement…" : "Enregistrer"}
          </button>
          <button
            onClick={remove}
            disabled={busy !== null}
            className="py-1 text-[0.85rem] font-semibold text-accent underline decoration-dotted underline-offset-4 disabled:opacity-60"
          >
            {busy === "delete" ? "Suppression…" : "Supprimer ce repas"}
          </button>
        </div>
      </div>
    </>
  );
}

function toDatetimeLocal(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
