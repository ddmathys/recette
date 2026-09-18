"use client";

import { useState } from "react";
import { joinHousehold, leaveHousehold } from "@/lib/useHousehold";
import type { Household, UserProfile } from "@/lib/types";

/**
 * "Activer le partage" — rejoindre la bibliothèque d'un autre compte (ou
 * revenir à la sienne). Voir src/lib/useHousehold.ts pour le modèle de
 * données (households/{ownerId}.members, users/{uid}.householdId).
 */
export function ShareSettings({
  uid,
  profile,
  household,
  onClose,
}: {
  uid: string;
  profile: UserProfile;
  household: Household | null;
  onClose: () => void;
}) {
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isOwnHousehold = profile.householdId === uid;

  async function handleJoin(e: React.FormEvent) {
    e.preventDefault();
    if (!email.trim()) return;
    setBusy(true);
    setError(null);
    try {
      await joinHousehold(uid, email.trim());
      setEmail("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erreur inconnue.");
    } finally {
      setBusy(false);
    }
  }

  async function handleLeave() {
    setBusy(true);
    setError(null);
    try {
      await leaveHousehold(uid, profile.householdId);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erreur inconnue.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className="fixed inset-0 z-42 bg-black/40" onClick={onClose} />
      <div className="fixed left-1/2 top-1/2 z-43 w-[min(440px,calc(100vw-32px))] -translate-x-1/2 -translate-y-1/2 rounded-[20px] bg-surface shadow-[-4px_12px_40px_-10px_rgba(0,0,0,.4)]">
        <div className="flex items-center justify-between gap-2.5 border-b border-line px-5 py-4.5">
          <h2 className="text-[1.1rem] font-semibold">Partage</h2>
          <button onClick={onClose} aria-label="Fermer" className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-2 text-ink">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-4 w-4">
              <path d="M6 6l12 12M18 6 6 18" />
            </svg>
          </button>
        </div>

        <div className="flex flex-col gap-4 px-5 py-5">
          {isOwnHousehold ? (
            <>
              <p className="text-[0.88rem] text-ink">
                Tu vois <strong>ta propre bibliothèque</strong>.
                {household && household.members.length > 1 && (
                  <> Elle est aussi partagée avec {household.members.length - 1} autre compte{household.members.length - 1 > 1 ? "s" : ""}.</>
                )}
              </p>
              <form onSubmit={handleJoin} className="flex flex-col gap-2">
                <label className="text-[0.76rem] font-semibold uppercase tracking-wide text-ink-soft">
                  Rejoindre la bibliothèque de quelqu&apos;un
                </label>
                <div className="flex gap-2">
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="e-mail de la personne"
                    className="flex-1 rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
                  />
                  <button
                    type="submit"
                    disabled={busy}
                    className="shrink-0 rounded-lg bg-accent px-3.5 py-2 text-[0.85rem] font-semibold text-accent-ink disabled:opacity-60"
                  >
                    Rejoindre
                  </button>
                </div>
                <p className="text-[0.76rem] text-ink-soft">
                  Tu verras et pourras modifier ses recettes (et elle les tiennes), avec une pastille qui indique qui a créé quoi.
                </p>
              </form>
            </>
          ) : (
            <>
              <p className="text-[0.88rem] text-ink">
                Tu vois la bibliothèque de <strong>{household?.ownerEmail ?? "…"}</strong>.
              </p>
              <button
                onClick={handleLeave}
                disabled={busy}
                className="self-start rounded-lg border border-line bg-surface px-3.5 py-2 text-[0.85rem] font-semibold text-ink hover:border-accent hover:text-accent disabled:opacity-60"
              >
                Revenir à ma bibliothèque
              </button>
            </>
          )}
          {error && <p className="text-[0.83rem] text-accent">{error}</p>}
        </div>
      </div>
    </>
  );
}
