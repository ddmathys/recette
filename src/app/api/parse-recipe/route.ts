import { NextRequest, NextResponse } from "next/server";
import { lookup } from "node:dns/promises";
import { CATEGORIES } from "@/lib/categories";
import { requireUser } from "@/lib/firebaseAdmin";
import { AI_DAILY_LIMIT, checkAiRateLimit } from "@/lib/aiRateLimit";

export const runtime = "nodejs";
// Vercel Node.js function budget: fetch (6s) + DeepSeek (25s) with margin.
export const maxDuration = 35;

const MAX_PAGE_BYTES = 2 * 1024 * 1024; // 2 MB cap on fetched page content

/** Blocks requests aimed at private/loopback/link-local addresses so the
 * "paste a link" feature can't be used to probe internal network hosts
 * from the Vercel function (SSRF). */
function isPrivateAddress(ip: string): boolean {
  if (ip === "::1" || ip === "127.0.0.1") return true;
  if (ip.startsWith("127.") || ip.startsWith("10.") || ip.startsWith("169.254.")) return true;
  if (ip.startsWith("192.168.")) return true;
  if (/^172\.(1[6-9]|2\d|3[0-1])\./.test(ip)) return true;
  if (ip.startsWith("fc") || ip.startsWith("fd") || ip.startsWith("fe80")) return true; // IPv6 ULA/link-local
  return false;
}

async function isSafeUrl(url: string): Promise<boolean> {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return false;
  try {
    const results = await lookup(parsed.hostname, { all: true });
    if (!results.length) return false;
    return results.every((r) => !isPrivateAddress(r.address));
  } catch {
    return false; // unresolvable host — treat as unsafe rather than guess
  }
}

async function readCapped(res: Response, maxBytes: number): Promise<string> {
  const reader = res.body?.getReader();
  if (!reader) return "";
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (value) {
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel().catch(() => {});
        break;
      }
      chunks.push(value);
    }
  }
  return Buffer.concat(chunks.map((c) => Buffer.from(c))).toString("utf8");
}

async function fetchPageText(url: string): Promise<{ text: string; ogImage: string | null }> {
  try {
    if (!(await isSafeUrl(url))) return { text: "", ogImage: null };

    const res = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0 (compatible; RecettesDuTiroir/1.0)" },
      signal: AbortSignal.timeout(6000),
      redirect: "follow",
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
      // The final URL (after redirects) must still resolve away from
      // internal hosts, in case the redirect target itself points inward.
      if (!(await isSafeUrl(res.url))) return { text: "", ogImage: null };
    } catch {
      /* if URL parsing fails, fall through and try to use the content anyway */
    }

    const html = await readCapped(res, MAX_PAGE_BYTES);

    const ogMatch =
      html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i) ||
      html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i) ||
      html.match(/<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i);
    let ogImage = ogMatch
      ? ogMatch[1].replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#39;/g, "'")
      : null;
    // Only ever hand back an http(s) image URL — never let extracted markup
    // leak a javascript:/data: URI back to the client.
    if (ogImage && !/^https?:\/\//i.test(ogImage)) ogImage = null;

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
    console.error("[parse-recipe] rate limit check failed:", e);
    return NextResponse.json({ error: "Vérification du quota impossible, réessaie." }, { status: 500 });
  }

  const body = await req.json().catch(() => null);
  if (!body) {
    return NextResponse.json({ error: "Requête invalide." }, { status: 400 });
  }
  const text = typeof body.text === "string" ? body.text.trim() : "";
  const name = typeof body.name === "string" ? body.name.trim() : "";
  const link = typeof body.link === "string" ? body.link.trim() : "";
  // Nombre de personnes choisi avant la recherche — optionnel (anciens
  // clients ne l'envoient pas), borné pour éviter des quantités absurdes.
  const rawServings = Math.round(Number(body.servings));
  const servings = Number.isFinite(rawServings) && rawServings > 0 ? Math.min(rawServings, 20) : null;

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
{"name": string, "cat": une valeur parmi [${catList}], "time": nombre entier de minutes de préparation active, "diff": "Facile" ou "Moyen" ou "Avancé", "servings": nombre entier de personnes, "veg": true si la recette ne contient ni viande ni poisson sinon false, "ingr": tableau de paires {"name": string, "qty": string}, "steps": tableau de 3 à 6 étapes concises en français, "nutrition": {"kcal": nombre, "proteinG": nombre, "carbsG": nombre, "fatG": nombre, "gramsPerServing": nombre entier}}
Si le texte ou la page donnent déjà des ingrédients/étapes précis, reprends-les fidèlement (range-les, complète les quantités manquantes de façon plausible). Si le contenu extrait de la page ne correspond visiblement pas à une recette du plat demandé (page d'accueil, contenu sans rapport), ignore-le et base-toi uniquement sur le nom du plat et le texte libre. S'il ne reste qu'un nom de plat, base-toi sur une recette classique et réaliste, adaptée au nombre de personnes.${servings ? `
La recette doit être prévue pour EXACTEMENT ${servings} personne(s) : "servings" vaut ${servings} et toutes les quantités d'ingrédients sont calculées pour ${servings} personne(s).` : ""}
Pour "nutrition", estime les valeurs moyennes d'UNE SEULE portion (pas toute la recette) à partir des ingrédients, de leurs quantités et du nombre de personnes : poids approximatif de l'assiette en grammes, kilocalories, protéines/glucides/lipides en grammes. Reste réaliste, une estimation approchée suffit — ce n'est pas une donnée médicale.

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

    return NextResponse.json({ draft, ogImage });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Erreur inconnue";
    return NextResponse.json({ error: `Appel à DeepSeek échoué : ${message}` }, { status: 502 });
  }
}
