"use client";

import { useMemo, useState } from "react";
import { mealTypeLabel } from "@/lib/mealTypes";
import { deleteMealLog } from "@/lib/useMealLogs";
import type { MealLog } from "@/lib/types";

const DEFAULT_GOAL = 2000;

function localDayKey(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString("fr-CH", { hour: "2-digit", minute: "2-digit" });
}

function moodFor(pct: number): { emoji: string; caption: string; color: string } {
  if (pct < 40) return { emoji: "😴", caption: "Encore un petit creux ?", color: "#8A8577" };
  if (pct < 90) return { emoji: "🙂", caption: "Sur la bonne voie", color: "#1FA876" };
  if (pct <= 110) return { emoji: "😋", caption: "Objectif atteint !", color: "#FF5A36" };
  return { emoji: "😅", caption: "Un peu au-dessus aujourd'hui", color: "#F2A600" };
}

/** Indicateur du jour : anneau de calories + petit personnage qui réagit à
 * la progression, macros vs objectif, liste des repas du jour, navigation
 * jour précédent/suivant. Les actions (ajouter un repas, recettes) sont
 * passées en `children` et s'affichent entre l'anneau et la liste. */
export function Dashboard({
  logs,
  dailyKcalGoal,
  onSetGoal,
  readOnly,
  children,
}: {
  logs: MealLog[];
  dailyKcalGoal: number | undefined;
  onSetGoal: (goal: number) => void;
  readOnly: boolean;
  children?: React.ReactNode;
}) {
  const goal = dailyKcalGoal && dailyKcalGoal > 0 ? dailyKcalGoal : DEFAULT_GOAL;
  const [dayOffset, setDayOffset] = useState(0);
  const [editingGoal, setEditingGoal] = useState(false);
  const [goalInput, setGoalInput] = useState(String(goal));
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const day = useMemo(() => {
    const d = new Date();
    d.setDate(d.getDate() + dayOffset);
    return d;
  }, [dayOffset]);
  const dayKey = localDayKey(day);

  const dayLogs = useMemo(
    () => logs.filter((l) => localDayKey(new Date(l.eatenAt)) === dayKey).sort((a, b) => a.eatenAt.localeCompare(b.eatenAt)),
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

  const pct = goal > 0 ? Math.round((totals.kcal / goal) * 100) : 0;
  const mood = moodFor(pct);
  const ringPct = Math.max(0, Math.min(100, pct));
  const circumference = 2 * Math.PI * 54;
  const dayLabel =
    dayOffset === 0 ? "Aujourd'hui" : dayOffset === -1 ? "Hier" : day.toLocaleDateString("fr-CH", { weekday: "short", day: "numeric", month: "short" });

  const proteinTarget = Math.round((goal * 0.25) / 4);
  const carbsTarget = Math.round((goal * 0.45) / 4);
  const fatTarget = Math.round((goal * 0.3) / 9);

  async function handleDelete(l: MealLog) {
    setDeletingId(l.id);
    try {
      await deleteMealLog(l.id, l.photoUrl);
    } finally {
      setDeletingId(null);
    }
  }

  function commitGoal() {
    const v = Number(goalInput);
    if (Number.isFinite(v) && v > 0) onSetGoal(Math.round(v));
    setEditingGoal(false);
  }

  return (
    <div className="rounded-3xl bg-surface p-4 shadow-[0_1px_3px_rgba(43,42,38,.08)] sm:p-5">
      <div className="mb-3 flex items-center justify-between gap-2">
        <button
          onClick={() => setDayOffset((o) => o - 1)}
          aria-label="Jour précédent"
          className="flex h-8 w-8 items-center justify-center rounded-full border border-line text-ink-soft hover:border-accent hover:text-accent"
        >
          ‹
        </button>
        <span className="text-[0.95rem] font-bold text-ink">{dayLabel}</span>
        <button
          onClick={() => setDayOffset((o) => Math.min(0, o + 1))}
          disabled={dayOffset === 0}
          aria-label="Jour suivant"
          className="flex h-8 w-8 items-center justify-center rounded-full border border-line text-ink-soft hover:border-accent hover:text-accent disabled:opacity-40"
        >
          ›
        </button>
      </div>

      <div className="flex flex-wrap items-center gap-5 sm:flex-nowrap">
        <div className="relative flex h-32 w-32 shrink-0 items-center justify-center">
          <svg viewBox="0 0 120 120" className="h-32 w-32 -rotate-90">
            <circle cx="60" cy="60" r="54" fill="none" stroke="var(--color-surface-2, #F2EFE4)" strokeWidth="10" />
            <circle
              cx="60"
              cy="60"
              r="54"
              fill="none"
              stroke={mood.color}
              strokeWidth="10"
              strokeLinecap="round"
              strokeDasharray={circumference}
              strokeDashoffset={circumference * (1 - ringPct / 100)}
              className="transition-[stroke-dashoffset] duration-500"
            />
          </svg>
          <div className="absolute flex flex-col items-center">
            <span className="animate-[pulse_2.5s_ease-in-out_infinite] text-[2rem] leading-none">{mood.emoji}</span>
            <span className="mt-1 font-mono text-[1rem] font-extrabold text-ink">{Math.round(totals.kcal)}</span>
            <span className="text-[0.62rem] uppercase tracking-wide text-ink-soft">/ {goal} kcal</span>
          </div>
        </div>

        <div className="min-w-0 flex-1">
          <p className="mb-2.5 text-[0.85rem] font-semibold text-ink">{mood.caption}</p>
          <div className="flex flex-col gap-2">
            <MacroBar label="Protéines" value={totals.proteinG} target={proteinTarget} color="#E5484D" />
            <MacroBar label="Glucides" value={totals.carbsG} target={carbsTarget} color="#FFC93C" />
            <MacroBar label="Lipides" value={totals.fatG} target={fatTarget} color="#17A2B8" />
          </div>
          <div className="mt-2.5 text-[0.74rem] text-ink-soft">
            Objectif :{" "}
            {editingGoal ? (
              <input
                autoFocus
                type="number"
                value={goalInput}
                onChange={(e) => setGoalInput(e.target.value)}
                onBlur={commitGoal}
                onKeyDown={(e) => e.key === "Enter" && commitGoal()}
                className="w-16 rounded border border-line bg-surface-2 px-1 py-0.5 text-[0.74rem] text-ink outline-none"
              />
            ) : (
              <button
                onClick={() => {
                  setGoalInput(String(goal));
                  setEditingGoal(true);
                }}
                className="font-semibold text-ink underline decoration-dotted underline-offset-2 hover:text-accent"
              >
                {goal} kcal/jour
              </button>
            )}
          </div>
        </div>
      </div>

      {children}

      <div className="mt-4">
        {dayLogs.length === 0 ? (
          <p className="text-[0.8rem] text-ink-soft">Aucun repas enregistré ce jour-là.</p>
        ) : (
          <ul className="flex flex-col gap-1.5">
            {dayLogs.map((l) => (
              <li key={l.id} className="flex items-center justify-between gap-2.5 rounded-xl bg-surface-2 px-3.5 py-2.5">
                <div className="min-w-0">
                  <p className="truncate text-[0.85rem] font-semibold text-ink">{l.label}</p>
                  <p className="text-[0.72rem] text-ink-soft">
                    {mealTypeLabel(l.mealType)} · {formatTime(l.eatenAt)} · {l.portionGrams} g
                  </p>
                </div>
                <div className="flex shrink-0 items-center gap-2">
                  <span className="whitespace-nowrap font-mono text-[0.8rem] text-ink">{l.kcal} kcal</span>
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
    </div>
  );
}

function MacroBar({ label, value, target, color }: { label: string; value: number; target: number; color: string }) {
  const pct = target > 0 ? Math.max(0, Math.min(100, (value / target) * 100)) : 0;
  return (
    <div className="flex items-center gap-2 text-[0.72rem]">
      <span className="w-16 shrink-0 text-ink-soft">{label}</span>
      <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-surface-2">
        <div className="h-full rounded-full transition-[width] duration-500" style={{ width: `${pct}%`, backgroundColor: color }} />
      </div>
      <span className="w-20 shrink-0 whitespace-nowrap text-right font-mono text-ink-soft">
        {Math.round(value)}/{target}g
      </span>
    </div>
  );
}
