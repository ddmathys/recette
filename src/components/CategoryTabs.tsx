"use client";

import { CATEGORIES } from "@/lib/categories";
import { CategoryIcon } from "./CategoryIcon";
import type { CategoryKey } from "@/lib/types";

export function CategoryTabs({
  active,
  onChange,
}: {
  active: CategoryKey | "all";
  onChange: (cat: CategoryKey | "all") => void;
}) {
  return (
    <div className="mt-3.5 overflow-x-auto pb-0.5">
      <div className="flex min-w-max gap-1.5">
        <Tab label="Toutes" selected={active === "all"} onClick={() => onChange("all")} />
        {CATEGORIES.map((c) => (
          <Tab
            key={c.key}
            label={c.label}
            selected={active === c.key}
            accent={c.color}
            icon={<CategoryIcon cat={c.key} className="h-3.5 w-3.5" />}
            onClick={() => onChange(c.key)}
          />
        ))}
      </div>
    </div>
  );
}

function Tab({
  label,
  selected,
  accent,
  icon,
  onClick,
}: {
  label: string;
  selected: boolean;
  accent?: string;
  icon?: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      role="tab"
      aria-selected={selected}
      onClick={onClick}
      style={accent ? ({ "--tab-accent": accent } as React.CSSProperties) : undefined}
      className={`flex items-center gap-1.5 rounded-t-[11px] border border-b-0 border-line px-3.5 pb-[9px] pt-2 text-[0.82rem] transition-all ${
        selected
          ? "translate-y-0 bg-surface font-semibold text-ink shadow-[0_1px_2px_rgba(41,39,31,.06),0_8px_20px_-12px_rgba(41,39,31,.25),inset_0_-3px_0_var(--tab-accent,var(--color-accent))]"
          : "translate-y-[3px] bg-surface-2 font-medium text-ink-soft hover:text-ink"
      }`}
    >
      {icon && (
        <span style={accent ? { color: accent, opacity: selected ? 1 : 0.6 } : undefined}>{icon}</span>
      )}
      <span>{label}</span>
    </button>
  );
}
