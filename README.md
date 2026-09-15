# Recettes du Tiroir

Bibliothèque de recettes familiale et partagée : ajout par texte libre (ou lien) analysé par
DeepSeek, notes personnelles par recette, photos, filtres par catégorie/temps/ingrédients.

Next.js 16 (App Router, Tailwind v4). Fonctionne en lecture seule avec 64 recettes de base tant
que Firebase n'est pas configuré ; devient une bibliothèque partagée en temps réel une fois
branché.

## Démarrer en local

```bash
npm install
npm run dev
```

Ouvre [http://localhost:3000](http://localhost:3000). Sans configuration, l'app tourne déjà en
lecture seule avec les 64 recettes intégrées (`src/data/seed-recipes.ts`).

## Activer l'IA (DeepSeek)

1. Récupère une clé sur [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys).
2. Copie `.env.example` en `.env.local` et renseigne `DEEPSEEK_API_KEY`.
3. Redémarre `npm run dev`.

La route `src/app/api/parse-recipe/route.ts` appelle DeepSeek côté serveur (la clé n'est jamais
exposée au navigateur). Si un lien est fourni, la page est récupérée côté serveur et son contenu
texte + son image `og:image` sont utilisés pour proposer une recette structurée et une photo.

## Activer la bibliothèque partagée (Firebase)

1. Crée un projet sur [console.firebase.google.com](https://console.firebase.google.com).
2. Active **Firestore Database** et **Storage**.
3. Project settings → General → Your apps → ajoute une app Web, copie la config dans
   `.env.local` (voir `.env.example` pour les noms de variables `NEXT_PUBLIC_FIREBASE_*`).
4. Project settings → Service accounts → **Generate new private key**, enregistre le fichier
   téléchargé sous `serviceAccountKey.json` à la racine (déjà dans `.gitignore`, ne jamais
   committer).
5. Seed les 64 recettes de base dans Firestore : `npm run seed` (sûr à relancer, ignore les
   doublons).
6. Redémarre `npm run dev` — la bannière "lecture seule" disparaît, l'ajout de recette, les notes
   et les photos deviennent fonctionnels et partagés en temps réel entre tous les viewers.

### Règles Firestore / Storage à configurer

Pour un usage familial simple, des règles ouvertes à tout utilisateur authentifié suffisent (pas
d'authentification mise en place dans cette v1 — à ajouter avant un partage plus large que la
famille proche). À durcir avant une mise en production plus large.

## Déploiement (Vercel)

```bash
vercel
```

Configure les mêmes variables d'environnement (`DEEPSEEK_API_KEY`, `NEXT_PUBLIC_FIREBASE_*`) dans
les paramètres du projet Vercel — jamais dans le repo.

## Structure

- `src/data/seed-recipes.ts` — les 64 recettes de base.
- `src/lib/useRecipes.ts` — lecture/écriture Firestore (recettes, notes, photos), avec repli sur
  les recettes de base si Firebase n'est pas configuré.
- `src/app/api/parse-recipe/route.ts` — appel DeepSeek + extraction de page liée.
- `src/components/` — UI (cartes, filtres, panneau de détail, formulaire d'ajout).
- `scripts/seed.ts` — seed Firestore ponctuel via `npm run seed`.
