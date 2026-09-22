import { NextRequest, NextResponse } from "next/server";
import { requireUser } from "@/lib/firebaseAdmin";
import { checkAiRateLimit, VISION_DAILY_LIMIT } from "@/lib/aiRateLimit";
import { MEAL_TYPES } from "@/lib/mealTypes";

export const runtime = "nodejs";
export const maxDuration = 30;

const MAX_IMAGE_BYTES = 8 * 1024 * 1024;

/** Only ever fetch images back from our own Storage bucket — the client
 * always uploads there first and passes the resulting download URL, so
 * there's no reason (and no safety) to let this route fetch an arbitrary
 * URL, unlike /api/parse-recipe's link feature. */
function isOwnStorageUrl(url: string): boolean {
  const bucket = process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET;
  if (!bucket) return false;
  try {
    const u = new URL(url);
    return u.hostname === "firebasestorage.googleapis.com" && u.pathname.startsWith(`/v0/b/${bucket}/o/`);
  } catch {
    return false;
  }
}

async function fetchImageAsBase64(url: string): Promise<{ data: string; mimeType: string } | null> {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return null;
    const contentType = res.headers.get("content-type") || "image/jpeg";
    if (!contentType.startsWith("image/")) return null;
    const buf = await res.arrayBuffer();
    if (buf.byteLength > MAX_IMAGE_BYTES) return null;
    return { data: Buffer.from(buf).toString("base64"), mimeType: contentType };
  } catch {
    return null;
  }
}

export async function POST(req: NextRequest) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return NextResponse.json({ error: "GEMINI_API_KEY n'est pas configurée côté serveur." }, { status: 500 });
  }

  const uid = await requireUser(req);
  if (!uid) {
    return NextResponse.json({ error: "Connecte-toi pour utiliser la reconnaissance photo." }, { status: 401 });
  }
  try {
    if (!(await checkAiRateLimit(uid, "vision"))) {
      return NextResponse.json(
        { error: `Limite de ${VISION_DAILY_LIMIT} photos analysées par jour atteinte, réessaie demain.` },
        { status: 429 },
      );
    }
  } catch (e) {
    console.error("[analyze-meal-photo] rate limit check failed:", e);
    return NextResponse.json({ error: "Vérification du quota impossible, réessaie." }, { status: 500 });
  }

  const body = await req.json().catch(() => null);
  if (!body) {
    return NextResponse.json({ error: "Requête invalide." }, { status: 400 });
  }
  const photoUrl = typeof body.photoUrl === "string" ? body.photoUrl : "";
  const recipes = Array.isArray(body.recipes)
    ? body.recipes.filter(
        (r: unknown): r is { id: string; name: string } =>
          Boolean(r) && typeof r === "object" && typeof (r as { id?: unknown }).id === "string" && typeof (r as { name?: unknown }).name === "string",
      )
    : [];

  if (!photoUrl || !isOwnStorageUrl(photoUrl)) {
    return NextResponse.json({ error: "Photo manquante ou invalide." }, { status: 400 });
  }

  const image = await fetchImageAsBase64(photoUrl);
  if (!image) {
    return NextResponse.json({ error: "Impossible de lire la photo envoyée." }, { status: 400 });
  }

  const mealTypeList = MEAL_TYPES.map((m) => m.key).join(", ");
  const recipeList = recipes.length
    ? recipes.map((r: { id: string; name: string }) => `- ${r.name} (id: ${r.id})`).join("\n")
    : "(aucune recette connue)";
  const prompt = `Tu es un assistant nutrition pour une appli de recettes familiales. On te montre la photo d'un repas mangé.
Réponds UNIQUEMENT avec un objet JSON valide (aucun texte autour, pas de balises markdown), au format exact :
{"label": string (nom court et concret du plat identifié), "portionGrams": nombre entier (poids total estimé de l'assiette en grammes), "kcal": nombre, "proteinG": nombre, "carbsG": nombre, "fatG": nombre, "mealType": une valeur parmi [${mealTypeList}], "matchedRecipeId": string ou null}
Estime les valeurs nutritionnelles à partir de ce que tu vois (types d'aliments, quantités visibles à l'oeil). Reste réaliste, une estimation approchée suffit — ce n'est pas une donnée médicale.
Devine "mealType" à partir de l'apparence du plat.
Si le plat correspond clairement à l'une de ces recettes connues du foyer, renvoie son id exact dans "matchedRecipeId" ; sinon renvoie null. Recettes connues :
${recipeList}`;

  try {
    const resp = await fetch(
      // "gemini-flash-latest" is Google's floating alias for the current
      // recommended Flash model — avoids hardcoding a version that Google
      // deprecates later (already hit this once: gemini-2.5-flash 404'd
      // with "no longer available to new users" during development).
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              parts: [{ inlineData: { mimeType: image.mimeType, data: image.data } }, { text: prompt }],
            },
          ],
          generationConfig: { responseMimeType: "application/json", temperature: 0.3 },
        }),
        signal: AbortSignal.timeout(25000),
      },
    );

    if (!resp.ok) {
      const errText = await resp.text();
      return NextResponse.json(
        { error: `Gemini a répondu une erreur (${resp.status}): ${errText.slice(0, 300)}` },
        { status: 502 },
      );
    }

    const data = await resp.json();
    const content: string | undefined = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!content) {
      return NextResponse.json({ error: "Réponse IA vide." }, { status: 502 });
    }

    let draft;
    try {
      draft = JSON.parse(content);
    } catch {
      return NextResponse.json({ error: "Réponse IA illisible (JSON invalide)." }, { status: 502 });
    }

    return NextResponse.json({ draft });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Erreur inconnue";
    return NextResponse.json({ error: `Appel à Gemini échoué : ${message}` }, { status: 502 });
  }
}
