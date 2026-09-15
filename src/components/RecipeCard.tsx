"use client";

import { CATEGORY_BY_KEY } from "@/lib/categories";
import { CategoryIcon } from "./CategoryIcon";
import type { Recipe } from "@/lib/types";

export function RecipeCard({
  recipe,
  isFav,
  onOpen,
  onToggleFav,
}: {
  recipe: Recipe;
  isFav: boolean;
  onOpen: () => void;
  onToggleFav: () => void;
}) {
  const cat = CATEGORY_BY_KEY[recipe.cat];

  return (
    <button
      onClick={onOpen}
      className="group flex flex-col overflow-hidden rounded-[18px] border border-line bg-surface text-left shadow-[0_1px_2px_rgba(41,39,31,.06),0_8px_20px_-12px_rgba(41,39,31,.25)] transition-transform duration-150 hover:-translate-y-1 hover:rotate-[-0.6deg] hover:shadow-[0_14px_26px_-14px_rgba(41,39,31,.35)] focus-visible:outline-2 focus-visible:outline-accent focus-visible:outline-offset-2"
    >
      <div
        className="relative flex h-31 items-center justify-center text-[#FBF8EF]"
        style={{
          backgroundColor: cat.color,
          backgroundImage:
            "radial-gradient(circle at 16px 16px, rgba(255,255,255,.16) 2.2px, transparent 2.2px)",
          backgroundSize: "22px 22px",
          height: "124px",
        }}
      >
        {recipe.photoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={recipe.photoUrl} alt="" className="absolute inset-0 h-full w-full object-cover" />
        ) : (
          <CategoryIcon cat={recipe.cat} className="h-11 w-11 opacity-95" />
        )}
        <span
          aria-hidden
          className="absolute left-1/2 top-[9px] h-[13px] w-[13px] -translate-x-1/2 rounded-full bg-surface shadow-[inset_0_1px_2px_rgba(0,0,0,.3)]"
        />
        <span
          role="button"
          tabIndex={0}
          onClick={(e) => {
            e.stopPropagation();
            onToggleFav();
          }}
          onKeyDown={(e) => {
            if (e.key === "Enter" || e.key === " ") {
              e.preventDefault();
              e.stopPropagation();
              onToggleFav();
            }
          }}
          aria-pressed={isFav}
          aria-label="Favori"
          className="absolute right-2 top-2 flex h-7 w-7 items-center justify-center rounded-full bg-black/25 text-[#FBF8EF] backdrop-blur-[2px]"
        >
          <svg viewBox="0 0 24 24" fill={isFav ? "currentColor" : "none"} stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="h-3.5 w-3.5">
            <path d="M12 20s-7-4.35-9.5-8.5C.8 8.1 2.4 5 5.6 5 7.6 5 9 6 12 8.5 15 6 16.4 5 18.4 5c3.2 0 4.8 3.1 3.1 6.5C19 15.65 12 20 12 20z" />
          </svg>
        </span>
      </div>
      <div className="flex flex-1 flex-col gap-1.5 px-3.5 pb-3.5 pt-3">
        <h3 className="text-[1.02rem] font-semibold leading-tight">{recipe.name}</h3>
        <div className="mt-auto flex flex-wrap gap-2.5 pt-1.5 font-mono text-[0.72rem] text-ink-soft">
          <span className="inline-flex items-center gap-1">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="h-2.5 w-2.5">
              <circle cx="12" cy="12" r="9" />
              <path d="M12 7v5l3 2" />
            </svg>
            {recipe.time} min
          </span>
          <span>{recipe.diff}</span>
          <span>{recipe.servings} pers.</span>
          {recipe.veg && (
            <span className="inline-flex items-center gap-1">
              <span className="inline-block h-1.5 w-1.5 rounded-full bg-herb" />
              végé
            </span>
          )}
        </div>
      </div>
    </button>
  );
}
