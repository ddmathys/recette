"use client";

import { useMemo, useState } from "react";

export function IngredientPicker({
  freq,
  selected,
  onToggle,
}: {
  freq: Record<string, number>;
  selected: Set<string>;
  onToggle: (name: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");

  const names = useMemo(
    () => Object.keys(freq).sort((a, b) => freq[b] - freq[a] || a.localeCompare(b)),
    [freq],
  );

  const list = useMemo(() => {
    const query = q.trim().toLowerCase();
    if (query) return names.filter((n) => n.toLowerCase().includes(query)).slice(0, 48);
    return names.slice(0, 28);
  }, [names, q]);

  return (
    <div className="mb-1 mt-2.5">
      <button
        onClick={() => setOpen((o) => !o)}
        className="inline-flex items-center gap-1.5 px-0.5 py-1 text-[0.82rem] font-semibold text-ink"
      >
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth={2}
          strokeLinecap="round"
          strokeLinejoin="round"
          className={`h-3.5 w-3.5 transition-transform ${open ? "rotate-90" : ""}`}
        >
          <path d="M9 6l6 6-6 6" />
        </svg>
        J&apos;ai déjà… (choisir des ingrédients)
      </button>

      {open && (
        <div className="pb-1 pt-2.5">
          <input
            type="search"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="chercher un ingrédient (ex: citron, poulet…)"
            className="mb-2.5 w-full max-w-80 rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.85rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
          />
          <div className="flex flex-wrap gap-1.5">
            {list.map((name) => {
              const isSel = selected.has(name);
              return (
                <button
                  key={name}
                  aria-pressed={isSel}
                  onClick={() => onToggle(name)}
                  className={`inline-flex items-center gap-1 rounded-full border px-2.5 py-1 text-[0.76rem] transition ${
                    isSel
                      ? "border-transparent bg-herb text-accent-ink"
                      : "border-line bg-surface text-ink-soft hover:text-ink"
                  }`}
                >
                  <span>{name}</span>
                  <span className={`font-mono text-[0.7rem] ${isSel ? "opacity-85" : "opacity-70"}`}>
                    {freq[name]}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      )}

      {selected.size > 0 && (
        <div className="mt-2 flex flex-wrap gap-1.5">
          {Array.from(selected).map((name) => (
            <span
              key={name}
              className="inline-flex items-center gap-1.5 rounded-full border border-transparent bg-accent px-2.5 py-1 text-[0.76rem] text-accent-ink"
            >
              {name}
              <button aria-label={`retirer ${name}`} onClick={() => onToggle(name)} className="text-[0.9rem] leading-none">
                &times;
              </button>
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
