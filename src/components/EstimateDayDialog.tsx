"use client";

import { useState } from "react";
import { dayLabel, eatenAtFor } from "@/lib/mealTypes";
import { addMealLog } from "@/lib/useMealLogs";

/**
 * "Je ne sais plus ce que j'ai mangé" : compléter une journée avec une
 * estimation. Proposition par défaut = ta moyenne des jours notés (ou ton
 * objectif s'il n'y a pas encore d'historique) ; on n'ajoute que ce qui
 * manque par rapport à ce qui est déjà noté ce jour-là. Les macros suivent
 * ta répartition moyenne (25/45/30 % par défaut).
 */
export function EstimateDayDialog({
  day,
  alreadyKcal,
  suggestedKcal,
  suggestionSource,
  split,
  owner,
  onClose,
}: {
  day: Date;
  alreadyKcal: number;
  suggestedKcal: number;
  suggestionSource: "average" | "goal";
  split: { protein: number; carbs: number; fat: number };
  owner: { uid: string; name: string; householdId: string };
  onClose: () => void;
}) {
  const [total, setTotal] = useState(Math.max(Math.round(suggestedKcal / 50) * 50, Math.round(alreadyKcal)));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const missing = Math.max(0, Math.round(total - alreadyKcal));

  async function save() {
    if (missing <= 0) {
      onClose();
      return;
    }
    setBusy(true);
    try {
      await addMealLog(
        {
          recipeId: null,
          label: alreadyKcal > 0 ? "Estimation (reste de la journée)" : "Journée estimée",
          mealType: "diner",
          eatenAt: eatenAtFor(day, "diner").toISOString(),
          portionGrams: 0,
          kcal: missing,
          proteinG: Math.round((missing * split.protein) / 4),
          carbsG: Math.round((missing * split.carbs) / 4),
          fatG: Math.round((missing * split.fat) / 9),
        },
        null,
        "estimate",
        owner,
      );
      onClose();
    } catch {
      setError("L'enregistrement a échoué, réessaie.");
      setBusy(false);
    }
  }

  return (
    <>
      <div className="fixed inset-0 z-50 bg-black/40" onClick={onClose} />
      <div className="fixed inset-x-0 bottom-0 z-51 mx-auto w-full max-w-[480px] rounded-t-3xl bg-surface p-5 pb-8 shadow-[0_-10px_40px_-10px_rgba(0,0,0,.4)] sm:bottom-auto sm:top-1/2 sm:-translate-y-1/2 sm:rounded-3xl">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-[1.1rem] font-extrabold text-ink">Estimer {dayLabel(day).toLowerCase()}</h2>
          <button onClick={onClose} aria-label="Fermer" className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-2 text-ink">
            ✕
          </button>
        </div>
        <p className="mb-4 text-[0.85rem] text-ink-soft">
          Tu ne sais plus exactement ? Indique à peu près combien tu as mangé en tout ce jour-là. Je propose{" "}
          {suggestionSource === "average" ? "ta moyenne des jours notés" : "ton objectif (pas encore assez d'historique)"}.
        </p>

        <label className="flex flex-col gap-1.5">
          <span className="text-[0.78rem] font-bold text-ink-soft">Total de la journée (kcal)</span>
          <input
            type="number"
            min={0}
            step={50}
            value={total}
            onChange={(e) => setTotal(Number(e.target.value) || 0)}
            className="w-full rounded-xl border-2 border-line bg-surface-2 px-3 py-2.5 font-mono text-[1.2rem] font-bold text-ink outline-none focus:border-accent"
          />
        </label>
        <div className="mt-2 flex flex-wrap gap-1.5">
          {[1500, 1800, 2000, 2200, 2500, 2800].map((v) => (
            <button
              key={v}
              onClick={() => setTotal(v)}
              className={`rounded-full border-2 px-3 py-1 text-[0.78rem] font-semibold ${total === v ? "border-accent text-accent" : "border-line text-ink-soft"}`}
            >
              {v}
            </button>
          ))}
        </div>

        <p className="mt-4 rounded-xl bg-surface-2 px-3.5 py-2.5 text-[0.85rem] text-ink">
          {alreadyKcal > 0 ? (
            <>
              Déjà noté : <strong>{Math.round(alreadyKcal)} kcal</strong> → j&apos;ajoute <strong>{missing} kcal</strong> estimées.
            </>
          ) : (
            <>
              J&apos;ajoute <strong>{missing} kcal</strong> estimées pour cette journée.
            </>
          )}
        </p>

        {error && <p className="mt-2 text-[0.85rem] text-accent">{error}</p>}
        <button
          onClick={save}
          disabled={busy}
          className="mt-4 w-full rounded-2xl bg-accent px-4 py-3.5 text-[0.95rem] font-bold text-accent-ink disabled:opacity-60"
        >
          {busy ? "Enregistrement…" : missing > 0 ? `Ajouter ${missing} kcal` : "Rien à ajouter"}
        </button>
      </div>
    </>
  );
}
