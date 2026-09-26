"use client";

import { useMemo, useState } from "react";
import { dailyTotals } from "@/lib/habits";
import { localDayKey } from "@/lib/mealTypes";
import type { MealLog } from "@/lib/types";

const RANGES = [7, 14, 30] as const;

/** Évolution des calories jour par jour vs objectif + moyennes sur la
 * période (jours renseignés uniquement). Les parts estimées ("je ne sais
 * plus") sont hachurées. Affiché dès qu'au moins une journée est notée. */
export function Evolution({ logs, goal }: { logs: MealLog[]; goal: number }) {
  const [range, setRange] = useState<(typeof RANGES)[number]>(14);

  const { days, stats } = useMemo(() => {
    const totals = dailyTotals(logs, localDayKey);
    const days: { key: string; date: Date; kcal: number; estimated: number }[] = [];
    for (let i = range - 1; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const t = totals.get(localDayKey(d));
      days.push({ key: localDayKey(d), date: d, kcal: t?.kcal ?? 0, estimated: t?.estimated ?? 0 });
    }
    const filled = days.map((d) => totals.get(d.key)).filter((t): t is NonNullable<typeof t> => Boolean(t));
    const n = filled.length || 1;
    const avg = (f: (t: (typeof filled)[number]) => number) => Math.round(filled.reduce((a, t) => a + f(t), 0) / n);
    return {
      days,
      stats: {
        filledDays: filled.length,
        kcal: avg((t) => t.kcal),
        proteinG: avg((t) => t.proteinG),
        carbsG: avg((t) => t.carbsG),
        fatG: avg((t) => t.fatG),
        onTarget: filled.filter((t) => t.kcal >= goal * 0.9 && t.kcal <= goal * 1.1).length,
      },
    };
  }, [logs, range, goal]);

  const max = Math.max(goal * 1.3, ...days.map((d) => d.kcal));
  const H = 120;
  const barW = 100 / days.length;
  const goalY = H - (goal / max) * H;

  function colorFor(kcal: number) {
    if (kcal > goal * 1.1) return "var(--gold)";
    if (kcal >= goal * 0.9) return "var(--herb)";
    return "var(--accent-2)";
  }

  return (
    <section className="rounded-3xl bg-surface p-4 shadow-[0_1px_3px_rgba(43,42,38,.08)] sm:p-5">
      <div className="mb-3 flex items-center justify-between gap-2">
        <h2 className="text-[0.95rem] font-bold text-ink">📈 Mon évolution</h2>
        <div className="flex gap-1 rounded-full bg-surface-2 p-0.5">
          {RANGES.map((r) => (
            <button
              key={r}
              onClick={() => setRange(r)}
              className={`rounded-full px-2.5 py-1 text-[0.74rem] font-bold ${range === r ? "bg-surface text-ink shadow-sm" : "text-ink-soft"}`}
            >
              {r} j
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2">
        <Stat label="Moyenne / jour" value={`${stats.kcal}`} unit="kcal" />
        <Stat label="Jours notés" value={`${stats.filledDays}`} unit={`/ ${range}`} />
        <Stat label="Dans l'objectif" value={`${stats.onTarget}`} unit="jours" />
      </div>

      <svg viewBox={`0 0 100 ${H + 14}`} preserveAspectRatio="none" className="mt-4 h-40 w-full" role="img" aria-label="Calories par jour">
        <defs>
          <pattern id="hatch" width="2" height="2" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
            <rect width="1" height="2" fill="rgba(255,255,255,.55)" />
          </pattern>
        </defs>
        {days.map((d, i) => {
          const h = (d.kcal / max) * H;
          const eh = (d.estimated / max) * H;
          const x = i * barW + barW * 0.15;
          const w = barW * 0.7;
          return (
            <g key={d.key}>
              <title>{`${d.date.toLocaleDateString("fr-CH", { weekday: "short", day: "numeric", month: "short" })} : ${Math.round(d.kcal)} kcal${d.estimated ? ` (dont ${Math.round(d.estimated)} estimées)` : ""}`}</title>
              {d.kcal > 0 ? (
                <>
                  <rect x={x} y={H - h} width={w} height={h} rx={0.8} fill={colorFor(d.kcal)} />
                  {eh > 0 && <rect x={x} y={H - h} width={w} height={eh} fill="url(#hatch)" />}
                </>
              ) : (
                <rect x={x} y={H - 1} width={w} height={1} fill="var(--line)" />
              )}
            </g>
          );
        })}
        <line x1="0" x2="100" y1={goalY} y2={goalY} stroke="var(--ink-soft)" strokeWidth="0.4" strokeDasharray="1.5 1" vectorEffect="non-scaling-stroke" />
      </svg>
      <div className="flex justify-between text-[0.66rem] text-ink-soft">
        <span>{days[0].date.toLocaleDateString("fr-CH", { day: "numeric", month: "short" })}</span>
        <span>- - objectif {goal} kcal</span>
        <span>aujourd&apos;hui</span>
      </div>

      {stats.filledDays > 0 && (
        <p className="mt-3 text-[0.78rem] text-ink-soft">
          En moyenne : <strong className="text-ink">{stats.proteinG} g</strong> de protéines,{" "}
          <strong className="text-ink">{stats.carbsG} g</strong> de glucides, <strong className="text-ink">{stats.fatG} g</strong> de lipides par jour.
        </p>
      )}
      <div className="mt-2 flex flex-wrap gap-3 text-[0.68rem] text-ink-soft">
        <Legend color="var(--accent-2)" label="sous l'objectif" />
        <Legend color="var(--herb)" label="dans l'objectif (±10 %)" />
        <Legend color="var(--gold)" label="au-dessus" />
      </div>
    </section>
  );
}

function Stat({ label, value, unit }: { label: string; value: string; unit: string }) {
  return (
    <div className="rounded-2xl bg-surface-2 px-3 py-2.5">
      <div className="text-[0.68rem] font-semibold text-ink-soft">{label}</div>
      <div className="font-mono text-[1.1rem] font-extrabold text-ink">
        {value} <span className="text-[0.7rem] font-semibold text-ink-soft">{unit}</span>
      </div>
    </div>
  );
}

function Legend({ color, label }: { color: string; label: string }) {
  return (
    <span className="inline-flex items-center gap-1">
      <span className="h-2 w-2 rounded-full" style={{ backgroundColor: color }} />
      {label}
    </span>
  );
}
