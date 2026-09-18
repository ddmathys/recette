# Recettes du Tiroir

Bibliothèque de recettes familiale et partagée : ajout par texte libre (ou lien) analysé par
DeepSeek, notes personnelles par recette, photos, filtres par catégorie/temps/ingrédients.
Accès réservé aux comptes connectés (Firebase Auth email/mot de passe) — voir
[`firestore.rules`](firestore.rules) et [`storage.rules`](storage.rules).

Next.js 16 (App Router, Tailwind v4) pour le web, app Flutter (dossier [`app_mobile/`](app_mobile))
pour Android/iOS. Les deux parlent au même projet Firebase. Le site web fonctionne en lecture
seule avec 64 recettes de base tant que Firebase n'est pas configuré ; devient une bibliothèque
partagée en temps réel, avec connexion obligatoire, une fois branché.

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
   committer). Sert à la fois à `npm run seed` et à `src/lib/firebaseAdmin.ts` (vérification des
   connexions sur `/api/parse-recipe`) en dev local. En prod (Vercel), utilise plutôt les
   variables `FIREBASE_PROJECT_ID` / `FIREBASE_CLIENT_EMAIL` / `FIREBASE_PRIVATE_KEY` (voir
   `.env.example`) — ne jamais committer le JSON.
5. Authentication → Sign-in method → active **E-mail/Mot de passe**.
6. Seed les 64 recettes de base dans Firestore : `npm run seed` (sûr à relancer, ignore les
   doublons).
7. Redémarre `npm run dev` — la bannière "lecture seule" disparaît. Crée un compte depuis l'écran
   de connexion ; une fois connecté, l'ajout de recette, les notes et les photos deviennent
   fonctionnels et partagés en temps réel entre tous les comptes.

### Règles Firestore / Storage

`firestore.rules` et `storage.rules` exigent `request.auth != null` : lecture et écriture
réservées aux comptes connectés, personne d'autre. N'importe qui avec le lien peut créer un
compte (pas de liste blanche en v1) — si besoin de restreindre à des e-mails précis, ajouter une
vérification côté règles ou désactiver l'auto-inscription.

Déployer les règles après une modification :

```bash
firebase deploy --only firestore:rules,storage:rules
```

## Déploiement (Vercel)

```bash
vercel --prod
```

Configure les mêmes variables d'environnement (`DEEPSEEK_API_KEY`, `NEXT_PUBLIC_FIREBASE_*`,
`FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`) dans les paramètres du
projet Vercel — jamais dans le repo.

## App mobile (Flutter — Android & iOS)

`app_mobile/` est une app Flutter qui parle au même projet Firebase (Auth, Firestore, Storage) et
au même endpoint `/api/parse-recipe` pour la génération IA. Voir
[`app_mobile/README.md`](app_mobile/README.md) pour la config et le build.

```bash
cd app_mobile
flutter pub get
flutter build apk --release   # Android
flutter build ios --release   # iOS (nécessite macOS + Xcode)
```

## Structure

- `src/data/seed-recipes.ts` — les 64 recettes de base.
- `src/lib/useRecipes.ts` — lecture/écriture Firestore (recettes, notes, photos), avec repli sur
  les recettes de base si Firebase n'est pas configuré.
- `src/lib/useAuth.ts`, `src/components/AuthGate.tsx` — connexion/inscription Firebase Auth.
- `src/lib/firebaseAdmin.ts` — vérification des tokens côté serveur (API routes).
- `src/app/api/parse-recipe/route.ts` — appel DeepSeek + extraction de page liée (auth requise,
  quota par utilisateur, garde-fous anti-SSRF).
- `src/components/` — UI web (cartes, filtres, panneau de détail, formulaire d'ajout).
- `scripts/seed.ts` — seed Firestore ponctuel via `npm run seed`.
- `app_mobile/` — app Flutter Android/iOS.
