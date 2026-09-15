"use client";

import { useEffect, useRef, useState } from "react";
import { CATEGORY_BY_KEY } from "@/lib/categories";
import { CategoryIcon } from "./CategoryIcon";
import type { Recipe } from "@/lib/types";

export function RecipeDetail({
  recipe,
  isFav,
  onToggleFav,
  onClose,
  onSaveNotes,
  onPhotoFile,
  readOnly,
}: {
  recipe: Recipe;
  isFav: boolean;
  onToggleFav: () => void;
  onClose: () => void;
  onSaveNotes: (text: string) => void;
  onPhotoFile: (file: File) => void;
  readOnly: boolean;
}) {
  const cat = CATEGORY_BY_KEY[recipe.cat];
  // Keyed by recipe.id in the parent, so this instance remounts (and re-runs
  // this initializer) whenever the open recipe changes.
  const [notes, setNotes] = useState(recipe.notes ?? "");
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [onClose]);

  function handleNotesChange(v: string) {
    setNotes(v);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => onSaveNotes(v), 900);
  }

  return (
    <>
      <div className="fixed inset-0 z-40 bg-black/40" onClick={onClose} />
      <aside className="fixed right-0 top-0 z-41 flex h-full w-full max-w-[440px] flex-col overflow-y-auto bg-surface shadow-[-12px_0_30px_-10px_rgba(0,0,0,.35)]">
        <div
          className="relative flex h-[150px] shrink-0 items-end bg-cover bg-center p-4 text-[#FBF8EF]"
          style={{
            backgroundColor: cat.color,
            backgroundImage: recipe.photoUrl ? `url('${recipe.photoUrl}')` : undefined,
          }}
        >
          {recipe.photoUrl && (
            <div className="absolute inset-0 bg-gradient-to-t from-black/55 via-transparent to-transparent" />
          )}
          <button
            onClick={onClose}
            aria-label="Fermer"
            className="absolute left-3.5 top-3.5 z-10 flex h-8 w-8 items-center justify-center rounded-full bg-black/30"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-4 w-4">
              <path d="M6 6l12 12M18 6 6 18" />
            </svg>
          </button>
          {!recipe.photoUrl && (
            <CategoryIcon cat={recipe.cat} className="absolute right-4 top-4 z-10 h-9 w-9 opacity-85" />
          )}
          <div className="relative z-10">
            <p className="mb-1 text-[0.75rem] uppercase tracking-wide opacity-85">{cat.label}</p>
            <h2 className="text-[1.4rem] font-semibold text-[#FBF8EF]">{recipe.name}</h2>
          </div>
        </div>

        <div className="flex flex-col gap-5 px-5 pb-8 pt-4.5">
          <div className="flex justify-end gap-2.5">
            {!readOnly && (
              <label className="inline-flex cursor-pointer items-center gap-1.5 rounded-full border border-line bg-surface-2 px-3.5 py-1.5 text-[0.78rem] text-ink">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="h-3.5 w-3.5">
                  <rect x="3" y="5" width="18" height="14" rx="2" />
                  <circle cx="12" cy="12" r="3.5" />
                  <path d="M8 5l1.5-2h5L16 5" />
                </svg>
                {recipe.photoUrl ? "Changer la photo" : "Ajouter une photo"}
                <input
                  ref={fileRef}
                  type="file"
                  accept="image/png,image/jpeg,image/webp,image/gif"
                  hidden
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (f) onPhotoFile(f);
                    e.target.value = "";
                  }}
                />
              </label>
            )}
            <button
              aria-pressed={isFav}
              onClick={onToggleFav}
              className={`inline-flex items-center gap-1.5 rounded-full border px-3.5 py-1.5 text-[0.78rem] ${
                isFav ? "border-transparent bg-accent text-accent-ink" : "border-line bg-surface-2 text-ink"
              }`}
            >
              <svg viewBox="0 0 24 24" fill={isFav ? "currentColor" : "none"} stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="h-3.5 w-3.5">
                <path d="M12 20s-7-4.35-9.5-8.5C.8 8.1 2.4 5 5.6 5 7.6 5 9 6 12 8.5 15 6 16.4 5 18.4 5c3.2 0 4.8 3.1 3.1 6.5C19 15.65 12 20 12 20z" />
              </svg>
              {isFav ? "Dans vos favoris" : "Ajouter aux favoris"}
            </button>
          </div>

          <div className="flex flex-wrap gap-3.5">
            <Badge value={`${recipe.time} min`} label="Préparation" />
            <Badge value={String(recipe.servings)} label="Personnes" />
            <Badge value={recipe.diff} label="Difficulté" />
          </div>

          {recipe.note && (
            <p className="inline-block rounded-lg bg-gold/15 px-2.5 py-1.5 text-[0.8rem] text-gold">{recipe.note}</p>
          )}

          <div>
            <SectionLabel>Ingrédients</SectionLabel>
            <ul className="flex flex-col">
              {recipe.ingr.map((i, idx) => (
                <li key={idx} className="flex items-center justify-between gap-2.5 border-b border-dashed border-line py-1.5 text-[0.88rem] last:border-b-0">
                  <span>{i.name}</span>
                  <span className="whitespace-nowrap font-mono text-[0.8rem] text-ink-soft">{i.qty}</span>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <SectionLabel>Préparation</SectionLabel>
            <ol className="flex flex-col gap-3">
              {recipe.steps.map((s, idx) => (
                <li key={idx} className="flex gap-3 text-[0.9rem] leading-relaxed">
                  <span className="flex h-5.5 w-5.5 shrink-0 items-center justify-center rounded-full border border-line bg-surface-2 font-mono text-[0.72rem] text-ink-soft">
                    {idx + 1}
                  </span>
                  {s}
                </li>
              ))}
            </ol>
          </div>

          <div>
            <SectionLabel>Mes notes</SectionLabel>
            <textarea
              rows={3}
              value={notes}
              disabled={readOnly}
              onChange={(e) => handleNotesChange(e.target.value)}
              placeholder="ex : mettre moins de sel, doubler les quantités la prochaine fois…"
              className="mb-1.5 w-full rounded-[10px] border border-line bg-surface-2 px-2.5 py-2 text-[0.88rem] text-ink outline-none placeholder:text-ink-soft disabled:cursor-not-allowed disabled:opacity-55"
            />
            <p className="text-[0.76rem] text-ink-soft">
              {readOnly
                ? "L'enregistrement des notes n'est pas disponible (Firebase non configuré)."
                : "Notes visibles par toute personne qui a accès à cette bibliothèque."}
            </p>
          </div>
        </div>
      </aside>
    </>
  );
}

function Badge({ value, label }: { value: string; label: string }) {
  return (
    <div className="flex flex-col gap-0.5 font-mono">
      <span className="text-[0.95rem] font-medium text-ink">{value}</span>
      <span className="text-[0.66rem] uppercase tracking-wide text-ink-soft">{label}</span>
    </div>
  );
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return <p className="mb-2.5 text-[0.72rem] font-semibold uppercase tracking-wider text-ink-soft">{children}</p>;
}
