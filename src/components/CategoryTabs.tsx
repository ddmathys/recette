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
    <div className="overflow-x-auto pb-0.5">
      <div className="flex min-w-max gap-1.5">
        <Chip label="Toutes" selected={active === "all"} onClick={() => onChange("all")} />
        {CATEGORIES.map((c) => (
          <Chip
            key={c.key}
            label={c.label}
            selected={active === c.key}
            color={c.color}
            icon={<CategoryIcon cat={c.key} className="h-3.5 w-3.5" />}
            onClick={() => onChange(c.key)}
          />
        ))}
      </div>
    </div>
  );
}

function Chip({
  label,
  selected,
  color,
  icon,
  onClick,
}: {
  label: string;
  selected: boolean;
  color?: string;
  icon?: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      role="tab"
      aria-selected={selected}
      onClick={onClick}
      style={selected && color ? { backgroundColor: color, borderColor: color } : undefined}
      className={`flex items-center gap-1.5 rounded-full border-2 px-3.5 py-1.5 text-[0.8rem] font-semibold transition ${
        selected ? "text-white shadow-sm" : "border-line bg-surface text-ink-soft hover:text-ink"
      }`}
    >
      {icon && <span style={!selected && color ? { color } : undefined}>{icon}</span>}
      <span>{label}</span>
    </button>
  );
}
