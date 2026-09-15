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

export function Toolbar({
  search,
  onSearch,
  veg,
  onVeg,
  fav,
  onFav,
  onSurprise,
  onAdd,
  addAvailable,
}: {
  search: string;
  onSearch: (v: string) => void;
  veg: boolean;
  onVeg: () => void;
  fav: boolean;
  onFav: () => void;
  onSurprise: () => void;
  onAdd: () => void;
  addAvailable: boolean;
}) {
  return (
    <div className="flex flex-wrap items-center gap-2.5">
      <label className="flex flex-1 basis-[260px] items-center gap-2 rounded-[10px] border border-line bg-surface px-3 py-2">
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

      <ToggleButton pressed={veg} onClick={onVeg} label="Végétarien" icon={
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4">
          <path d="M12 21V11" />
          <path d="M12 11C12 6 8 5 5 5c0 4 2 6 7 6z" />
          <path d="M12 14c0-4 4-5 7-5 0 4-2 6-7 5z" />
        </svg>
      } />

      <ToggleButton pressed={fav} onClick={onFav} label="Favoris" icon={
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4">
          <path d="M12 20s-7-4.35-9.5-8.5C.8 8.1 2.4 5 5.6 5 7.6 5 9 6 12 8.5 15 6 16.4 5 18.4 5c3.2 0 4.8 3.1 3.1 6.5C19 15.65 12 20 12 20z" />
        </svg>
      } />

      <button
        onClick={onSurprise}
        className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-xl border border-transparent bg-accent px-3.5 py-2.5 text-[0.85rem] font-medium text-accent-ink transition hover:brightness-105 active:scale-[.97]"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.9} strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4">
          <path d="M12 3v3M12 18v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M3 12h3M18 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1" />
          <circle cx="12" cy="12" r="3.2" />
        </svg>
        Surprends-moi
      </button>

      {addAvailable && (
        <button
          onClick={onAdd}
          className="inline-flex items-center gap-1.5 whitespace-nowrap rounded-xl border border-line bg-surface px-3.5 py-2.5 text-[0.85rem] font-medium text-ink transition hover:bg-surface-2 active:scale-[.97]"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-4 w-4">
            <path d="M12 5v14M5 12h14" />
          </svg>
          Ajouter une recette
        </button>
      )}
    </div>
  );
}

function ToggleButton({
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
