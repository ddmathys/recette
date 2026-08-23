# 05 — Plan MVP, de la première à la dernière étape

> Statut : proposition v1
> Format : 13 étapes numérotées, chacune avec un livrable vérifiable et une **condition de sortie**.
> Rythme supposé : temps partiel, ~10 h/semaine. Les durées sont des ordres de grandeur, pas des engagements.

**Règle du plan : on ne passe pas à l'étape N+1 tant que la condition de sortie de N n'est pas remplie.** C'est ce qui empêche d'accumuler du travail à moitié fini — l'équivalent, au niveau du projet, de la règle « pas de retour en arrière ».

---

## Étape 0 — Valider ces documents ✅ *(fait le 22/08/2026)*

Rien à coder. Tu lis les docs 01 à 04 et tu tranches les points ouverts :
- doc 01 §8 : test de placement avant ou après la 1ʳᵉ leçon · méthodes de connexion · classification d'âge
- doc 02 : les 5 niveaux et leurs descripteurs · le seuil de validation par compétence
- doc 03 : la formule de difficulté et les 6 paliers
- doc 04 : les 6 décisions gelées

**Sortie :** ✅ validé. Les décisions sont consignées au doc 01 §8.

---

## Étape 1 — Le prototype cliquable *(fait — voir `prototype/`)*

Un parcours complet jouable dans un navigateur : test de placement adaptatif réel (sur les 130 lemmes), carte d'Espagne, fiche ville, leçon à 3 exercices, tampon, passeport.

**Ce n'est pas l'app.** C'est l'outil pour décider avant de coder : est-ce que la boucle donne envie ? est-ce que le placement tombe juste ? est-ce que la carte est lisible ?

**Sortie :** tu as joué le parcours 3 fois et tu sais ce que tu veux changer.

---

## Étape 2 — Fondations techniques ✅ *(squelette posé)*

- Projet Flutter, flavors `dev` / `prod`, `analysis_options` strict.
- Firebase : projet dev + projet prod, Auth anonyme, Firestore, Remote Config, Crashlytics.
- Design system Kameo : couleurs, Fredoka/Nunito, `KButton`, `KCard`, `KProgress`, haptiques.
- CI GitHub Actions : `flutter analyze` + `flutter test` sur chaque push.
- Arborescence du doc 04 §5, avec `domain/` vide mais isolé.

**Sortie :** ✅ posé — `pubspec.yaml`, `analysis_options.yaml` strict, thème Kameo (`lib/core/theme/`), `KButton` avec son retour haptique, `ContentRepository` qui charge le pack depuis les assets, un écran d'amorçage qui affiche la répartition du répertoire, et `.github/workflows/ci.yml` (deux jobs : moteur Dart pur, app Flutter).

⚠️ **Restant à faire sur ta machine** : `flutter create` pour générer les dossiers `android/` et `ios/`, puis `flutter pub get && flutter run`. Le conteneur de développement n'a pas le SDK Flutter — le code Dart est vérifié syntaxiquement, mais l'app n'a pas été compilée. C'est la seule partie de l'étape 2 qui n'est pas prouvée.

---

## Étape 3 — Le moteur, sans interface ✅ *(fait — `packages/kameo_engine`)* ⭐

L'étape la plus importante du plan, et celle que personne ne fait dans cet ordre.

Dans `domain/`, en Dart pur, avec des tests unitaires :
- `Lexicon` : chargement, calcul de difficulté, paliers, tirage par difficulté/thème/ville.
- `PlacementEngine` : l'escalier adaptatif du doc 03 §4.2.
- `SrsScheduler` : SM-2+ du doc 02 §5.
- `MasteryModel` : les 4 échelons R1→R4 et leurs transitions.
- `LessonBuilder` : la recette 60/20/20 du doc 02 §6.
- `EventReducer` : journal → état (doc 04 §2).

**Sortie :** ✅ `dart analyze` sans avertissement, **48 tests au vert**, dont :

- placement simulé sur **1 000 apprenants synthétiques** : erreur moyenne 4,2 points, **84 % dans le bon tour, 100 % à un tour près** ;
- la démonstration chiffrée que noter sur toutes les réponses bat la position de l'escalier, et que la précision se paie en questions ;
- SRS : un échec isolé ne fait jamais perdre d'échelon, il en faut trois consécutifs ; monter exige deux réussites espacées de 24 h ;
- réducteur : rejouer un événement ne change rien, un tampon ne redescend jamais, le tour courant ne recule pas même après un placement raté, l'XP est monotone.

Le package est du **Dart pur** : ni Flutter, ni Firebase, ni réseau. Il tourne en 12 secondes.

---

## Étape 4 — Contenu : pack Espagne Tour 1 🚧 *(outillage fait, contenu à produire)*

- Lexique espagnol porté à ~500 lemmes (import fréquentiel + annotation IA + revue, doc 03 §6).
- 6 villes × 4 leçons × ~12 items = **~290 items**, générés par le pipeline, au schéma du doc 02 §8.
- 6 expressions locales + 6 épreuves de tampon.
- **Revue humaine** : les 6 expressions locales et tous les items marqués « piège » sont relus par un natif (Fiverr, ~50 €).
- Audios TTS (voix castillane) générés en lot, stockés dans Firebase Storage.

**Sortie :** ✅ **le pipeline est en place et prouvé de bout en bout** (`tools/`) :

- `validate-content.mjs` — schéma Zod **et** onze règles pédagogiques, sans clé API, branché en CI. Dès son premier passage sur la semence il a trouvé deux vraies erreurs et vingt annotations approximatives ;
- `normalize-lexicon.mjs` — l'opacité est désormais **calculée**, plus annotée (28 lemmes ont changé de palier après recalcul) ;
- `annotate-lexicon.mjs` et `generate-pack.mjs` — annotation et génération sous schéma strict, prompt en cache, vocabulaire fermé ;
- `recalibrate.mjs` — la télémétrie corrige la difficulté ; vérifié sur un jeu synthétique ;
- `emit-difficulty-fixture.mjs` — témoin de parité entre la formule JS et la formule Dart, vérifié en CI ;
- `content/es/packs/2026-08-22_v1/valencia.t1.json` — pack de référence écrit à la main (3 leçons, 17 items, épreuve de tampon), qui traverse le validateur, se charge dans le moteur et compose une vraie leçon (7 tests dédiés).

🔑 **Ce qui reste et qui demande toi** : ta clé API pour lancer la génération des 5 autres villes, l'import fréquentiel pour porter le lexique à ~500 lemmes, la génération des audios TTS, et **la relecture par un natif** des expressions locales. Tant que `humanReviewed` est faux, l'app refuse de servir le pack — c'est volontaire.

---

## Étape 5 — Onboarding + placement ✅ *(fait)*

Écrans A1→A7 du doc 01, branchés sur le vrai `PlacementEngine`.

**Sortie :** ✅ les trois questions du doc 01 (§2 A1–A7), puis le test de placement branché sur le vrai `PlacementEngine` — l'écran ne connaît pas l'algorithme, il pose la question que le moteur lui donne. L'écran de résultat montre le niveau **par compétence**, l'incertitude assumée (« à ±5 points près »), et « je préfère commencer au début » est un vrai bouton.

---

## Étape 6 — La carte et la fiche ville ✅ *(fait — trois destinations)*

Cartes illustrées dessinées au `CustomPainter` depuis le contenu, villes, itinéraire (plein pour le parcouru, pointillé pour le reste), états validée / en cours / verrouillée, bandeau passeport, fiche ville en bottom sheet avec son expression locale prononcée.

**Sortie :** ✅ **trois destinations, pas une** : l'Espagne, le Royaume-Uni et les États-Unis. Chaque pays est un fichier de contenu (contour + villes + expressions), aucune géométrie n'est codée en dur. Un test vérifie que **chaque ville tombe bien à l'intérieur de son contour**.

Et surtout, la destination n'est pas cosmétique : elle porte une **variante de langue**. Le répertoire anglais contient 25 mots qui n'existent que d'un côté de l'Atlantique (*the tube* / *subway*, *pavement* / *sidewalk*, *chips* qui veut dire frites à Londres et chips à New York). Partir à New York filtre le vocabulaire britannique, et l'accent des voix suit (`en-GB` contre `en-US`).

---

## Étape 7 — Le moteur d'exercices 🚧 *(vocabulaire fait, phrases à venir)* ⭐

- **Écrire** : banque de mots, saisie libre, texte à trous, tolérance aux accents et à la ponctuation.
- **Écouter** : dictée, QCM audio, contrôle de vitesse (×0,75).
- **Parler** : répétition + `speech_to_text` + comparaison indulgente (doc 02 §9).
- Barre de progression, cœurs, sélection d'un mot difficile **en un appui long**, écran de fin.

**Sortie partielle :** ✅ **l'apprentissage du vocabulaire tourne, sans aucun contenu rédigé.** Les exercices sont fabriqués depuis le répertoire par le moteur (`DrillBuilder`) : reconnaître, retrouver, écouter. Une ville se valide en assimilant son vocabulaire (doc 02 §6 bis), pas en enchaînant des leçons.

Reste à faire : les exercices sur **phrases** — traduction avec banque de mots, texte à trous, répétition orale notée. Ceux-là demandent du contenu rédigé, donc le pipeline IA.

---

## Étape 8 — Tampons, passeport, cérémonie *(~1 semaine)*

Épreuve de tampon, animation de tamponnage (haptique + son), page de passeport, visa de tour.

**Sortie :** obtenir un tampon procure une vraie satisfaction. Test simple : tu as envie de le refaire.

---

## Étape 9 — Carnet de mots et révision *(~1 semaine)*

Liste avec contexte de ville, niveau de maîtrise, session express de 3 minutes, pastille de mots dus.

**Sortie :** un mot ajouté aujourd'hui revient demain, au bon échelon.

---

## Étape 10 — Économie, compte, serveur *(~1,5 semaine)*

- XP, gemmes, cœurs, streak et ses gels — **paramétrés dans Remote Config**, pas dans le code.
- Cloud Functions : `submitLessonResult`, `awardStamp`, `validateTour` (D6 du doc 04).
- Écran de création de compte au bon moment (A10/A11), `linkWithCredential`.
- Suppression de compte + export RGPD.
- Les 25 événements analytics du doc 01 §7.

**Sortie :** deux appareils avec le même compte convergent vers le même état. Un client modifié ne peut pas s'attribuer d'XP.

---

## Étape 11 — Finition *(~1 semaine)*

Vides, erreurs, hors-ligne, lenteurs, accessibilité (contrastes, tailles de police, VoiceOver sur les boutons), 60 fps sur la carte, taille de l'app, temps de démarrage < 2 s.

**Sortie :** aucun écran ne peut afficher un spinner infini. Ta checklist Carnet s'applique ici telle quelle.

---

## Étape 12 — Bêta fermée *(~2 semaines)*

Firebase App Distribution, 20 à 30 testeurs (familles CH/FR), formulaire court, une session d'observation en direct avec 3 personnes — **regarder quelqu'un utiliser l'app sans l'aider est ce qui apprend le plus**.

**Sortie :** on a les chiffres du funnel réel et une liste triée des 10 vrais problèmes.

---

## Étape 13 — Décision *(1 jour)*

Face aux KPIs de la spec §9 (activation > 60 %, D7 > 20 %, complétion Tour 1 > 15 %) :
- **Ça tient** → phase 2 : Tour 2, paywall RevenueCat, partage social, stores.
- **Ça ne tient pas** → on corrige la boucle avant de monétiser. Un paywall sur une rétention faible ne produit rien.

---

## Vue d'ensemble

```
S1   ▓ Étape 0-1   valider · prototype
S2   ▓ Étape 2     fondations
S3-4 ▓ Étape 3     LE MOTEUR (tests d'abord)          ⭐
S4-5 ▓ Étape 4     contenu Espagne T1        (parallèle)
S5   ▓ Étape 5     onboarding + placement
S6   ▓ Étape 6     carte + ville
S7-8 ▓ Étape 7     exercices                          ⭐
S9   ▓ Étape 8     tampons + passeport
S10  ▓ Étape 9     carnet + révision
S11  ▓ Étape 10    économie + serveur + compte
S12  ▓ Étape 11    finition
S13-14 ▓ Étape 12  bêta
S14  ▓ Étape 13    décision
```

**≈ 14 semaines à temps partiel**, contre les 8–10 annoncées dans la spec. L'écart vient de l'étape 3 (le moteur testé avant l'UI) et de l'étape 4 (le contenu revu par un natif). Ces deux-là sont exactement ce qui évite de tout reprendre au moment d'ajouter la 2ᵉ langue.

---

## Ce qui n'est PAS dans le MVP

Angleterre · Tours 2+ · paywall · conversations IA · ligues · profils famille · partage social · notifications push · widget · mode enfant.

Chacun est **prévu par la structure** (doc 04) mais aucun n'est nécessaire pour répondre à la seule question qui compte : *est-ce que voyager donne envie d'apprendre tous les jours ?*
