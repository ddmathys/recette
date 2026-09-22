"use client";

import { useEffect, useRef, useState } from "react";
import { getCategoryMeta } from "@/lib/categories";
import { CategoryIcon } from "./CategoryIcon";
import { compressImageIfNeeded } from "@/lib/compressImage";
import type { Recipe } from "@/lib/types";

const MAX_PHOTO_BYTES = 10 * 1024 * 1024;

/** Only accept http(s) URLs as a CSS `background-image`, and reject anything
 * containing a quote — `photoUrl` can come from Firestore (any account can
 * write it) or from a third-party site's og:image, so it must never be
 * trusted enough to interpolate raw into `url('...')`. */
function safeBackgroundUrl(url: string | null | undefined): string | undefined {
  if (!url) return undefined;
  if (!/^https:\/\//i.test(url)) return undefined;
  if (/['"()\\]/.test(url)) return undefined;
  return url;
}

export function RecipeDetail({
  recipe,
  isFav,
  onToggleFav,
  onClose,
  onSaveNotes,
  onPhotoFile,
  onDelete,
  onAddEatenDate,
  onRemoveEatenDate,
  onEdit,
  onLogMeal,
  readOnly,
}: {
  recipe: Recipe;
  isFav: boolean;
  onToggleFav: () => void;
  onClose: () => void;
  onSaveNotes: (text: string) => void;
  onPhotoFile: (file: File) => Promise<unknown>;
  onDelete: () => Promise<unknown>;
  onAddEatenDate: (date: string) => Promise<unknown>;
  onRemoveEatenDate: (date: string) => Promise<unknown>;
  onEdit: () => void;
  onLogMeal: () => void;
  readOnly: boolean;
}) {
  const cat = getCategoryMeta(recipe.cat);
  const bgUrl = safeBackgroundUrl(recipe.photoUrl);
  // Keyed by recipe.id in the parent, so this instance remounts (and re-runs
  // this initializer) whenever the open recipe changes.
  const [notes, setNotes] = useState(recipe.notes ?? "");
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const [photoState, setPhotoState] = useState<"idle" | "uploading" | "error">("idle");
  const [photoError, setPhotoError] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [newDate, setNewDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [addingDate, setAddingDate] = useState(false);
  const eatenDates = [...(recipe.eatenDates ?? [])].sort().reverse();

  async function handleAddDate() {
    if (!newDate) return;
    setAddingDate(true);
    try {
      await onAddEatenDate(newDate);
    } finally {
      setAddingDate(false);
    }
  }

  async function handleDelete() {
    if (!confirmDelete) {
      setConfirmDelete(true);
      return;
    }
    setDeleting(true);
    try {
      await onDelete();
    } catch {
      setDeleting(false);
      setConfirmDelete(false);
    }
  }

  async function handlePhotoFile(file: File) {
    setPhotoError(null);
    if (!file.type.startsWith("image/")) {
      setPhotoState("error");
      setPhotoError("Ce fichier n'est pas une image.");
      return;
    }
    setPhotoState("uploading");
    try {
      const toUpload = await compressImageIfNeeded(file, MAX_PHOTO_BYTES);
      if (toUpload.size > MAX_PHOTO_BYTES) {
        setPhotoState("error");
        setPhotoError("Photo trop lourde (max 10 Mo), même après compression — essaie une image plus petite.");
        return;
      }
      await onPhotoFile(toUpload);
      setPhotoState("idle");
    } catch (e) {
      setPhotoState("error");
      setPhotoError(e instanceof Error ? e.message : "L'envoi de la photo a échoué, réessaie.");
    }
  }

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
          className="relative flex h-[110px] shrink-0 items-end bg-cover bg-center p-4 text-white"
          style={{
            backgroundColor: cat.color,
            backgroundImage: bgUrl ? `url('${bgUrl}')` : undefined,
          }}
        >
          {bgUrl && (
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
          {!bgUrl && (
            <CategoryIcon cat={recipe.cat} className="absolute right-4 top-4 z-10 h-9 w-9 opacity-85" />
          )}
          <div className="relative z-10">
            <p className="mb-0.5 flex items-center gap-1.5 text-[0.72rem] font-semibold uppercase tracking-wide opacity-90">
              {cat.label}
              {recipe.ownerName && (
                <span className="rounded-full bg-black/25 px-1.5 py-0.5 text-[0.65rem] normal-case tracking-normal">
                  {recipe.ownerName}
                </span>
              )}
            </p>
            <h2 className="text-[1.2rem] font-extrabold text-white">{recipe.name}</h2>
          </div>
        </div>

        <div className="flex flex-col gap-5 px-5 pb-8 pt-4.5">
          <div className="flex flex-col items-end gap-1.5">
            <div className="flex justify-end gap-2.5">
              {!readOnly && (
                <label
                  className={`inline-flex items-center gap-1.5 rounded-full border border-line bg-surface-2 px-3.5 py-1.5 text-[0.78rem] text-ink ${
                    photoState === "uploading" ? "cursor-wait opacity-70" : "cursor-pointer"
                  }`}
                >
                  {photoState === "uploading" ? (
                    <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-line border-t-accent" />
                  ) : (
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="h-3.5 w-3.5">
                      <rect x="3" y="5" width="18" height="14" rx="2" />
                      <circle cx="12" cy="12" r="3.5" />
                      <path d="M8 5l1.5-2h5L16 5" />
                    </svg>
                  )}
                  {photoState === "uploading" ? "Envoi…" : recipe.photoUrl ? "Changer la photo" : "Ajouter une photo"}
                  <input
                    ref={fileRef}
                    type="file"
                    accept="image/png,image/jpeg,image/webp,image/gif"
                    hidden
                    disabled={photoState === "uploading"}
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      if (f) handlePhotoFile(f);
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
            {photoState === "error" && photoError && (
              <p className="text-[0.78rem] text-accent">{photoError}</p>
            )}
          </div>

          <div className="flex flex-wrap items-center justify-between gap-3.5">
            <div className="flex flex-wrap gap-3.5">
              <Badge value={`${recipe.time} min`} label="Préparation" />
              <Badge value={String(recipe.servings)} label="Personnes" />
              <Badge value={recipe.diff} label="Difficulté" />
              {recipe.nutrition && <Badge value={`${recipe.nutrition.kcal} kcal`} label="Par portion" />}
            </div>
            {!readOnly && (
              <button
                onClick={onEdit}
                className="inline-flex items-center gap-1.5 rounded-full border border-line bg-surface-2 px-3.5 py-1.5 text-[0.78rem] font-semibold text-ink hover:border-accent hover:text-accent"
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="h-3.5 w-3.5">
                  <path d="M12 20h9" />
                  <path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z" />
                </svg>
                Modifier
              </button>
            )}
          </div>

          {recipe.nutrition && (
            <div className="flex flex-wrap gap-3.5 rounded-xl border border-line bg-surface-2 px-3.5 py-2.5">
              <Badge value={`${recipe.nutrition.gramsPerServing} g`} label="Poids" />
              <Badge value={`${recipe.nutrition.proteinG} g`} label="Protéines" />
              <Badge value={`${recipe.nutrition.carbsG} g`} label="Glucides" />
              <Badge value={`${recipe.nutrition.fatG} g`} label="Lipides" />
            </div>
          )}

          {!readOnly && (
            <button
              onClick={onLogMeal}
              className="inline-flex items-center justify-center gap-1.5 self-start rounded-full bg-accent px-3.5 py-2 text-[0.82rem] font-bold text-accent-ink"
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="h-3.5 w-3.5">
                <path d="M12 5v14M5 12h14" />
              </svg>
              Manger ce repas
            </button>
          )}

          {recipe.note && (
            <p className="inline-block rounded-lg bg-gold/15 px-2.5 py-1.5 text-[0.8rem] text-gold">{recipe.note}</p>
          )}

          <div>
            <SectionLabel>Mangé le…</SectionLabel>
            {!readOnly && (
              <div className="mb-2.5 flex items-center gap-2">
                <input
                  type="date"
                  value={newDate}
                  onChange={(e) => setNewDate(e.target.value)}
                  className="rounded-[10px] border border-line bg-surface-2 px-2.5 py-1.5 text-[0.85rem] text-ink outline-none"
                />
                <button
                  onClick={handleAddDate}
                  disabled={addingDate || !newDate}
                  className="inline-flex items-center gap-1 rounded-full bg-accent px-3 py-1.5 text-[0.8rem] font-bold text-accent-ink disabled:opacity-60"
                >
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round" className="h-3.5 w-3.5">
                    <path d="M12 5v14M5 12h14" />
                  </svg>
                  Ajouter
                </button>
              </div>
            )}
            {eatenDates.length > 0 ? (
              <div className="flex flex-wrap gap-1.5">
                {eatenDates.map((d) => (
                  <span
                    key={d}
                    className="inline-flex items-center gap-1.5 rounded-full border border-line bg-surface-2 px-2.5 py-1 text-[0.78rem] text-ink"
                  >
                    {formatDate(d)}
                    {!readOnly && (
                      <button
                        aria-label={`retirer le ${formatDate(d)}`}
                        onClick={() => onRemoveEatenDate(d)}
                        className="text-ink-soft hover:text-accent"
                      >
                        &times;
                      </button>
                    )}
                  </span>
                ))}
              </div>
            ) : (
              <p className="text-[0.78rem] text-ink-soft">Pas encore de date enregistrée.</p>
            )}
          </div>

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

          {!readOnly && (
            <button
              onClick={handleDelete}
              onBlur={() => setConfirmDelete(false)}
              disabled={deleting}
              className={`inline-flex items-center justify-center gap-1.5 rounded-full border-2 px-3.5 py-2 text-[0.82rem] font-bold transition active:scale-95 disabled:opacity-60 ${
                confirmDelete
                  ? "border-transparent bg-accent text-accent-ink"
                  : "border-line bg-surface text-ink-soft hover:border-accent hover:text-accent"
              }`}
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="h-3.5 w-3.5">
                <path d="M4 7h16M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2m-9 0 1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12" />
              </svg>
              {deleting ? "Suppression…" : confirmDelete ? "Confirmer la suppression ?" : "Supprimer la recette"}
            </button>
          )}
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

function formatDate(iso: string): string {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y, m - 1, d).toLocaleDateString("fr-CH", { day: "numeric", month: "short", year: "numeric" });
}
