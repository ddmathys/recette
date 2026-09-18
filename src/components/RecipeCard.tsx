"use client";

import { getCategoryMeta } from "@/lib/categories";
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
  const cat = getCategoryMeta(recipe.cat);

  return (
    <button
      onClick={onOpen}
      className="group flex flex-col overflow-hidden rounded-2xl bg-surface text-left shadow-[0_1px_3px_rgba(43,42,38,.08)] transition-transform duration-150 hover:-translate-y-0.5 hover:shadow-[0_10px_20px_-10px_rgba(43,42,38,.3)] focus-visible:outline-2 focus-visible:outline-accent focus-visible:outline-offset-2"
    >
      <div
        className="relative flex h-20 items-center justify-center"
        style={{ backgroundColor: cat.color }}
      >
        {recipe.photoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={recipe.photoUrl} alt="" className="absolute inset-0 h-full w-full object-cover" />
        ) : (
          <CategoryIcon cat={recipe.cat} className="h-8 w-8 text-white opacity-95" />
        )}
        {recipe.ownerName && (
          <span
            title={`Créé par ${recipe.ownerName}`}
            className="absolute left-1.5 top-1.5 rounded-full bg-black/25 px-1.5 py-0.5 text-[0.62rem] font-bold text-white backdrop-blur-[2px]"
          >
            {recipe.ownerName}
          </span>
        )}
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
          className="absolute right-1.5 top-1.5 flex h-6.5 w-6.5 items-center justify-center rounded-full bg-black/25 text-white backdrop-blur-[2px]"
        >
          <svg viewBox="0 0 24 24" fill={isFav ? "currentColor" : "none"} stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="h-3.5 w-3.5">
            <path d="M12 20s-7-4.35-9.5-8.5C.8 8.1 2.4 5 5.6 5 7.6 5 9 6 12 8.5 15 6 16.4 5 18.4 5c3.2 0 4.8 3.1 3.1 6.5C19 15.65 12 20 12 20z" />
          </svg>
        </span>
      </div>
      <div className="flex flex-1 flex-col gap-1 px-2.5 pb-2.5 pt-2">
        <h3 className="text-[0.88rem] font-bold leading-tight text-ink">{recipe.name}</h3>
        <div className="mt-auto flex flex-wrap items-center gap-1.5 pt-1 text-[0.7rem] font-semibold text-ink-soft">
          <span className="inline-flex items-center gap-0.5">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} className="h-2.5 w-2.5">
              <circle cx="12" cy="12" r="9" />
              <path d="M12 7v5l3 2" />
            </svg>
            {recipe.time} min
          </span>
          <span>·</span>
          <span>{recipe.servings} pers.</span>
          {recipe.veg && (
            <span className="ml-auto inline-flex h-4 w-4 items-center justify-center rounded-full bg-herb text-white" title="Végétarien">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="h-2.5 w-2.5">
                <path d="M12 21V11" />
                <path d="M12 11C12 6 8 5 5 5c0 4 2 6 7 6z" />
                <path d="M12 14c0-4 4-5 7-5 0 4-2 6-7 5z" />
              </svg>
            </span>
          )}
        </div>
      </div>
    </button>
  );
}
