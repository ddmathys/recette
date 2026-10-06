"use client";

import { useMemo, useState } from "react";
import { ACTIVITIES, AIMS, computeEnergy, metricsComplete, type ActivityKey, type AimKey, type Sex } from "@/lib/energy";
import { saveBodyMetrics, setDailyKcalGoal, setDisplayName } from "@/lib/useHousehold";
import type { UserProfile } from "@/lib/types";

const DEFAULT_GOAL = 2000;

/**
 * « Mon profil » : prénom, mesures du corps (sexe, année de naissance,
 * taille, poids, activité, objectif de poids) → besoin quotidien estimé
 * (Mifflin-St Jeor, voir src/lib/energy.ts). La proposition ne devient
 * l'objectif que si l'utilisateur la valide ; il peut aussi taper son
 * propre chiffre, ici ou directement sur le dashboard, à tout moment.
 */
export function ProfileDialog({
  uid,
  profile,
  onClose,
}: {
  uid: string;
  profile: UserProfile;
  onClose: () => void;
}) {
  const year = new Date().getFullYear();
  const [name, setName] = useState(profile.displayName ?? "");
  const [sex, setSex] = useState<Sex | undefined>(profile.sex);
  const [birthYear, setBirthYear] = useState(profile.birthYear ? String(profile.birthYear) : "");
  const [heightCm, setHeightCm] = useState(profile.heightCm ? String(profile.heightCm) : "");
  const [weightKg, setWeightKg] = useState(profile.weightKg ? String(profile.weightKg) : "");
  const [activity, setActivity] = useState<ActivityKey | undefined>(profile.activity);
  const [aim, setAim] = useState<AimKey | undefined>(profile.aim);

  const currentGoal = profile.dailyKcalGoal && profile.dailyKcalGoal > 0 ? profile.dailyKcalGoal : DEFAULT_GOAL;
  const [goalInput, setGoalInput] = useState(String(currentGoal));
  const [busy, setBusy] = useState<"metrics" | "goal" | "apply" | null>(null);
  const [saved, setSaved] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const draft = useMemo(
    () => ({
      sex,
      birthYear: Number(birthYear) || undefined,
      heightCm: Number(heightCm) || undefined,
      weightKg: Number(weightKg) || undefined,
      activity,
      aim,
    }),
    [sex, birthYear, heightCm, weightKg, activity, aim],
  );

  const energy = metricsComplete(draft) ? computeEnergy(draft) : null;
  const missing = !energy;

  async function saveMetrics() {
    if (!metricsComplete(draft)) {
      setError("Complète le sexe, l'année de naissance, la taille, le poids, l'activité et l'objectif.");
      return;
    }
    setError(null);
    setBusy("metrics");
    try {
      if (name.trim() && name.trim() !== profile.displayName) await setDisplayName(uid, name);
      await saveBodyMetrics(uid, draft);
      setSaved("Mesures enregistrées.");
    } catch {
      setError("L'enregistrement a échoué, réessaie.");
    } finally {
      setBusy(null);
    }
  }

  /** « OK, je réplique » : la proposition devient l'objectif du dashboard. */
  async function applySuggestion() {
    if (!energy || !metricsComplete(draft)) return;
    setError(null);
    setBusy("apply");
    try {
      if (name.trim() && name.trim() !== profile.displayName) await setDisplayName(uid, name);
      await saveBodyMetrics(uid, draft);
      await setDailyKcalGoal(uid, energy.suggested, "computed");
      setGoalInput(String(energy.suggested));
      setSaved(`Objectif réglé sur ${energy.suggested} kcal/jour.`);
    } catch {
      setError("L'enregistrement a échoué, réessaie.");
    } finally {
      setBusy(null);
    }
  }

  async function saveGoal() {
    const v = Number(goalInput);
    if (!Number.isFinite(v) || v < 800 || v > 6000) {
      setError("Indique un objectif entre 800 et 6000 kcal.");
      return;
    }
    setError(null);
    setBusy("goal");
    try {
      await setDailyKcalGoal(uid, Math.round(v), "manual");
      setSaved(`Objectif fixé à la main : ${Math.round(v)} kcal/jour.`);
    } catch {
      setError("L'enregistrement a échoué, réessaie.");
    } finally {
      setBusy(null);
    }
  }

  const goalDiffers = energy ? Math.abs(energy.suggested - currentGoal) >= 25 : false;

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-bg">
      <header className="sticky top-0 z-10 border-b border-line bg-bg/95 backdrop-blur" style={{ paddingTop: "env(safe-area-inset-top, 0px)" }}>
        <div className="mx-auto flex max-w-[640px] items-center gap-3 px-4 py-3">
          <button
            onClick={onClose}
            aria-label="Fermer"
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-surface text-ink shadow-[0_1px_3px_rgba(43,42,38,.08)]"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" className="h-4.5 w-4.5">
              <path d="M15 18l-6-6 6-6" />
            </svg>
          </button>
          <h2 className="min-w-0 flex-1 truncate text-[1.1rem] font-extrabold tracking-tight text-ink">Mon profil</h2>
        </div>
      </header>

      <main className="mx-auto flex max-w-[640px] flex-col gap-3.5 px-4 pb-16 pt-4">
        {error && <p className="rounded-xl bg-accent/10 px-3.5 py-2.5 text-[0.85rem] font-medium text-accent">{error}</p>}
        {saved && !error && <p className="rounded-xl bg-herb/10 px-3.5 py-2.5 text-[0.85rem] font-semibold text-herb">✓ {saved}</p>}

        {/* Objectif en cours — toujours modifiable, c'est lui que le dashboard utilise. */}
        <section className="rounded-3xl bg-surface p-4 shadow-[0_1px_3px_rgba(43,42,38,.08)]">
          <h3 className="text-[0.78rem] font-bold uppercase tracking-wider text-ink-soft">Mon objectif du jour</h3>
          <div className="mt-2 flex flex-wrap items-end gap-3">
            <label className="flex flex-col gap-1">
              <span className="text-[0.76rem] text-ink-soft">kcal par jour</span>
              <input
                type="number"
                inputMode="numeric"
                value={goalInput}
                onChange={(e) => setGoalInput(e.target.value)}
                className="w-32 rounded-xl border-2 border-line bg-surface-2 px-3 py-2.5 font-mono text-[1.25rem] font-extrabold text-ink outline-none focus:border-accent"
              />
            </label>
            <button
              onClick={saveGoal}
              disabled={busy !== null}
              className="rounded-xl bg-ink px-4 py-2.5 text-[0.88rem] font-bold text-bg disabled:opacity-50"
            >
              {busy === "goal" ? "…" : "Enregistrer"}
            </button>
          </div>
          <p className="mt-2 text-[0.76rem] text-ink-soft">
            {profile.goalSource === "computed"
              ? "Calculé depuis tes mesures — tu peux le remplacer par ton propre chiffre quand tu veux."
              : "Fixé à la main. Remplis tes mesures ci-dessous pour obtenir une proposition."}
          </p>
        </section>

        {/* Mesures → proposition */}
        <section className="rounded-3xl bg-surface p-4 shadow-[0_1px_3px_rgba(43,42,38,.08)]">
          <h3 className="text-[0.78rem] font-bold uppercase tracking-wider text-ink-soft">Mes mesures</h3>
          <p className="mb-3 mt-1 text-[0.78rem] text-ink-soft">
            Servent uniquement à estimer ton besoin quotidien. Rien n&apos;est partagé avec les autres membres du foyer.
          </p>

          <div className="flex flex-col gap-3.5">
            <label className="flex flex-col gap-1.5">
              <span className="text-[0.84rem] font-bold text-ink">Prénom</span>
              <input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="David"
                className="rounded-xl border-2 border-line bg-surface-2 px-3.5 py-2.5 text-[0.95rem] text-ink outline-none focus:border-accent"
              />
            </label>

            <div className="flex flex-col gap-1.5">
              <span className="text-[0.84rem] font-bold text-ink">Sexe</span>
              <div className="flex gap-2">
                {([
                  ["f", "Femme"],
                  ["h", "Homme"],
                ] as [Sex, string][]).map(([key, label]) => (
                  <button
                    key={key}
                    onClick={() => setSex(key)}
                    className={`flex-1 rounded-xl border-2 px-3 py-2.5 text-[0.9rem] font-bold ${
                      sex === key ? "border-accent bg-accent text-accent-ink" : "border-line bg-surface-2 text-ink-soft"
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>
              <span className="text-[0.72rem] text-ink-soft">La formule de calcul n&apos;a que ces deux variantes.</span>
            </div>

            <div className="grid grid-cols-3 gap-2.5">
              <Field label="Année de naissance" value={birthYear} onChange={setBirthYear} placeholder={String(year - 35)} />
              <Field label="Taille (cm)" value={heightCm} onChange={setHeightCm} placeholder="178" />
              <Field label="Poids (kg)" value={weightKg} onChange={setWeightKg} placeholder="75" />
            </div>

            <div className="flex flex-col gap-1.5">
              <span className="text-[0.84rem] font-bold text-ink">Activité physique</span>
              <div className="flex flex-col gap-1.5">
                {ACTIVITIES.map((a) => (
                  <button
                    key={a.key}
                    onClick={() => setActivity(a.key)}
                    className={`flex items-baseline gap-2 rounded-xl border-2 px-3.5 py-2.5 text-left ${
                      activity === a.key ? "border-accent bg-accent/8" : "border-line bg-surface-2"
                    }`}
                  >
                    <span className="text-[0.9rem] font-bold text-ink">{a.label}</span>
                    <span className="text-[0.74rem] text-ink-soft">{a.hint}</span>
                  </button>
                ))}
              </div>
            </div>

            <div className="flex flex-col gap-1.5">
              <span className="text-[0.84rem] font-bold text-ink">Mon objectif de poids</span>
              <div className="flex flex-wrap gap-1.5">
                {AIMS.map((a) => (
                  <button
                    key={a.key}
                    onClick={() => setAim(a.key)}
                    title={a.hint}
                    className={`rounded-full border-2 px-3.5 py-2 text-[0.84rem] font-bold ${
                      aim === a.key ? "border-accent bg-accent text-accent-ink" : "border-line bg-surface-2 text-ink-soft"
                    }`}
                  >
                    {a.label}
                  </button>
                ))}
              </div>
              {aim && <span className="text-[0.74rem] text-ink-soft">{AIMS.find((a) => a.key === aim)?.hint}</span>}
            </div>
          </div>
        </section>

        {/* Résultat du calcul */}
        <section className="rounded-3xl bg-[linear-gradient(160deg,#fffdf8_0%,#fdf4e4_100%)] p-4 shadow-[0_2px_14px_-6px_rgba(43,42,38,.25)]">
          <h3 className="text-[0.78rem] font-bold uppercase tracking-wider text-ink-soft">Ton besoin estimé</h3>
          {missing ? (
            <p className="mt-2 text-[0.88rem] text-ink-soft">
              Complète tes mesures ci-dessus et le calcul s&apos;affiche ici.
            </p>
          ) : (
            <>
              <div className="mt-1.5 flex items-baseline gap-2">
                <span className="font-mono text-[2.4rem] font-extrabold leading-none text-ink">{energy.suggested}</span>
                <span className="text-[0.9rem] font-semibold text-ink-soft">kcal / jour</span>
              </div>
              <p className="mt-2 text-[0.8rem] text-ink-soft">
                Métabolisme de base <strong className="text-ink">{energy.bmr}</strong> × activité{" "}
                {ACTIVITIES.find((a) => a.key === activity)?.label.toLowerCase()} = <strong className="text-ink">{energy.tdee}</strong> kcal
                dépensées, {AIMS.find((a) => a.key === aim)?.delta === 0 ? "sans ajustement" : `ajusté de ${AIMS.find((a) => a.key === aim)!.delta > 0 ? "+" : ""}${AIMS.find((a) => a.key === aim)!.delta} kcal pour ton objectif`}.
              </p>
              {energy.floored && (
                <p className="mt-2 rounded-xl bg-gold/15 px-3 py-2 text-[0.78rem] font-semibold text-gold">
                  Relevé au plancher de sécurité ({sex === "f" ? 1200 : 1500} kcal). Pour descendre plus bas, parles-en à un professionnel.
                </p>
              )}
              <div className="mt-3 flex flex-col gap-2">
                <button
                  onClick={applySuggestion}
                  disabled={busy !== null}
                  className="rounded-2xl bg-accent px-4 py-3.5 text-[0.95rem] font-bold text-accent-ink shadow-[0_2px_10px_-2px_rgba(255,90,54,.65)] disabled:opacity-50"
                >
                  {busy === "apply" ? "Enregistrement…" : goalDiffers ? `OK, utiliser ${energy.suggested} kcal` : `✓ C'est déjà mon objectif`}
                </button>
                <button
                  onClick={saveMetrics}
                  disabled={busy !== null}
                  className="rounded-2xl border-2 border-line bg-surface px-4 py-3 text-[0.9rem] font-bold text-ink hover:border-accent disabled:opacity-50"
                >
                  {busy === "metrics" ? "Enregistrement…" : "Garder mes mesures sans changer l'objectif"}
                </button>
              </div>
              <p className="mt-2.5 text-[0.74rem] text-ink-soft">
                Estimation indicative, sans valeur médicale. Tu gardes la main : l&apos;objectif reste modifiable ici ou en tapant
                sur le chiffre du dashboard.
              </p>
            </>
          )}
        </section>
      </main>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder: string;
}) {
  return (
    <label className="flex flex-col gap-1.5">
      <span className="text-[0.76rem] font-semibold text-ink-soft">{label}</span>
      <input
        type="number"
        inputMode="numeric"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full rounded-xl border-2 border-line bg-surface-2 px-3 py-2.5 font-mono text-[1rem] font-bold text-ink outline-none focus:border-accent"
      />
    </label>
  );
}
