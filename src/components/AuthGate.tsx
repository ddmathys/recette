"use client";

import { useState } from "react";
import { signIn, signUp, resetPassword, signInWithGoogle } from "@/lib/useAuth";

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

  async function handleGoogle() {
    setError(null);
    setBusy(true);
    try {
      await signInWithGoogle();
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
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/logo.svg" alt="" className="h-9 w-9 shrink-0 drop-shadow-sm" />
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

        <button
          type="button"
          onClick={handleGoogle}
          disabled={busy}
          className="mb-4 flex w-full items-center justify-center gap-2.5 rounded-xl border border-line bg-surface px-3.5 py-2.5 text-[0.9rem] font-bold text-ink hover:bg-surface-2 disabled:opacity-60"
        >
          <svg viewBox="0 0 48 48" className="h-[18px] w-[18px]" aria-hidden="true">
            <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z" />
            <path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z" />
            <path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-8l-6.5 5C9.5 39.6 16.2 44 24 44z" />
            <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z" />
          </svg>
          Continuer avec Google
        </button>

        <div className="mb-4 flex items-center gap-3 text-[0.75rem] font-semibold uppercase tracking-wide text-ink-soft">
          <span className="h-px flex-1 bg-line" />
          ou
          <span className="h-px flex-1 bg-line" />
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
          {resetSent && (
            <p className="text-[0.83rem] text-herb">
              Si un compte existe pour cette adresse, un e-mail de réinitialisation vient de partir (expéditeur
              noreply@recette-37d50.firebaseapp.com) — pense à regarder dans les spams. Tu peux aussi utiliser
              « Continuer avec Google » ci-dessus avec la même adresse.
            </p>
          )}

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
