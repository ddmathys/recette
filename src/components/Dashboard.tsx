"use client";

import { useMemo, useState } from "react";
import { MEAL_TYPES, dayLabel, localDayKey } from "@/lib/mealTypes";
import type { MealLog, MealType } from "@/lib/types";

const DEFAULT_GOAL = 2000;
const R = 56;
const C = 2 * Math.PI * R;

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString("fr-CH", { hour: "2-digit", minute: "2-digit" });
}

function moodFor(pct: number): { emoji: string; caption: string } {
  if (pct < 40) return { emoji: "😴", caption: "La journée commence" };
  if (pct < 90) return { emoji: "🙂", caption: "Sur la bonne voie" };
  if (pct <= 110) return { emoji: "😋", caption: "Objectif atteint !" };
  return { emoji: "😅", caption: "Un peu au-dessus" };
}

/**
 * « Ma journée » : anneau de calories segmenté par moment de la journée,
 * macros vs objectif, puis les 4 créneaux (petit-déj / déjeuner / dîner /
 * collations), chacun avec son total et son bouton « + » qui ouvre tout ce
 * qu'on peut y mettre (habituels, recettes, photo, description).
 * La navigation jour précédent/suivant est pilotée par la page : les ajouts
 * vont sur le jour affiché. Chaque repas noté est cliquable pour le
 * modifier. `children` = tuiles de navigation sous les créneaux.
 */
export function Dashboard({
  logs,
  dailyKcalGoal,
  onSetGoal,
  dayOffset,
  onDayOffset,
  onEditLog,
  onAddToSlot,
  onEstimateDay,
  readOnly,
  children,
}: {
  logs: MealLog[];
  dailyKcalGoal: number | undefined;
  onSetGoal: (goal: number) => void;
  dayOffset: number;
  onDayOffset: (offset: number) => void;
  onEditLog: (log: MealLog) => void;
  /** Ouvre le choix d'ajout pour ce créneau, sur le jour affiché. */
  onAddToSlot: (slot: MealType) => void;
  /** Ouvre "je ne sais plus → estimer la journée" pour le jour affiché. */
  onEstimateDay: () => void;
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

  // Un total de journée estimé ("je ne sais plus") n'appartient à aucun
  // créneau : il est listé à part, sous les créneaux.
  const estimates = useMemo(() => dayLogs.filter((l) => l.source === "estimate"), [dayLogs]);
  const bySlot = useMemo(() => {
    const m = new Map<MealType, MealLog[]>(MEAL_TYPES.map((s) => [s.key, [] as MealLog[]]));
    for (const l of dayLogs) {
      if (l.source === "estimate") continue;
      m.get(l.mealType)?.push(l);
    }
    return m;
  }, [dayLogs]);

  const pct = goal > 0 ? Math.round((totals.kcal / goal) * 100) : 0;
  const mood = moodFor(pct);
  const left = Math.round(goal - totals.kcal);

  // Anneau : un arc par créneau, dans l'ordre de la journée.
  const ring = useMemo(() => {
    const segs: { color: string; len: number; start: number }[] = [];
    let cursor = 0;
    const push = (kcal: number, color: string) => {
      if (kcal <= 0) return;
      const raw = (kcal / goal) * C;
      const len = Math.max(0, Math.min(raw, C - cursor));
      if (len > 0.5) segs.push({ color, len, start: cursor });
      cursor += raw;
    };
    for (const slot of MEAL_TYPES) {
      push((bySlot.get(slot.key) ?? []).reduce((a, l) => a + l.kcal, 0), slot.color);
    }
    push(estimates.reduce((a, l) => a + l.kcal, 0), "#8A8577");
    return { segs, over: cursor > C };
  }, [bySlot, estimates, goal]);

  const proteinTarget = Math.round((goal * 0.25) / 4);
  const carbsTarget = Math.round((goal * 0.45) / 4);
  const fatTarget = Math.round((goal * 0.3) / 9);

  function commitGoal() {
    const v = Number(goalInput);
    if (Number.isFinite(v) && v > 0) onSetGoal(Math.round(v));
    setEditingGoal(false);
  }

  return (
    <div className="flex flex-col gap-3">
      {/* Anneau du jour */}
      <section className="overflow-hidden rounded-[1.75rem] bg-surface shadow-[0_2px_14px_-6px_rgba(43,42,38,.28)]">
        <div className="bg-[linear-gradient(160deg,#fffdf8_0%,#fdf4e4_100%)] px-4 pb-5 pt-3.5 sm:px-6">
          <div className="mb-1 flex items-center justify-between gap-2">
            <button
              onClick={() => onDayOffset(dayOffset - 1)}
              aria-label="Jour précédent"
              className="flex h-9 w-9 items-center justify-center rounded-full bg-surface text-[1.1rem] text-ink-soft shadow-[0_1px_3px_rgba(43,42,38,.1)] transition hover:text-accent active:scale-90"
            >
              ‹
            </button>
            <div className="text-center">
              <p className="text-[1.05rem] font-extrabold leading-tight tracking-tight text-ink">{dayLabel(day)}</p>
              <p className="text-[0.7rem] font-semibold uppercase tracking-wider text-ink-soft">
                {day.toLocaleDateString("fr-CH", { weekday: "long", day: "numeric", month: "long" })}
              </p>
            </div>
            <button
              onClick={() => onDayOffset(Math.min(0, dayOffset + 1))}
              disabled={dayOffset === 0}
              aria-label="Jour suivant"
              className="flex h-9 w-9 items-center justify-center rounded-full bg-surface text-[1.1rem] text-ink-soft shadow-[0_1px_3px_rgba(43,42,38,.1)] transition hover:text-accent active:scale-90 disabled:opacity-30 disabled:shadow-none"
            >
              ›
            </button>
          </div>

          <div className="flex flex-col items-center gap-4 sm:flex-row sm:gap-6">
            <div className="relative flex h-[9.5rem] w-[9.5rem] shrink-0 items-center justify-center">
              <svg viewBox="0 0 140 140" className="h-[9.5rem] w-[9.5rem] -rotate-90">
                <circle cx="70" cy="70" r={R} fill="none" stroke="#efe7d6" strokeWidth="13" />
                {ring.segs.map((s, i) => (
                  <circle
                    key={i}
                    cx="70"
                    cy="70"
                    r={R}
                    fill="none"
                    stroke={s.color}
                    strokeWidth="13"
                    strokeDasharray={`${s.len} ${C - s.len}`}
                    strokeDashoffset={-s.start}
                    className="transition-all duration-700 ease-out"
                  />
                ))}
                {ring.over && <circle cx="70" cy="70" r={R - 10} fill="none" stroke="var(--gold)" strokeWidth="3" strokeDasharray="4 3" />}
              </svg>
              <div className="absolute flex flex-col items-center">
                <span className="font-mono text-[2.05rem] font-extrabold leading-none tracking-tight text-ink">{Math.round(totals.kcal)}</span>
                <span className="mt-0.5 text-[0.66rem] font-bold uppercase tracking-widest text-ink-soft">kcal</span>
                <span className="mt-1.5 rounded-full bg-surface px-2.5 py-0.5 text-[0.7rem] font-bold text-ink-soft shadow-[0_1px_2px_rgba(43,42,38,.1)]">
                  {left > 0 ? `reste ${left}` : left === 0 ? "pile !" : `+${Math.abs(left)}`}
                </span>
              </div>
              <span className="absolute -right-1 top-1 flex h-9 w-9 items-center justify-center rounded-full bg-surface text-[1.25rem] shadow-[0_2px_6px_rgba(43,42,38,.16)]">
                {mood.emoji}
              </span>
            </div>

            <div className="min-w-0 flex-1 self-stretch">
              <div className="mb-2 flex flex-wrap items-baseline gap-x-2">
                <p className="text-[0.95rem] font-extrabold text-ink">{mood.caption}</p>
                <p className="text-[0.78rem] text-ink-soft">
                  objectif{" "}
                  {editingGoal ? (
                    <input
                      autoFocus
                      type="number"
                      value={goalInput}
                      onChange={(e) => setGoalInput(e.target.value)}
                      onBlur={commitGoal}
                      onKeyDown={(e) => e.key === "Enter" && commitGoal()}
                      className="w-16 rounded border border-line bg-surface px-1 py-0.5 text-[0.78rem] text-ink outline-none"
                    />
                  ) : (
                    <button
                      onClick={() => {
                        setGoalInput(String(goal));
                        setEditingGoal(true);
                      }}
                      className="font-bold text-ink underline decoration-dotted underline-offset-2 hover:text-accent"
                    >
                      {goal} kcal
                    </button>
                  )}
                </p>
              </div>
              <div className="flex flex-col gap-2">
                <MacroBar label="Protéines" value={totals.proteinG} target={proteinTarget} color="#E5484D" />
                <MacroBar label="Glucides" value={totals.carbsG} target={carbsTarget} color="#FFC93C" />
                <MacroBar label="Lipides" value={totals.fatG} target={fatTarget} color="#17A2B8" />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Les 4 créneaux du jour */}
      <section className="rounded-[1.75rem] bg-surface p-3.5 shadow-[0_1px_3px_rgba(43,42,38,.08)] sm:p-4">
        <div className="mb-2.5 flex items-baseline justify-between gap-2 px-1">
          <h2 className="text-[0.95rem] font-extrabold text-ink">Ce que j&apos;ai mangé</h2>
          <span className="font-mono text-[0.78rem] text-ink-soft">{Math.round(totals.kcal)} kcal</span>
        </div>
        <ul className="flex flex-col gap-2">
          {MEAL_TYPES.map((slot) => {
            const slotLogs = bySlot.get(slot.key) ?? [];
            const kcal = slotLogs.reduce((a, l) => a + l.kcal, 0);
            return (
              <li key={slot.key} className="overflow-hidden rounded-2xl bg-surface-2">
                <div className="flex items-center gap-2.5 px-3 py-2.5">
                  <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-[1.05rem]" style={{ backgroundColor: `${slot.color}22` }}>
                    {slot.emoji}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="text-[0.9rem] font-extrabold leading-tight text-ink">{slot.label}</p>
                    <p className="text-[0.72rem] text-ink-soft">
                      {slotLogs.length === 0
                        ? "rien de noté"
                        : `${slotLogs.length} ${slotLogs.length > 1 ? "entrées" : "entrée"} · ${Math.round(kcal)} kcal`}
                    </p>
                  </div>
                  {!readOnly && (
                    <button
                      onClick={() => onAddToSlot(slot.key)}
                      aria-label={`Ajouter au ${slot.label.toLowerCase()}`}
                      className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-[1.3rem] font-bold text-white shadow-[0_2px_8px_-3px_rgba(43,42,38,.5)] transition active:scale-90"
                      style={{ backgroundColor: slot.color }}
                    >
                      +
                    </button>
                  )}
                </div>
                {slotLogs.length > 0 && (
                  <ul className="flex flex-col gap-1 px-2 pb-2">
                    {slotLogs.map((l) => (
                      <li key={l.id}>
                        <button
                          onClick={() => onEditLog(l)}
                          disabled={readOnly}
                          className="flex w-full items-center justify-between gap-2.5 rounded-xl bg-surface px-3 py-2 text-left transition hover:brightness-[.98] active:scale-[.99]"
                        >
                          <div className="min-w-0">
                            <p className="truncate text-[0.84rem] font-semibold text-ink">
                              {l.label}
                              {l.count && l.count > 1 ? <span className="text-ink-soft"> ×{l.count}</span> : null}
                            </p>
                            <p className="text-[0.7rem] text-ink-soft">
                              {formatTime(l.eatenAt)} · {l.portionGrams} g{l.recipeId ? " · depuis une recette" : ""}
                            </p>
                          </div>
                          <div className="flex shrink-0 items-center gap-2">
                            <span className="whitespace-nowrap font-mono text-[0.8rem] font-bold text-ink">{l.kcal}</span>
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
              </li>
            );
          })}
        </ul>

        {estimates.length > 0 && (
          <ul className="mt-2 flex flex-col gap-1">
            {estimates.map((l) => (
              <li key={l.id}>
                <button
                  onClick={() => onEditLog(l)}
                  disabled={readOnly}
                  className="flex w-full items-center justify-between gap-2.5 rounded-2xl border border-dashed border-line px-3.5 py-2.5 text-left"
                >
                  <div className="min-w-0">
                    <p className="truncate text-[0.84rem] font-semibold text-ink">{l.label}</p>
                    <p className="text-[0.7rem] text-ink-soft">Estimation · valeurs approximatives</p>
                  </div>
                  <span className="shrink-0 whitespace-nowrap font-mono text-[0.8rem] font-bold text-ink">{l.kcal}</span>
                </button>
              </li>
            ))}
          </ul>
        )}

        {!readOnly && dayLogs.length === 0 && (
          <button
            onClick={onEstimateDay}
            className="mt-2.5 w-full rounded-2xl border border-dashed border-line py-2.5 text-[0.78rem] font-semibold text-ink-soft hover:border-accent hover:text-accent"
          >
            Je ne sais plus ce que j&apos;ai mangé → estimer la journée
          </button>
        )}
      </section>

      {children}
    </div>
  );
}

function MacroBar({ label, value, target, color }: { label: string; value: number; target: number; color: string }) {
  const pct = target > 0 ? Math.max(0, Math.min(100, (value / target) * 100)) : 0;
  return (
    <div className="flex items-center gap-2 text-[0.72rem]">
      <span className="w-[4.2rem] shrink-0 font-semibold text-ink-soft">{label}</span>
      <div className="h-2 flex-1 overflow-hidden rounded-full bg-[#efe7d6]">
        <div className="h-full rounded-full transition-[width] duration-700 ease-out" style={{ width: `${pct}%`, backgroundColor: color }} />
      </div>
      <span className="w-[4.4rem] shrink-0 whitespace-nowrap text-right font-mono text-ink-soft">
        {Math.round(value)}/{target} g
      </span>
    </div>
  );
}
