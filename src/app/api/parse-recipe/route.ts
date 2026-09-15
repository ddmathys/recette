import { NextRequest, NextResponse } from "next/server";
import { CATEGORIES } from "@/lib/categories";

export const runtime = "nodejs";

async function fetchPageText(url: string): Promise<{ text: string; ogImage: string | null }> {
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0 (compatible; RecettesDuTiroir/1.0)" },
      signal: AbortSignal.timeout(8000),
    });

    // Some sites bounce non-browser requests to an unrelated page (home,
    // consent wall, bot check) instead of serving the article — if we got
    // redirected well away from the requested path, the content is not
    // trustworthy, so treat it as unreadable rather than feeding DeepSeek
    // an unrelated page.
    try {
      const requestedPath = new URL(url).pathname.replace(/\/+$/, "");
      const finalPath = new URL(res.url).pathname.replace(/\/+$/, "");
      if (requestedPath && finalPath !== requestedPath) {
        return { text: "", ogImage: null };
      }
    } catch {
      /* if URL parsing fails, fall through and try to use the content anyway */
    }

    const html = await res.text();

    const ogMatch =
      html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i) ||
      html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i) ||
      html.match(/<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i);
    const ogImage = ogMatch
      ? ogMatch[1].replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#39;/g, "'")
      : null;

    const text = html
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<[^>]+>/g, " ")
      .replace(/&nbsp;/g, " ")
      .replace(/\s+/g, " ")
      .trim();

    return { text: text.slice(0, 6000), ogImage };
  } catch {
    return { text: "", ogImage: null };
  }
}

export async function POST(req: NextRequest) {
  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { error: "DEEPSEEK_API_KEY n'est pas configurée côté serveur." },
      { status: 500 },
    );
  }

  const body = await req.json().catch(() => null);
  if (!body) {
    return NextResponse.json({ error: "Requête invalide." }, { status: 400 });
  }
  const text = typeof body.text === "string" ? body.text.trim() : "";
  const name = typeof body.name === "string" ? body.name.trim() : "";
  const link = typeof body.link === "string" ? body.link.trim() : "";

  if (!text && !name && !link) {
    return NextResponse.json({ error: "Donne au moins un nom de plat, un texte ou un lien." }, { status: 400 });
  }

  let linkText = "";
  let ogImage: string | null = null;
  if (link) {
    const page = await fetchPageText(link);
    linkText = page.text;
    ogImage = page.ogImage;
  }

  const catList = CATEGORIES.map((c) => c.key).join(", ");
  const prompt = `Tu es un assistant culinaire pour une appli de recettes familiales.
On te donne des informations sur un plat : un nom, un texte libre (ingrédients/étapes dans le désordre, ou juste des notes), et éventuellement le contenu extrait d'une page web source. Structure tout ça.
Réponds UNIQUEMENT avec un objet JSON valide (aucun texte autour, pas de balises markdown), au format exact :
{"name": string, "cat": une valeur parmi [${catList}], "time": nombre entier de minutes de préparation active, "diff": "Facile" ou "Moyen" ou "Avancé", "servings": nombre entier de personnes, "veg": true si la recette ne contient ni viande ni poisson sinon false, "ingr": tableau de paires {"name": string, "qty": string}, "steps": tableau de 3 à 6 étapes concises en français}
Si le texte ou la page donnent déjà des ingrédients/étapes précis, reprends-les fidèlement (range-les, complète les quantités manquantes de façon plausible). Si le contenu extrait de la page ne correspond visiblement pas à une recette du plat demandé (page d'accueil, contenu sans rapport), ignore-le et base-toi uniquement sur le nom du plat et le texte libre. S'il ne reste qu'un nom de plat, base-toi sur une recette classique et réaliste, adaptée au nombre de personnes.

Nom du plat indiqué : ${name || "(aucun)"}
Texte libre fourni par l'utilisateur :
${text || "(aucun)"}
Contenu extrait de la page liée (${link || "aucun lien fourni"}) :
${linkText || "(aucun, ou page illisible)"}`;

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
      signal: AbortSignal.timeout(60000),
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

    return NextResponse.json({ draft, ogImage });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Erreur inconnue";
    return NextResponse.json({ error: `Appel à DeepSeek échoué : ${message}` }, { status: 502 });
  }
}
