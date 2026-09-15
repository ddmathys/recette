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
 * the drawer content renders inline instead), and the add-recipe action.
 */
export function Toolbar({
  search,
  onSearch,
  onOpenFilters,
  activeFilterCount,
  onAdd,
  addAvailable,
}: {
  search: string;
  onSearch: (v: string) => void;
  onOpenFilters: () => void;
  activeFilterCount: number;
  onAdd: () => void;
  addAvailable: boolean;
}) {
  return (
    <div className="flex flex-wrap items-center gap-2.5">
      <label className="flex flex-1 basis-[220px] items-center gap-2 rounded-[10px] border border-line bg-surface px-3 py-2">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-4 w-4 shrink-0 text-ink-soft">
          <circle cx="11" cy="11" r="7" />
          <path d="m21 21-4.3-4.3" />
        </svg>
        <input
          type="search"
          value={search}
          onChange={(e) => onSearch(e.target.value)}
          placeholder="Chercher une recette, un plat…"
          className="w-full bg-transparent text-[0.92rem] text-ink outline-none placeholder:text-ink-soft"
        />
      </label>

      <button
        onClick={onOpenFilters}
        className="relative inline-flex items-center gap-1.5 whitespace-nowrap rounded-xl border border-line bg-surface px-3.5 py-2.5 text-[0.85rem] font-medium text-ink transition hover:bg-surface-2 active:scale-[.97] md:hidden"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4">
          <path d="M4 6h16M7 12h10M10 18h4" />
        </svg>
        Filtres
        {activeFilterCount > 0 && (
          <span className="ml-0.5 flex h-4.5 min-w-4.5 items-center justify-center rounded-full bg-accent px-1 font-mono text-[0.68rem] text-accent-ink">
            {activeFilterCount}
          </span>
        )}
      </button>

      {addAvailable && (
        <button
          onClick={onAdd}
          className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-xl border border-line bg-surface px-3.5 py-2.5 text-[0.85rem] font-medium text-ink transition hover:bg-surface-2 active:scale-[.97]"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-4 w-4">
            <path d="M12 5v14M5 12h14" />
          </svg>
          <span className="hidden sm:inline">Ajouter une recette</span>
          <span className="sm:hidden">Ajouter</span>
        </button>
      )}
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
      className={`inline-flex items-center gap-1.5 whitespace-nowrap rounded-xl border px-3.5 py-2.5 text-[0.85rem] font-medium transition active:scale-[.97] ${
        pressed ? "border-transparent bg-herb text-accent-ink" : "border-line bg-surface text-ink hover:bg-surface-2"
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
          className={`rounded-full border px-3 py-1.5 font-mono text-[0.78rem] font-medium transition ${
            active === b.key
              ? "border-transparent bg-accent text-accent-ink"
              : "border-line bg-surface text-ink-soft hover:text-ink"
          }`}
        >
          {b.label}
        </button>
      ))}
    </div>
  );
}
