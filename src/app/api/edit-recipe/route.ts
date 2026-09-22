import { NextRequest, NextResponse } from "next/server";
import { CATEGORIES } from "@/lib/categories";
import { requireUser } from "@/lib/firebaseAdmin";
import { AI_DAILY_LIMIT, checkAiRateLimit } from "@/lib/aiRateLimit";

export const runtime = "nodejs";
export const maxDuration = 30;

/** AI-assisted edit of an *existing* recipe: given its current content and
 * a free-text instruction ("remplace le poulet par du tofu", "double les
 * proportions"...), asks DeepSeek for the updated recipe. Sibling to
 * /api/parse-recipe (same auth + quota), but takes a recipe instead of a
 * link/text to parse from scratch. */
export async function POST(req: NextRequest) {
  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { error: "DEEPSEEK_API_KEY n'est pas configurée côté serveur." },
      { status: 500 },
    );
  }

  const uid = await requireUser(req);
  if (!uid) {
    return NextResponse.json({ error: "Connecte-toi pour utiliser la génération IA." }, { status: 401 });
  }
  try {
    if (!(await checkAiRateLimit(uid))) {
      return NextResponse.json(
        { error: `Limite de ${AI_DAILY_LIMIT} générations IA par jour atteinte, réessaie demain.` },
        { status: 429 },
      );
    }
  } catch (e) {
    console.error("[edit-recipe] rate limit check failed:", e);
    return NextResponse.json({ error: "Vérification du quota impossible, réessaie." }, { status: 500 });
  }

  const body = await req.json().catch(() => null);
  if (!body) {
    return NextResponse.json({ error: "Requête invalide." }, { status: 400 });
  }
  const recipe = body.recipe;
  const instruction = typeof body.instruction === "string" ? body.instruction.trim() : "";
  if (!recipe || typeof recipe !== "object") {
    return NextResponse.json({ error: "Recette manquante." }, { status: 400 });
  }
  if (!instruction) {
    return NextResponse.json({ error: "Décris la modification à apporter." }, { status: 400 });
  }

  const catList = CATEGORIES.map((c) => c.key).join(", ");
  const prompt = `Tu es un assistant culinaire pour une appli de recettes familiales.
Voici une recette existante, au format JSON :
${JSON.stringify(recipe)}

L'utilisateur demande la modification suivante : "${instruction}"

Applique cette modification à la recette. Garde tout le reste identique (mêmes ingrédients, mêmes étapes, mêmes quantités) sauf si la demande implique explicitement un changement plus large. Ajuste temps/personnes/difficulté/végétarien si la modification les affecte.
Réponds UNIQUEMENT avec un objet JSON valide (aucun texte autour, pas de balises markdown) représentant la recette mise à jour, au format exact :
{"name": string, "cat": une valeur parmi [${catList}], "time": nombre entier de minutes de préparation active, "diff": "Facile" ou "Moyen" ou "Avancé", "servings": nombre entier de personnes, "veg": true si la recette ne contient ni viande ni poisson sinon false, "ingr": tableau de paires {"name": string, "qty": string}, "steps": tableau de 3 à 6 étapes concises en français, "nutrition": {"kcal": nombre, "proteinG": nombre, "carbsG": nombre, "fatG": nombre, "gramsPerServing": nombre entier}}
Recalcule "nutrition" (valeurs pour UNE portion) si la modification change les ingrédients, les quantités ou le nombre de personnes ; sinon reprends l'estimation existante si elle est cohérente.`;

  try {
    const resp = await fetch("https://api.deepseek.com/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        messages: [{ role: "user", content: prompt }],
        response_format: { type: "json_object" },
        temperature: 0.4,
      }),
      signal: AbortSignal.timeout(25000),
    });

    if (!resp.ok) {
      const errText = await resp.text();
      return NextResponse.json(
        { error: `DeepSeek a répondu une erreur (${resp.status}): ${errText.slice(0, 300)}` },
        { status: 502 },
      );
    }

    const data = await resp.json();
    const content: string | undefined = data.choices?.[0]?.message?.content;
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
    return NextResponse.json({ error: `Appel à DeepSeek échoué : ${message}` }, { status: 502 });
  }
}
