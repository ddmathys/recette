"use client";

export const TIME_BUCKETS = [
  { key: "all", label: "Tous" },
  { key: "15", label: "≤ 15 min", max: 15 },
  { key: "30", label: "≤ 30 min", max: 30 },
  { key: "45", label: "≤ 45 min", max: 45 },
  { key: "60", label: "≤ 60 min", max: 60 },
  { key: "60+", label: "60 min +", min: 61 },
] as const;

export type TimeBucketKey = (typeof TIME_BUCKETS)[number]["key"];

/**
 * Compact top bar — always visible, on phone and desktop alike: search,
 * a "Filtres" button that opens the drawer on phone (hidden at md+, where
 * the drawer content renders inline instead). L'ajout passe par le
 * parcours "Ajouter un repas" de l'accueil, plus de bouton ici.
 */
export function Toolbar({
  search,
  onSearch,
  onOpenFilters,
  activeFilterCount,
}: {
  search: string;
  onSearch: (v: string) => void;
  onOpenFilters: () => void;
  activeFilterCount: number;
}) {
  return (
    <div className="flex items-center gap-2">
      <label className="flex flex-1 items-center gap-2 rounded-full border-2 border-transparent bg-surface px-4 py-2.5 shadow-[0_1px_3px_rgba(43,42,38,.08)] transition focus-within:border-accent">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" className="h-4 w-4 shrink-0 text-accent">
          <circle cx="11" cy="11" r="7" />
          <path d="m21 21-4.3-4.3" />
        </svg>
        <input
          type="search"
          value={search}
          onChange={(e) => onSearch(e.target.value)}
          placeholder="Chercher une recette, un ingrédient…"
          className="w-full bg-transparent text-[0.92rem] text-ink outline-none placeholder:text-ink-soft"
        />
      </label>

      <button
        onClick={onOpenFilters}
        className="relative inline-flex shrink-0 items-center gap-1.5 whitespace-nowrap rounded-full bg-accent-2 px-4 py-2.5 text-[0.85rem] font-bold text-accent-2-ink shadow-[0_2px_8px_-2px_rgba(23,162,184,.6)] transition active:scale-95 md:hidden"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4">
          <path d="M4 6h16M7 12h10M10 18h4" />
        </svg>
        Filtres
        {activeFilterCount > 0 && (
          <span className="flex h-4.5 min-w-4.5 items-center justify-center rounded-full bg-white px-1 text-[0.68rem] font-extrabold text-accent-2">
            {activeFilterCount}
          </span>
        )}
      </button>

    </div>
  );
}

export function ToggleButton({
  pressed,
  onClick,
  label,
  icon,
}: {
  pressed: boolean;
  onClick: () => void;
  label: string;
  icon: React.ReactNode;
}) {
  return (
    <button
      aria-pressed={pressed}
      onClick={onClick}
      className={`inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border-2 px-3.5 py-2 text-[0.83rem] font-semibold transition active:scale-95 ${
        pressed ? "border-herb bg-herb text-white" : "border-line bg-surface text-ink hover:border-herb"
      }`}
    >
      {icon}
      {label}
    </button>
  );
}

export function TimePills({
  active,
  onChange,
}: {
  active: TimeBucketKey;
  onChange: (key: TimeBucketKey) => void;
}) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {TIME_BUCKETS.map((b) => (
        <button
          key={b.key}
          aria-pressed={active === b.key}
          onClick={() => onChange(b.key)}
          className={`rounded-full border-2 px-3 py-1.5 text-[0.78rem] font-semibold transition ${
            active === b.key
              ? "border-accent bg-accent text-accent-ink"
              : "border-line bg-surface text-ink-soft hover:border-accent hover:text-accent"
          }`}
        >
          {b.label}
        </button>
      ))}
    </div>
  );
}
