"use client";

import { useMemo, useState } from "react";
import { dayLabel, localDayKey, mealTypeLabel } from "@/lib/mealTypes";
import type { MealLog } from "@/lib/types";

const DEFAULT_GOAL = 2000;

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
 * jour précédent/suivant (piloté par la page : les ajouts vont sur le jour
 * affiché). Chaque repas est cliquable pour le modifier. Les actions
 * (ajouter un repas, en-cas, recettes) sont passées en `children`. */
export function Dashboard({
  logs,
  dailyKcalGoal,
  onSetGoal,
  dayOffset,
  onDayOffset,
  onEditLog,
  readOnly,
  children,
}: {
  logs: MealLog[];
  dailyKcalGoal: number | undefined;
  onSetGoal: (goal: number) => void;
  dayOffset: number;
  onDayOffset: (offset: number) => void;
  onEditLog: (log: MealLog) => void;
  readOnly: boolean;
  children?: React.ReactNode;
}) {
  const goal = dailyKcalGoal && dailyKcalGoal > 0 ? dailyKcalGoal : DEFAULT_GOAL;
  const [editingGoal, setEditingGoal] = useState(false);
  const [goalInput, setGoalInput] = useState(String(goal));

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

  const proteinTarget = Math.round((goal * 0.25) / 4);
  const carbsTarget = Math.round((goal * 0.45) / 4);
  const fatTarget = Math.round((goal * 0.3) / 9);

  function commitGoal() {
    const v = Number(goalInput);
    if (Number.isFinite(v) && v > 0) onSetGoal(Math.round(v));
    setEditingGoal(false);
  }

  return (
    <div className="rounded-3xl bg-surface p-4 shadow-[0_1px_3px_rgba(43,42,38,.08)] sm:p-5">
      <div className="mb-3 flex items-center justify-between gap-2">
        <button
          onClick={() => onDayOffset(dayOffset - 1)}
          aria-label="Jour précédent"
          className="flex h-8 w-8 items-center justify-center rounded-full border border-line text-ink-soft hover:border-accent hover:text-accent"
        >
          ‹
        </button>
        <span className="text-[0.95rem] font-bold text-ink">{dayLabel(day)}</span>
        <button
          onClick={() => onDayOffset(Math.min(0, dayOffset + 1))}
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
              <li key={l.id}>
                <button
                  onClick={() => onEditLog(l)}
                  disabled={readOnly}
                  className="flex w-full items-center justify-between gap-2.5 rounded-xl bg-surface-2 px-3.5 py-2.5 text-left transition hover:brightness-[.97] active:scale-[.99]"
                >
                  <div className="min-w-0">
                    <p className="truncate text-[0.85rem] font-semibold text-ink">{l.label}</p>
                    <p className="text-[0.72rem] text-ink-soft">
                      {mealTypeLabel(l.mealType)} · {formatTime(l.eatenAt)} · {l.portionGrams} g
                    </p>
                  </div>
                  <div className="flex shrink-0 items-center gap-2">
                    <span className="whitespace-nowrap font-mono text-[0.8rem] text-ink">{l.kcal} kcal</span>
                    {!readOnly && (
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="h-3.5 w-3.5 text-ink-soft" aria-hidden>
                        <path d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z" />
                      </svg>
                    )}
                  </div>
                </button>
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
