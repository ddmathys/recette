import { NextResponse } from "next/server";
import { adminAccessToken, adminDb } from "@/lib/firebaseAdmin";
import { checkDailyQuota } from "@/lib/aiRateLimit";

/**
 * Envoi du lien « mot de passe oublié » par nos propres soins.
 *
 * Pourquoi ne pas utiliser `sendPasswordResetEmail()` du SDK client : les
 * e-mails envoyés par le domaine Firebase par défaut
 * (noreply@recette-37d50.firebaseapp.com) ne sont jamais délivrés chez
 * Gmail — testé, pas même en spam. On génère donc le lien côté serveur via
 * l'API Identity Toolkit (`returnOobLink: true` : Firebase renvoie le lien
 * sans envoyer d'e-mail) et on l'envoie avec Resend depuis dmathys.dev, le
 * domaine déjà vérifié utilisé par Éclosion.
 *
 * La réponse est toujours `{ ok: true }` quand la configuration est en
 * place, même si l'adresse n'a pas de compte : sinon ce endpoint dirait à
 * n'importe qui quelles adresses sont inscrites. Si la configuration
 * manque (pas de clé Resend, pas d'identifiants admin), on répond 503 et
 * le client retombe sur l'envoi Firebase.
 */

const FROM = "Recettes du Tiroir <recettes@dmathys.dev>";
const RESET_DAILY_LIMIT = 5;

async function oobLinkFor(email: string): Promise<string | null> {
  const projectId = process.env.FIREBASE_PROJECT_ID || process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  const token = await adminAccessToken();
  if (!projectId || !token) return null;

  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:sendOobCode`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ requestType: "PASSWORD_RESET", email, returnOobLink: true }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    // EMAIL_NOT_FOUND est un cas normal : on ne le distingue pas d'un succès
    // côté client, on n'envoie simplement pas d'e-mail.
    const reason = typeof data?.error?.message === "string" ? data.error.message : `HTTP ${res.status}`;
    if (reason.includes("EMAIL_NOT_FOUND")) return null;
    throw new Error(`Identity Toolkit: ${reason}`);
  }
  return typeof data.oobLink === "string" ? data.oobLink : null;
}

async function sendViaResend(email: string, link: string): Promise<void> {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) throw new Error("RESEND_API_KEY manquante");

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({
      from: FROM,
      to: [email],
      subject: "Ton nouveau mot de passe — Recettes du Tiroir",
      text: [
        "Tu as demandé à changer ton mot de passe sur Recettes du Tiroir.",
        "",
        `Choisis-en un nouveau ici : ${link}`,
        "",
        "Ce lien est valable une heure et ne fonctionne qu'une fois.",
        "Si tu n'as rien demandé, ignore cet e-mail : ton mot de passe reste inchangé.",
        "",
        "Tu peux aussi te connecter avec Google si ton compte utilise la même adresse.",
      ].join("\n"),
      html: `<div style="font-family:system-ui,-apple-system,'Segoe UI',sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#2b2a26">
  <h1 style="font-size:19px;margin:0 0 16px">Ton nouveau mot de passe</h1>
  <p style="font-size:15px;line-height:1.5;margin:0 0 20px">Tu as demandé à changer ton mot de passe sur <strong>Recettes du Tiroir</strong>.</p>
  <p style="margin:0 0 24px"><a href="${link}" style="display:inline-block;background:#ff5a36;color:#fff;text-decoration:none;font-weight:700;font-size:15px;padding:13px 22px;border-radius:14px">Choisir un nouveau mot de passe</a></p>
  <p style="font-size:13px;line-height:1.5;color:#8a8577;margin:0 0 8px">Ce lien est valable une heure et ne fonctionne qu'une fois.</p>
  <p style="font-size:13px;line-height:1.5;color:#8a8577;margin:0 0 8px">Si tu n'as rien demandé, ignore cet e-mail : ton mot de passe reste inchangé.</p>
  <p style="font-size:13px;line-height:1.5;color:#8a8577;margin:0">Tu peux aussi te connecter avec Google si ton compte utilise la même adresse.</p>
</div>`,
    }),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Resend: HTTP ${res.status} ${body.slice(0, 200)}`);
  }
}

export async function POST(req: Request) {
  let email = "";
  try {
    const body = (await req.json()) as { email?: unknown };
    email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  } catch {
    /* corps illisible → traité comme e-mail manquant */
  }

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return NextResponse.json({ error: "Adresse e-mail invalide." }, { status: 400 });
  }
  if (!process.env.RESEND_API_KEY) {
    return NextResponse.json({ error: "Envoi non configuré." }, { status: 503 });
  }

  // Plafond quotidien par adresse : empêche d'utiliser ce endpoint pour
  // inonder quelqu'un d'e-mails. Si Firestore admin n'est pas joignable, on
  // laisse passer plutôt que de casser la récupération de compte.
  if (adminDb) {
    const key = `pwreset_${Buffer.from(email).toString("base64url").slice(0, 80)}`;
    const allowed = await checkDailyQuota(key, RESET_DAILY_LIMIT).catch(() => true);
    if (!allowed) {
      return NextResponse.json({ error: "Trop de demandes pour cette adresse aujourd'hui, réessaie demain." }, { status: 429 });
    }
  }

  try {
    const link = await oobLinkFor(email);
    // Pas de compte pour cette adresse : on répond comme si tout allait
    // bien, sans rien envoyer (ne pas révéler qui est inscrit).
    if (link) await sendViaResend(email, link);
    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error("[send-password-reset]", e instanceof Error ? e.message : e);
    return NextResponse.json({ error: "L'envoi a échoué." }, { status: 502 });
  }
}
