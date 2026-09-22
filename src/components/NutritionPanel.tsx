"use client";

import { useMemo, useState } from "react";
import { mealTypeLabel } from "@/lib/mealTypes";
import { deleteMealLog } from "@/lib/useMealLogs";
import type { MealLog } from "@/lib/types";

function localDayKey(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString("fr-CH", { hour: "2-digit", minute: "2-digit" });
}

/** "Aujourd'hui" — journal des repas mangés, scopé par jour (navigation
 * jour précédent/suivant), avec le total kcal/macros du jour. Repas d'une
 * collection Firestore indépendante (mealLogs) — voir src/lib/useMealLogs.ts. */
export function NutritionPanel({
  logs,
  onClose,
  onAddMeal,
  readOnly,
}: {
  logs: MealLog[];
  onClose: () => void;
  onAddMeal: () => void;
  readOnly: boolean;
}) {
  const [dayOffset, setDayOffset] = useState(0); // 0 = aujourd'hui, négatif = passé
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const day = useMemo(() => {
    const d = new Date();
    d.setDate(d.getDate() + dayOffset);
    return d;
  }, [dayOffset]);
  const dayKey = localDayKey(day);

  const dayLogs = useMemo(
    () =>
      logs
        .filter((l) => localDayKey(new Date(l.eatenAt)) === dayKey)
        .sort((a, b) => a.eatenAt.localeCompare(b.eatenAt)),
    [logs, dayKey],
  );

  const totals = dayLogs.reduce(
    (acc, l) => ({
      kcal: acc.kcal + l.kcal,
      proteinG: acc.proteinG + l.proteinG,
      carbsG: acc.carbsG + l.carbsG,
      fatG: acc.fatG + l.fatG,
    }),
    { kcal: 0, proteinG: 0, carbsG: 0, fatG: 0 },
  );

  async function handleDelete(l: MealLog) {
    setDeletingId(l.id);
    try {
      await deleteMealLog(l.id, l.photoUrl);
    } finally {
      setDeletingId(null);
    }
  }

  const dayLabel =
    dayOffset === 0
      ? "Aujourd'hui"
      : dayOffset === -1
        ? "Hier"
        : day.toLocaleDateString("fr-CH", { weekday: "short", day: "numeric", month: "short" });

  return (
    <>
      <div className="fixed inset-0 z-40 bg-black/40" onClick={onClose} />
      <aside className="fixed right-0 top-0 z-41 flex h-full w-full max-w-[440px] flex-col overflow-y-auto bg-surface shadow-[-12px_0_30px_-10px_rgba(0,0,0,.35)]">
        <div className="sticky top-0 z-10 flex items-center justify-between gap-2.5 border-b border-line bg-surface px-5 py-4.5">
          <h2 className="text-[1.1rem] font-semibold">Journal alimentaire</h2>
          <button onClick={onClose} aria-label="Fermer" className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-2 text-ink">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-4 w-4">
              <path d="M6 6l12 12M18 6 6 18" />
            </svg>
          </button>
        </div>

        <div className="flex flex-col gap-4 px-5 py-5">
          <div className="flex items-center justify-between gap-2">
            <button
              onClick={() => setDayOffset((o) => o - 1)}
              aria-label="Jour précédent"
              className="flex h-8 w-8 items-center justify-center rounded-full border border-line text-ink-soft hover:border-accent hover:text-accent"
            >
              ‹
            </button>
            <span className="text-[0.95rem] font-semibold text-ink">{dayLabel}</span>
            <button
              onClick={() => setDayOffset((o) => Math.min(0, o + 1))}
              disabled={dayOffset === 0}
              aria-label="Jour suivant"
              className="flex h-8 w-8 items-center justify-center rounded-full border border-line text-ink-soft hover:border-accent hover:text-accent disabled:opacity-40"
            >
              ›
            </button>
          </div>

          <div className="grid grid-cols-4 gap-2 rounded-xl border border-line bg-surface-2 p-3 text-center">
            <Total value={totals.kcal} label="Kcal" />
            <Total value={totals.proteinG} label="Protéines (g)" />
            <Total value={totals.carbsG} label="Glucides (g)" />
            <Total value={totals.fatG} label="Lipides (g)" />
          </div>

          {!readOnly && (
            <button
              onClick={onAddMeal}
              className="inline-flex items-center justify-center gap-1.5 self-start rounded-full bg-accent px-3.5 py-2 text-[0.82rem] font-bold text-accent-ink"
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round" className="h-3.5 w-3.5">
                <path d="M12 5v14M5 12h14" />
              </svg>
              Repas mangé
            </button>
          )}

          {dayLogs.length === 0 ? (
            <p className="text-[0.82rem] text-ink-soft">Aucun repas enregistré ce jour-là.</p>
          ) : (
            <ul className="flex flex-col gap-2">
              {dayLogs.map((l) => (
                <li key={l.id} className="flex items-center justify-between gap-2.5 rounded-xl border border-line bg-surface-2 px-3.5 py-2.5">
                  <div className="min-w-0">
                    <p className="truncate text-[0.86rem] font-semibold text-ink">{l.label}</p>
                    <p className="text-[0.74rem] text-ink-soft">
                      {mealTypeLabel(l.mealType)} · {formatTime(l.eatenAt)} · {l.portionGrams} g
                    </p>
                  </div>
                  <div className="flex shrink-0 items-center gap-2">
                    <span className="whitespace-nowrap font-mono text-[0.82rem] text-ink">{l.kcal} kcal</span>
                    {!readOnly && (
                      <button
                        onClick={() => handleDelete(l)}
                        disabled={deletingId === l.id}
                        aria-label={`Supprimer ${l.label}`}
                        className="text-ink-soft hover:text-accent disabled:opacity-50"
                      >
                        &times;
                      </button>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </aside>
    </>
  );
}

function Total({ value, label }: { value: number; label: string }) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="font-mono text-[1rem] font-bold text-ink">{Math.round(value)}</span>
      <span className="text-[0.62rem] uppercase tracking-wide text-ink-soft">{label}</span>
    </div>
  );
}
