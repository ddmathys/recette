"use client";

import { useMemo, useState } from "react";
import { addMealLog } from "@/lib/useMealLogs";
import { habitToDraft, slotHabits, type Habit } from "@/lib/habits";
import { dayLabel, eatenAtFor, mealTypeMeta } from "@/lib/mealTypes";
import type { MealLog, MealType, Recipe } from "@/lib/types";

/** Nombre d'habitudes visibles avant « Voir les autres ». */
const TOP = 3;

type Macros = { kcal: number; proteinG: number; carbsG: number; fatG: number };

/**
 * Écran « + » d'un créneau du dashboard (petit-déj, déjeuner, dîner,
 * collation) : d'abord MES habitudes — tout ce que j'ai déjà noté, quel que
 * soit le créneau (le yaourt de la collation sert aussi au petit-déj),
 * celles de ce créneau en tête, les 3 premières puis le reste à déplier.
 * Chacune se note en 1 tap, ou avec des calories saisies à la main (✎).
 * La recherche fouille habitudes et recettes, toujours avec kcal + macros.
 * Chaque ajout est noté sur le jour affiché au dashboard et dans ce créneau.
 */
export function AddToSlotSheet({
  slot,
  day,
  recipes,
  logs,
  owner,
  onClose,
  onPhoto,
  onDescribe,
  onOpenRecipe,
  onViewRecipe,
}: {
  slot: MealType;
  day: Date;
  recipes: Recipe[];
  logs: MealLog[];
  owner: { uid: string; name: string; householdId: string };
  onClose: () => void;
  /** Photo d'assiette → analyse IA, notée dans ce créneau. */
  onPhoto: () => void;
  /** Description libre → estimation IA, notée dans ce créneau. */
  onDescribe: () => void;
  /** Recette sans estimation nutritionnelle : on passe par l'écran complet. */
  onOpenRecipe: (recipe: Recipe) => void;
  /** Ouvre la fiche (ingrédients, étapes) par-dessus cet écran. */
  onViewRecipe: (recipe: Recipe) => void;
}) {
  const meta = mealTypeMeta(slot);
  const habits = useMemo(() => slotHabits(logs, owner.uid, slot), [logs, owner.uid, slot]);
  const [search, setSearch] = useState("");
  const [added, setAdded] = useState<{ label: string; kcal: number }[]>([]);
  const [showAll, setShowAll] = useState(false);
  const [manual, setManual] = useState(false);

  // Recette d'une habitude : par son lien, sinon par le nom (les repas notés
  // par photo ou description n'ont pas de recipeId mais portent souvent le
  // nom exact d'une recette de la bibliothèque).
  const recipeFor = useMemo(() => {
    const byId = new Map(recipes.map((r) => [r.id, r]));
    const byName = new Map(recipes.map((r) => [r.name.trim().toLowerCase(), r]));
    return (h: Habit) => (h.recipeId && byId.get(h.recipeId)) || byName.get(h.label.toLowerCase()) || null;
  }, [recipes]);

  const q = search.trim().toLowerCase();
  const foundHabits = q ? habits.filter((h) => h.label.toLowerCase().includes(q)) : [];
  // Une recette déjà proposée comme habitude n'apparaît pas deux fois.
  const shown = new Set(foundHabits.map((h) => recipeFor(h)?.id));
  const foundRecipes = !q
    ? []
    : recipes
        .filter((r) => !shown.has(r.id))
        .filter((r) => r.name.toLowerCase().includes(q) || r.ingr.some((i) => i.name.toLowerCase().includes(q)))
        .sort((a, b) => Number(!a.nutrition) - Number(!b.nutrition) || a.name.localeCompare(b.name, "fr"));

  async function logHabit(h: Habit, count: number, override?: Macros) {
    const unit = override ? { ...h, ...override } : h;
    await addMealLog(habitToDraft(unit, count, slot, eatenAtFor(day, slot)), null, h.recipeId ? "recipe" : "manual", owner);
    setAdded((a) => [...a, { label: h.label, kcal: Math.round(unit.kcal * count) }]);
  }

  async function logRecipe(r: Recipe, portions: number) {
    const n = r.nutrition;
    if (!n) {
      onOpenRecipe(r);
      return;
    }
    await addMealLog(
      {
        recipeId: r.id,
        label: r.name,
        mealType: slot,
        eatenAt: eatenAtFor(day, slot).toISOString(),
        portionGrams: Math.round(n.gramsPerServing * portions),
        kcal: Math.round(n.kcal * portions),
        proteinG: Math.round(n.proteinG * portions),
        carbsG: Math.round(n.carbsG * portions),
        fatG: Math.round(n.fatG * portions),
        ...(portions !== 1 ? { count: portions } : {}),
      },
      null,
      "recipe",
      owner,
    );
    setAdded((a) => [...a, { label: r.name, kcal: Math.round(n.kcal * portions) }]);
  }

  async function logManual(label: string, m: Macros) {
    await addMealLog(
      { recipeId: null, label, mealType: slot, eatenAt: eatenAtFor(day, slot).toISOString(), portionGrams: 0, ...m },
      null,
      "manual",
      owner,
    );
    setAdded((a) => [...a, { label, kcal: m.kcal }]);
    setManual(false);
  }

  const totalAdded = added.reduce((a, x) => a + x.kcal, 0);
  const isToday = day.toDateString() === new Date().toDateString();
  const visible = showAll ? habits : habits.slice(0, TOP);
  const doneCount = (label: string) => added.filter((a) => a.label === label).length;

  const habitRow = (h: Habit & { inSlot: number }) => (
    <HabitRow
      key={h.label.toLowerCase()}
      habit={h}
      slotLabel={meta.short.toLowerCase()}
      recipe={recipeFor(h)}
      done={doneCount(h.label)}
      onLog={(count, override) => logHabit(h, count, override)}
      onViewRecipe={onViewRecipe}
    />
  );

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-bg">
      <header className="sticky top-0 z-10 border-b border-line bg-bg/95 backdrop-blur" style={{ paddingTop: "env(safe-area-inset-top, 0px)" }}>
        <div className="mx-auto flex max-w-[640px] items-center gap-3 px-4 py-3">
          <button
            onClick={onClose}
            aria-label="Fermer"
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-surface text-ink shadow-[0_1px_3px_rgba(43,42,38,.08)]"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" className="h-4.5 w-4.5">
              <path d="M15 18l-6-6 6-6" />
            </svg>
          </button>
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-[1.1rem]" style={{ backgroundColor: `${meta.color}22` }}>
            {meta.emoji}
          </span>
          <h2 className="min-w-0 flex-1 truncate text-[1.1rem] font-extrabold tracking-tight text-ink">{meta.label}</h2>
          {!isToday && <span className="shrink-0 rounded-full bg-gold/15 px-3 py-1 text-[0.76rem] font-bold text-gold">📅 {dayLabel(day)}</span>}
        </div>
      </header>

      <main className="mx-auto flex max-w-[640px] flex-col gap-3.5 px-4 pb-32 pt-4">
        <label className="flex items-center gap-2 rounded-full border-2 border-transparent bg-surface px-4 py-2.5 shadow-[0_1px_3px_rgba(43,42,38,.08)] transition focus-within:border-accent">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" className="h-4 w-4 shrink-0 text-accent">
            <circle cx="11" cy="11" r="7" />
            <path d="m21 21-4.3-4.3" />
          </svg>
          <input
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Chercher dans mes habitudes et recettes…"
            className="w-full bg-transparent text-[0.92rem] text-ink outline-none placeholder:text-ink-soft"
          />
        </label>

        {q ? (
          <section className="rounded-3xl bg-surface p-4 shadow-[0_1px_3px_rgba(43,42,38,.08)]">
            {foundHabits.length === 0 && foundRecipes.length === 0 ? (
              <p className="py-3 text-center text-[0.84rem] text-ink-soft">Rien ne correspond — essaie « Décrire » ou « À la main » ci-dessous.</p>
            ) : (
              <>
                {foundHabits.length > 0 && (
                  <>
                    <h3 className="mb-1 text-[0.78rem] font-bold uppercase tracking-wider text-ink-soft">Mes habitudes</h3>
                    <ul className="mb-2 flex flex-col divide-y divide-line">{foundHabits.map(habitRow)}</ul>
                  </>
                )}
                {foundRecipes.length > 0 && (
                  <>
                    <h3 className="mb-1 mt-1 text-[0.78rem] font-bold uppercase tracking-wider text-ink-soft">Dans mes recettes</h3>
                    <ul className="flex flex-col divide-y divide-line">
                      {foundRecipes.map((r) => (
                        <RecipeRow key={r.id} recipe={r} done={doneCount(r.name)} onLog={(p) => logRecipe(r, p)} onView={() => onViewRecipe(r)} />
                      ))}
                    </ul>
                  </>
                )}
              </>
            )}
          </section>
        ) : (
          <section className="rounded-3xl bg-surface p-4 shadow-[0_1px_3px_rgba(43,42,38,.08)]">
            <h3 className="mb-1 text-[0.78rem] font-bold uppercase tracking-wider text-ink-soft">Mes habitudes</h3>
            {habits.length === 0 ? (
              <p className="py-3 text-[0.84rem] text-ink-soft">
                Rien encore noté. Ajoute un premier repas ci-dessous : il apparaîtra ici pour être renoté en un tap.
              </p>
            ) : (
              <>
                <p className="mb-1 text-[0.76rem] text-ink-soft">Touche la quantité : c&apos;est noté. ✎ pour mettre tes propres calories.</p>
                <ul className="flex flex-col divide-y divide-line">{visible.map(habitRow)}</ul>
                {habits.length > TOP && (
                  <button
                    onClick={() => setShowAll((v) => !v)}
                    className="mt-2 w-full rounded-xl bg-surface-2 py-2.5 text-[0.82rem] font-bold text-ink-soft hover:text-accent"
                  >
                    {showAll ? "Réduire" : `Voir mes ${habits.length - TOP} autres habitudes ▾`}
                  </button>
                )}
              </>
            )}
          </section>
        )}

        <section className="rounded-3xl bg-surface p-4 shadow-[0_1px_3px_rgba(43,42,38,.08)]">
          <h3 className="mb-2.5 text-[0.78rem] font-bold uppercase tracking-wider text-ink-soft">Autre chose</h3>
          <div className="grid grid-cols-3 gap-2">
            <button
              onClick={onPhoto}
              className="flex flex-col items-start gap-1 rounded-2xl bg-accent p-3 text-left text-accent-ink shadow-[0_6px_18px_-8px_rgba(255,90,54,.8)] transition active:scale-[.97]"
            >
              <span className="text-[1.4rem] leading-none">📸</span>
              <span className="text-[0.88rem] font-extrabold">Photo</span>
              <span className="text-[0.7rem] text-accent-ink/85">de mon assiette</span>
            </button>
            <button
              onClick={onDescribe}
              className="flex flex-col items-start gap-1 rounded-2xl bg-accent-2/12 p-3 text-left text-ink transition active:scale-[.97]"
            >
              <span className="text-[1.4rem] leading-none">✍️</span>
              <span className="text-[0.88rem] font-extrabold">Décrire</span>
              <span className="text-[0.7rem] text-ink-soft">l&apos;IA estime</span>
            </button>
            <button
              onClick={() => setManual((v) => !v)}
              className={`flex flex-col items-start gap-1 rounded-2xl p-3 text-left text-ink transition active:scale-[.97] ${manual ? "bg-herb/20" : "bg-herb/10"}`}
            >
              <span className="text-[1.4rem] leading-none">🔢</span>
              <span className="text-[0.88rem] font-extrabold">À la main</span>
              <span className="text-[0.7rem] text-ink-soft">mes calories</span>
            </button>
          </div>
          {manual && <ManualEntry onSave={logManual} />}
        </section>
      </main>

      {/* Récapitulatif collant : ce que ce passage a ajouté. */}
      <div
        className="fixed bottom-0 left-0 right-0 z-10 border-t border-line bg-bg/95 px-4 py-3 backdrop-blur"
        style={{ paddingBottom: "max(0.75rem, env(safe-area-inset-bottom, 0px))" }}
      >
        <div className="mx-auto flex max-w-[640px] items-center gap-3">
          <p className="min-w-0 flex-1 text-[0.82rem] text-ink-soft">
            {added.length === 0 ? (
              "Touche une quantité : c'est noté tout de suite."
            ) : (
              <>
                <strong className="text-herb">✓ {added.length} ajout{added.length > 1 ? "s" : ""}</strong> ·{" "}
                <span className="font-mono font-bold text-ink">{totalAdded} kcal</span>
              </>
            )}
          </p>
          <button
            onClick={onClose}
            className={`shrink-0 rounded-2xl px-5 py-3 text-[0.9rem] font-bold transition active:scale-[.97] ${
              added.length ? "bg-herb text-white" : "bg-surface text-ink shadow-[0_1px_3px_rgba(43,42,38,.1)]"
            }`}
          >
            {added.length ? "Terminé" : "Fermer"}
          </button>
        </div>
      </div>
    </div>
  );
}

function macroLine(m: Macros) {
  return (
    <>
      <span className="font-mono font-bold text-ink">{Math.round(m.kcal)} kcal</span> · P {Math.round(m.proteinG)} · G {Math.round(m.carbsG)} · L{" "}
      {Math.round(m.fatG)}
    </>
  );
}

const qtyBtn =
  "h-9 min-w-9 rounded-full border-2 border-line bg-surface px-1.5 text-[0.78rem] font-bold text-ink transition hover:border-accent hover:text-accent disabled:opacity-50";

/** Une habitude : macros à l'unité, lien vers sa recette, ×1–×3, et ✎ pour
 * corriger les calories avant de noter (le repas noté porte alors ces
 * valeurs, que l'habitude reprend la fois suivante). */
function HabitRow({
  habit: h,
  slotLabel,
  recipe,
  done,
  onLog,
  onViewRecipe,
}: {
  habit: Habit & { inSlot: number };
  slotLabel: string;
  recipe: Recipe | null;
  done: number;
  onLog: (count: number, override?: Macros) => Promise<void>;
  onViewRecipe: (r: Recipe) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [m, setM] = useState<Macros>({ kcal: h.kcal, proteinG: h.proteinG, carbsG: h.carbsG, fatG: h.fatG });
  const [busy, setBusy] = useState(false);

  async function log(count: number) {
    setBusy(true);
    try {
      await onLog(count, editing ? m : undefined);
      setEditing(false);
    } finally {
      setBusy(false);
    }
  }

  return (
    <li className="py-2.5">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="min-w-0 flex-1">
          <p className="line-clamp-2 text-[0.9rem] font-semibold leading-tight text-ink">{h.label}</p>
          <p className="text-[0.72rem] leading-snug text-ink-soft">
            {macroLine(editing ? m : h)} <span className="text-ink-soft/80">/ unité</span>
          </p>
          <p className="text-[0.7rem] text-ink-soft/80">
            {h.inSlot > 0 ? `${h.inSlot}× au ${slotLabel}` : `noté ${h.times}×`}
            {recipe && (
              <>
                {" · "}
                <button onClick={() => onViewRecipe(recipe)} className="font-bold text-accent">
                  📖 Recette
                </button>
              </>
            )}
          </p>
        </div>
        <div className="flex shrink-0 items-center gap-1">
          {done > 0 && <span className="mr-0.5 text-[0.78rem] font-bold text-herb">✓{done > 1 ? `×${done}` : ""}</span>}
          {[1, 2, 3].map((n) => (
            <button key={n} disabled={busy} onClick={() => log(n)} className={qtyBtn}>
              ×{n}
            </button>
          ))}
          <button
            onClick={() => setEditing((v) => !v)}
            aria-label="Mettre mes calories"
            className={`${qtyBtn} ${editing ? "border-accent text-accent" : ""}`}
          >
            ✎
          </button>
        </div>
      </div>
      {editing && (
        <div className="mt-2 rounded-2xl bg-surface-2 p-3">
          <MacroInputs value={m} onChange={setM} />
          <p className="mt-2 text-[0.72rem] text-ink-soft">Par unité — touche ×1, ×2 ou ×3 pour noter avec ces valeurs.</p>
        </div>
      )}
    </li>
  );
}

/** Une recette trouvée par la recherche : macros par portion, ½/×1/×2. */
function RecipeRow({ recipe: r, done, onLog, onView }: { recipe: Recipe; done: number; onLog: (portions: number) => Promise<void>; onView: () => void }) {
  const [busy, setBusy] = useState(false);
  const n = r.nutrition;

  async function log(p: number) {
    setBusy(true);
    try {
      await onLog(p);
    } finally {
      setBusy(false);
    }
  }

  return (
    <li className="flex flex-wrap items-center justify-between gap-2 py-2.5">
      <div className="min-w-0 flex-1">
        <p className="line-clamp-2 text-[0.9rem] font-semibold leading-tight text-ink">{r.name}</p>
        <p className="text-[0.72rem] leading-snug text-ink-soft">
          {n ? (
            <>
              {macroLine(n)} <span className="text-ink-soft/80">/ portion</span>
            </>
          ) : (
            "pas encore d'estimation — « Estimer » la calcule"
          )}
        </p>
        <button onClick={onView} className="text-[0.7rem] font-bold text-accent">
          📖 Recette
        </button>
      </div>
      <div className="flex shrink-0 items-center gap-1">
        {done > 0 && <span className="mr-0.5 text-[0.78rem] font-bold text-herb">✓{done > 1 ? `×${done}` : ""}</span>}
        {n ? (
          [0.5, 1, 2].map((p) => (
            <button key={p} disabled={busy} onClick={() => log(p)} className={qtyBtn}>
              {p === 0.5 ? "½" : `×${p}`}
            </button>
          ))
        ) : (
          <button onClick={() => onLog(1)} className="h-9 shrink-0 rounded-full border-2 border-line bg-surface px-3.5 text-[0.8rem] font-bold text-ink-soft hover:border-accent hover:text-accent">
            Estimer
          </button>
        )}
      </div>
    </li>
  );
}

function MacroInputs({ value, onChange }: { value: Macros; onChange: (m: Macros) => void }) {
  const fields: [keyof Macros, string][] = [
    ["kcal", "Kcal"],
    ["proteinG", "Prot. (g)"],
    ["carbsG", "Gluc. (g)"],
    ["fatG", "Lip. (g)"],
  ];
  return (
    <div className="grid grid-cols-4 gap-2">
      {fields.map(([k, label]) => (
        <label key={k} className="flex flex-col gap-0.5">
          <span className="text-[0.66rem] font-semibold uppercase tracking-wide text-ink-soft">{label}</span>
          <input
            type="number"
            inputMode="decimal"
            min={0}
            value={value[k] || ""}
            onChange={(e) => onChange({ ...value, [k]: Math.max(0, Math.round(Number(e.target.value) || 0)) })}
            className="w-full rounded-lg border border-line bg-surface px-2 py-1.5 text-[0.88rem] text-ink outline-none focus:border-accent"
          />
        </label>
      ))}
    </div>
  );
}

/** Saisie libre : un nom + ses calories, sans IA. Une fois noté, il
 * rejoint « Mes habitudes ». */
function ManualEntry({ onSave }: { onSave: (label: string, m: Macros) => Promise<void> }) {
  const [label, setLabel] = useState("");
  const [m, setM] = useState<Macros>({ kcal: 0, proteinG: 0, carbsG: 0, fatG: 0 });
  const [busy, setBusy] = useState(false);
  const ok = label.trim().length > 0 && m.kcal > 0;

  async function save() {
    if (!ok) return;
    setBusy(true);
    try {
      await onSave(label.trim(), m);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mt-3 flex flex-col gap-2.5 rounded-2xl bg-surface-2 p-3">
      <input
        value={label}
        onChange={(e) => setLabel(e.target.value)}
        placeholder="Ex. Yaourt nature"
        className="w-full rounded-lg border border-line bg-surface px-3 py-2 text-[0.9rem] text-ink outline-none focus:border-accent"
      />
      <MacroInputs value={m} onChange={setM} />
      <button
        disabled={!ok || busy}
        onClick={save}
        className="rounded-xl bg-herb py-2.5 text-[0.88rem] font-bold text-white transition active:scale-[.98] disabled:opacity-40"
      >
        Noter{m.kcal > 0 ? ` · ${m.kcal} kcal` : ""}
      </button>
    </div>
  );
}
