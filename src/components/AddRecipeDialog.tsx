"use client";

import { useState } from "react";
import { CATEGORIES } from "@/lib/categories";
import { compressImageIfNeeded } from "@/lib/compressImage";
import { auth } from "@/lib/firebase";
import type { CategoryKey, Difficulty, Ingredient, RecipeDraft } from "@/lib/types";
import { addRecipe, uploadRecipePhoto } from "@/lib/useRecipes";

const DIFFICULTIES: Difficulty[] = ["Facile", "Moyen", "Avancé"];
const MAX_PHOTO_BYTES = 10 * 1024 * 1024;

type Stage = "intro" | "form";

export function AddRecipeDialog({ onClose }: { onClose: () => void }) {
  const [stage, setStage] = useState<Stage>("intro");
  const [text, setText] = useState("");
  const [name, setName] = useState("");
  const [link, setLink] = useState("");
  const [aiBusy, setAiBusy] = useState(false);
  const [aiError, setAiError] = useState<string | null>(null);
  const [suggestedPhoto, setSuggestedPhoto] = useState<string | null>(null);

  const [draft, setDraft] = useState<RecipeDraft>({
    name: "",
    cat: "viande",
    time: 30,
    diff: "Facile",
    servings: 4,
    veg: false,
    ingr: [{ name: "", qty: "" }],
    steps: [""],
  });
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
  const [photoBusy, setPhotoBusy] = useState(false);
  const [photoError, setPhotoError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  // Set once the recipe doc itself is safely created — from that point on,
  // a photo-upload failure is a warning to show, never a reason to let the
  // user "retry" and create a second recipe.
  const [savedRecipeName, setSavedRecipeName] = useState<string | null>(null);
  const [photoWarning, setPhotoWarning] = useState<string | null>(null);

  async function handlePhotoInput(f: File) {
    setPhotoError(null);
    setPhotoBusy(true);
    try {
      const toUse = await compressImageIfNeeded(f, MAX_PHOTO_BYTES);
      if (toUse.size > MAX_PHOTO_BYTES) {
        setPhotoError("Photo trop lourde (max 10 Mo), même après compression — essaie une image plus petite.");
        return;
      }
      setPhotoFile(toUse);
      setPhotoPreview(URL.createObjectURL(toUse));
      setSuggestedPhoto(null);
    } finally {
      setPhotoBusy(false);
    }
  }

  function openForm(fromDraft: RecipeDraft | null) {
    setDraft(
      fromDraft ?? {
        name: name.trim() || "",
        cat: "viande",
        time: 30,
        diff: "Facile",
        servings: 4,
        veg: false,
        ingr: [{ name: "", qty: "" }],
        steps: [""],
      },
    );
    setStage("form");
  }

  async function generateWithAi() {
    if (!text.trim() && !name.trim() && !link.trim()) {
      setAiError("Écris un nom de plat, colle un texte, ou donne un lien avant de générer.");
      return;
    }
    setAiBusy(true);
    setAiError(null);
    try {
      const idToken = await auth?.currentUser?.getIdToken();
      const res = await fetch("/api/parse-recipe", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
        },
        body: JSON.stringify({ text, name, link }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "La génération IA a échoué.");
      const d = data.draft as Partial<RecipeDraft>;
      const validCat = CATEGORIES.some((c) => c.key === d.cat) ? (d.cat as CategoryKey) : "viande";
      const validDiff = DIFFICULTIES.includes(d.diff as Difficulty) ? (d.diff as Difficulty) : "Facile";
      openForm({
        name: d.name || name.trim() || "",
        cat: validCat,
        time: Number(d.time) > 0 ? Number(d.time) : 30,
        diff: validDiff,
        servings: Number(d.servings) > 0 ? Number(d.servings) : 4,
        veg: Boolean(d.veg),
        ingr: Array.isArray(d.ingr) && d.ingr.length ? (d.ingr as Ingredient[]) : [{ name: "", qty: "" }],
        steps: Array.isArray(d.steps) && d.steps.length ? (d.steps as string[]) : [""],
      });
      if (data.ogImage) setSuggestedPhoto(data.ogImage);
    } catch (e) {
      setAiError(e instanceof Error ? e.message : "La génération IA a échoué. Tu peux remplir manuellement.");
    } finally {
      setAiBusy(false);
    }
  }

  function updateIngr(idx: number, field: keyof Ingredient, value: string) {
    setDraft((d) => ({
      ...d,
      ingr: d.ingr.map((row, i) => (i === idx ? { ...row, [field]: value } : row)),
    }));
  }
  function updateStep(idx: number, value: string) {
    setDraft((d) => ({ ...d, steps: d.steps.map((s, i) => (i === idx ? value : s)) }));
  }

  async function handleSave() {
    const name2 = draft.name.trim();
    const ingr = draft.ingr.map((i) => ({ name: i.name.trim(), qty: i.qty.trim() })).filter((i) => i.name);
    const steps = draft.steps.map((s) => s.trim()).filter(Boolean);
    if (!name2 || !ingr.length || !steps.length) {
      setSaveError("Nom, au moins un ingrédient et une étape sont nécessaires.");
      return;
    }
    setSaving(true);
    setSaveError(null);
    let newId: string;
    try {
      const finalDraft: RecipeDraft = { ...draft, name: name2, ingr, steps };
      // Toujours créer le document d'abord (sans la photo si on en a une à
      // uploader) : c'est la seule étape qui doit pouvoir être réessayée.
      newId = await addRecipe(finalDraft, link.trim() || null, photoFile ? null : suggestedPhoto);
    } catch {
      setSaveError("L'enregistrement a échoué, réessaie.");
      setSaving(false);
      return;
    }

    // La recette existe maintenant. Un échec d'upload photo à partir d'ici
    // n'est plus une raison de réessayer (ça créerait un doublon) — juste un
    // avertissement, et on ferme quand même.
    if (photoFile) {
      try {
        await uploadRecipePhoto(newId, photoFile);
      } catch {
        setSavedRecipeName(name2);
        setPhotoWarning("La recette a bien été enregistrée, mais l'envoi de la photo a échoué. Tu peux la rajouter depuis la fiche de la recette.");
        setSaving(false);
        return;
      }
    }
    setSaving(false);
    onClose();
  }

  return (
    <>
      <div className="fixed inset-0 z-42 bg-black/40" onClick={onClose} />
      <div className="fixed left-1/2 top-1/2 z-43 max-h-[90dvh] w-[min(640px,calc(100vw-32px))] -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-[20px] bg-surface shadow-[-4px_12px_40px_-10px_rgba(0,0,0,.4)]">
        <div className="sticky top-0 z-10 flex items-center justify-between gap-2.5 rounded-t-[20px] border-b border-line bg-surface px-5 py-4.5">
          <h2 className="text-[1.15rem] font-semibold">Ajouter une recette</h2>
          <button onClick={onClose} aria-label="Fermer" className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-2 text-ink">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-4 w-4">
              <path d="M6 6l12 12M18 6 6 18" />
            </svg>
          </button>
        </div>

        <div className="flex flex-col gap-3.5 px-5 pb-6.5 pt-4.5">
          {savedRecipeName ? (
            <>
              <p className="text-[0.9rem] text-ink">
                <strong>{savedRecipeName}</strong> a été ajoutée à la bibliothèque.
              </p>
              <p className="text-[0.83rem] text-gold">{photoWarning}</p>
              <button
                onClick={onClose}
                className="self-start rounded-xl bg-accent px-3.5 py-2.5 text-[0.85rem] font-medium text-accent-ink"
              >
                Fermer
              </button>
            </>
          ) : stage === "intro" && (
            <>
              <Field label="Ta recette, en texte libre">
                <textarea
                  rows={6}
                  value={text}
                  onChange={(e) => setText(e.target.value)}
                  placeholder="Colle ou tape ce que tu as : le nom du plat, les ingrédients, les étapes — dans l'ordre ou en vrac, l'IA s'occupe de ranger. Même juste un nom de plat suffit."
                  className="w-full resize-y rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
                />
              </Field>
              <div className="flex flex-wrap gap-3">
                <Field label="Nom du plat (si tu veux le préciser)" className="flex-1 basis-35">
                  <input
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="ex : Tarte aux poireaux"
                    className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
                  />
                </Field>
                <Field label="Lien source (optionnel)" className="flex-1 basis-35">
                  <input
                    type="url"
                    value={link}
                    onChange={(e) => setLink(e.target.value)}
                    placeholder="https://..."
                    className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
                  />
                </Field>
              </div>
              <p className="text-[0.76rem] text-ink-soft">
                Si tu donnes un lien, le serveur va essayer de lire la page pour en extraire la recette et une photo.
              </p>

              <div className="flex flex-wrap gap-2.5 pt-1">
                <button
                  onClick={generateWithAi}
                  disabled={aiBusy}
                  className="inline-flex items-center gap-1.5 rounded-xl bg-accent px-3.5 py-2.5 text-[0.85rem] font-medium text-accent-ink disabled:opacity-60"
                >
                  {aiBusy && <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-line border-t-accent-ink" />}
                  {aiBusy ? "DeepSeek réfléchit…" : "Générer avec l'IA (DeepSeek)"}
                </button>
                <button
                  onClick={() => openForm(null)}
                  className="rounded-xl border border-line bg-surface px-3.5 py-2.5 text-[0.85rem] font-medium text-ink hover:bg-surface-2"
                >
                  Remplir manuellement
                </button>
              </div>
              {aiError && <p className="text-[0.83rem] text-accent">{aiError}</p>}
            </>
          )}

          {!savedRecipeName && stage === "form" && (
            <form
              onSubmit={(e) => {
                e.preventDefault();
                handleSave();
              }}
              className="flex flex-col gap-3.5"
            >
              <Field label="Nom du plat">
                <input
                  required
                  value={draft.name}
                  onChange={(e) => setDraft((d) => ({ ...d, name: e.target.value }))}
                  className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
                />
              </Field>

              <div className="flex flex-wrap gap-3">
                <Field label="Catégorie" className="flex-1 basis-35">
                  <select
                    value={draft.cat}
                    onChange={(e) => setDraft((d) => ({ ...d, cat: e.target.value as CategoryKey }))}
                    className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
                  >
                    {CATEGORIES.map((c) => (
                      <option key={c.key} value={c.key}>
                        {c.label}
                      </option>
                    ))}
                  </select>
                </Field>
                <Field label="Temps (min)" className="flex-1 basis-35">
                  <input
                    type="number"
                    min={1}
                    max={600}
                    value={draft.time}
                    onChange={(e) => setDraft((d) => ({ ...d, time: Number(e.target.value) || 1 }))}
                    className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
                  />
                </Field>
              </div>

              <div className="flex flex-wrap gap-3">
                <Field label="Difficulté" className="flex-1 basis-35">
                  <select
                    value={draft.diff}
                    onChange={(e) => setDraft((d) => ({ ...d, diff: e.target.value as Difficulty }))}
                    className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
                  >
                    {DIFFICULTIES.map((d) => (
                      <option key={d} value={d}>
                        {d}
                      </option>
                    ))}
                  </select>
                </Field>
                <Field label="Personnes" className="flex-1 basis-35">
                  <input
                    type="number"
                    min={1}
                    max={20}
                    value={draft.servings}
                    onChange={(e) => setDraft((d) => ({ ...d, servings: Number(e.target.value) || 1 }))}
                    className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
                  />
                </Field>
              </div>

              <label className="flex items-center gap-2 text-[0.88rem]">
                <input
                  type="checkbox"
                  checked={draft.veg}
                  onChange={(e) => setDraft((d) => ({ ...d, veg: e.target.checked }))}
                />
                Recette végétarienne
              </label>

              <div>
                <p className="mb-2.5 text-[0.72rem] font-semibold uppercase tracking-wider text-ink-soft">Ingrédients</p>
                <div className="flex flex-col gap-2">
                  {draft.ingr.map((row, idx) => (
                    <div key={idx} className="flex items-center gap-2">
                      <input
                        placeholder="ingrédient"
                        value={row.name}
                        onChange={(e) => updateIngr(idx, "name", e.target.value)}
                        className="flex-2 rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
                      />
                      <input
                        placeholder="quantité"
                        value={row.qty}
                        onChange={(e) => updateIngr(idx, "qty", e.target.value)}
                        className="flex-1 rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
                      />
                      <RemoveButton
                        onClick={() => setDraft((d) => ({ ...d, ingr: d.ingr.filter((_, i) => i !== idx) }))}
                      />
                    </div>
                  ))}
                </div>
                <AddRowButton onClick={() => setDraft((d) => ({ ...d, ingr: [...d.ingr, { name: "", qty: "" }] }))}>
                  + ajouter un ingrédient
                </AddRowButton>
              </div>

              <div>
                <p className="mb-2.5 text-[0.72rem] font-semibold uppercase tracking-wider text-ink-soft">Étapes</p>
                <div className="flex flex-col gap-2">
                  {draft.steps.map((s, idx) => (
                    <div key={idx} className="flex items-start gap-2">
                      <span className="flex h-8.5 w-5.5 shrink-0 items-center justify-center font-mono text-[0.75rem] text-ink-soft">
                        {idx + 1}
                      </span>
                      <textarea
                        rows={1}
                        value={s}
                        onChange={(e) => updateStep(idx, e.target.value)}
                        placeholder="étape de préparation"
                        className="min-h-9.5 flex-1 rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-[0.86rem] text-ink outline-none"
                      />
                      <RemoveButton onClick={() => setDraft((d) => ({ ...d, steps: d.steps.filter((_, i) => i !== idx) }))} />
                    </div>
                  ))}
                </div>
                <AddRowButton onClick={() => setDraft((d) => ({ ...d, steps: [...d.steps, ""] }))}>
                  + ajouter une étape
                </AddRowButton>
              </div>

              <Field label="Photo (optionnel)">
                <div className="flex flex-wrap items-center gap-3">
                  {(photoPreview || suggestedPhoto) && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={photoPreview || suggestedPhoto || ""}
                      alt=""
                      className="h-16 w-16 rounded-[10px] border border-line object-cover"
                    />
                  )}
                  <label className="cursor-pointer rounded-xl border border-line bg-surface px-3.5 py-2 text-[0.85rem] text-ink hover:bg-surface-2">
                    {photoBusy ? "Compression…" : "Choisir une photo"}
                    <input
                      type="file"
                      accept="image/png,image/jpeg,image/webp,image/gif"
                      hidden
                      disabled={photoBusy}
                      onChange={(e) => {
                        const f = e.target.files?.[0];
                        if (!f) return;
                        handlePhotoInput(f);
                      }}
                    />
                  </label>
                  {suggestedPhoto && !photoFile && (
                    <span className="text-[0.76rem] text-ink-soft">Photo trouvée sur la page liée — tu peux la remplacer.</span>
                  )}
                </div>
                {photoError && <p className="mt-1.5 text-[0.76rem] text-accent">{photoError}</p>}
                <p className="mt-1.5 text-[0.76rem] text-ink-soft">Sans photo, une icône de catégorie sera utilisée par défaut.</p>
              </Field>

              {saveError && <p className="text-[0.83rem] text-accent">{saveError}</p>}
              <div className="flex flex-wrap gap-2.5 pt-1">
                <button
                  type="submit"
                  disabled={saving}
                  className="rounded-xl bg-accent px-3.5 py-2.5 text-[0.85rem] font-medium text-accent-ink disabled:opacity-60"
                >
                  {saving ? "Ajout en cours…" : "Ajouter à la bibliothèque"}
                </button>
                <button
                  type="button"
                  onClick={onClose}
                  className="rounded-xl border border-line bg-surface px-3.5 py-2.5 text-[0.85rem] font-medium text-ink hover:bg-surface-2"
                >
                  Annuler
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
    </>
  );
}

function Field({ label, className, children }: { label: string; className?: string; children: React.ReactNode }) {
  return (
    <div className={`flex flex-col gap-1.5 ${className ?? ""}`}>
      <label className="text-[0.76rem] font-semibold uppercase tracking-wide text-ink-soft">{label}</label>
      {children}
    </div>
  );
}

function RemoveButton({ onClick }: { onClick: () => void }) {
  return (
    <button type="button" onClick={onClick} aria-label="retirer" className="flex h-6.5 w-6.5 shrink-0 items-center justify-center rounded-md text-ink-soft hover:bg-surface-2 hover:text-accent">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-3.5 w-3.5">
        <path d="M6 6l12 12M18 6 6 18" />
      </svg>
    </button>
  );
}

function AddRowButton({ onClick, children }: { onClick: () => void; children: React.ReactNode }) {
  return (
    <button type="button" onClick={onClick} className="mt-2 self-start rounded-lg border border-dashed border-line px-3 py-1.5 text-[0.8rem] text-ink-soft hover:border-accent hover:text-accent">
      {children}
    </button>
  );
}
