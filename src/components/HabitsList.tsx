"use client";

import { useState } from "react";
import { mealTypeLabel } from "@/lib/mealTypes";
import type { Habit } from "@/lib/habits";

/** "Tes habituels" : ce que tu as déjà noté, à renoter en un tap avec la
 * quantité (×1 à ×4) — mêmes calories que la première fois. */
export function HabitsList({
  habits,
  onLog,
  showType = false,
}: {
  habits: Habit[];
  onLog: (h: Habit, count: number) => Promise<void>;
  showType?: boolean;
}) {
  const [done, setDone] = useState<Record<string, number>>({});
  const [busy, setBusy] = useState<string | null>(null);

  if (!habits.length) return null;

  async function log(h: Habit, count: number) {
    const key = h.label.toLowerCase();
    setBusy(key);
    try {
      await onLog(h, count);
      setDone((d) => ({ ...d, [key]: count }));
    } finally {
      setBusy(null);
    }
  }

  return (
    <section className="rounded-3xl bg-surface p-4.5 shadow-[0_1px_3px_rgba(43,42,38,.08)]">
      <h3 className="mb-1 text-[0.78rem] font-bold uppercase tracking-wider text-ink-soft">Tes habituels</h3>
      <p className="mb-3 text-[0.78rem] text-ink-soft">Touche la quantité pour le noter tout de suite, avec les mêmes calories.</p>
      <ul className="flex flex-col divide-y divide-line">
        {habits.map((h) => {
          const key = h.label.toLowerCase();
          return (
            <li key={key} className="flex flex-wrap items-center justify-between gap-2 py-2.5">
              <div className="min-w-0">
                <p className="truncate text-[0.9rem] font-semibold text-ink">{h.label}</p>
                <p className="text-[0.72rem] text-ink-soft">
                  {h.kcal} kcal l&apos;unité{showType ? ` · ${mealTypeLabel(h.mealType)}` : ""} · noté {h.times}×
                </p>
              </div>
              {done[key] ? (
                <span className="rounded-full bg-herb/12 px-3 py-1.5 text-[0.8rem] font-bold text-herb">
                  ✓ Ajouté{done[key] > 1 ? ` ×${done[key]}` : ""}
                </span>
              ) : (
                <div className="flex gap-1">
                  {[1, 2, 3, 4].map((n) => (
                    <button
                      key={n}
                      disabled={busy !== null}
                      onClick={() => log(h, n)}
                      className="h-9 min-w-9 rounded-full border-2 border-line bg-surface px-2 text-[0.82rem] font-bold text-ink hover:border-accent hover:text-accent disabled:opacity-50"
                    >
                      ×{n}
                    </button>
                  ))}
                </div>
              )}
            </li>
          );
        })}
      </ul>
    </section>
  );
}
