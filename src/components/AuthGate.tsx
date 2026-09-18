"use client";

import { useState } from "react";
import { signIn, signUp, resetPassword } from "@/lib/useAuth";

type Mode = "signin" | "signup";

/**
 * Formulaire plein écran de connexion / inscription. La bibliothèque est
 * familiale et privée : n'importe qui avec le lien peut créer un compte
 * (pas de liste blanche en v1), mais il faut un compte pour lire ou écrire
 * quoi que ce soit — voir firestore.rules / storage.rules.
 */
export function AuthLanding() {
  const [mode, setMode] = useState<Mode>("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [resetSent, setResetSent] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      if (mode === "signin") await signIn(email.trim(), password);
      else await signUp(email.trim(), password, name.trim());
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erreur inconnue.");
    } finally {
      setBusy(false);
    }
  }

  async function handleReset() {
    if (!email.trim()) {
      setError("Indique ton e-mail pour recevoir le lien de réinitialisation.");
      return;
    }
    setError(null);
    setBusy(true);
    try {
      await resetPassword(email.trim());
      setResetSent(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erreur inconnue.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex min-h-full flex-1 items-center justify-center px-4 py-10">
      <div className="w-full max-w-[380px] rounded-2xl bg-surface p-6 shadow-[0_1px_3px_rgba(43,42,38,.08)]">
        <div className="mb-5 flex items-center gap-2">
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent text-accent-ink">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="h-4.5 w-4.5">
              <path d="M18 8h1a4 4 0 0 1 0 8h-1M6 8h12v9a3 3 0 0 1-3 3H9a3 3 0 0 1-3-3V8Z" />
              <path d="M6 1v3M10 1v3M14 1v3" />
            </svg>
          </div>
          <h1 className="text-[1.1rem] font-extrabold tracking-tight text-ink">Recettes du Tiroir</h1>
        </div>

        <div className="mb-4 flex rounded-full bg-surface-2 p-1 text-[0.85rem] font-semibold">
          <button
            onClick={() => {
              setMode("signin");
              setError(null);
              setResetSent(false);
            }}
            className={`flex-1 rounded-full py-1.5 transition ${mode === "signin" ? "bg-surface text-ink shadow-sm" : "text-ink-soft"}`}
          >
            Connexion
          </button>
          <button
            onClick={() => {
              setMode("signup");
              setError(null);
              setResetSent(false);
            }}
            className={`flex-1 rounded-full py-1.5 transition ${mode === "signup" ? "bg-surface text-ink shadow-sm" : "text-ink-soft"}`}
          >
            Créer un compte
          </button>
        </div>

        <form onSubmit={handleSubmit} className="flex flex-col gap-3">
          {mode === "signup" && (
            <div className="flex flex-col gap-1.5">
              <label className="text-[0.76rem] font-semibold uppercase tracking-wide text-ink-soft">Prénom</label>
              <input
                type="text"
                required
                autoComplete="given-name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Affiché sur tes recettes"
                className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
              />
            </div>
          )}
          <div className="flex flex-col gap-1.5">
            <label className="text-[0.76rem] font-semibold uppercase tracking-wide text-ink-soft">E-mail</label>
            <input
              type="email"
              required
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <label className="text-[0.76rem] font-semibold uppercase tracking-wide text-ink-soft">Mot de passe</label>
            <input
              type="password"
              required
              minLength={6}
              autoComplete={mode === "signin" ? "current-password" : "new-password"}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-lg border border-line bg-surface-2 px-2.5 py-2 text-[0.9rem] text-ink outline-none focus-visible:outline-2 focus-visible:outline-accent"
            />
          </div>

          {error && <p className="text-[0.83rem] text-accent">{error}</p>}
          {resetSent && <p className="text-[0.83rem] text-herb">E-mail de réinitialisation envoyé, vérifie ta boîte de réception.</p>}

          <button
            type="submit"
            disabled={busy}
            className="mt-1 rounded-xl bg-accent px-3.5 py-2.5 text-[0.9rem] font-bold text-accent-ink disabled:opacity-60"
          >
            {busy ? "…" : mode === "signin" ? "Se connecter" : "Créer mon compte"}
          </button>

          {mode === "signin" && (
            <button
              type="button"
              onClick={handleReset}
              className="self-center text-[0.8rem] font-semibold text-ink-soft hover:text-accent"
            >
              Mot de passe oublié ?
            </button>
          )}
        </form>
      </div>
    </div>
  );
}
