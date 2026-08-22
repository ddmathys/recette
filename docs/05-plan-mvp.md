# 05 — Plan MVP, de la première à la dernière étape

> Statut : proposition v1
> Format : 13 étapes numérotées, chacune avec un livrable vérifiable et une **condition de sortie**.
> Rythme supposé : temps partiel, ~10 h/semaine. Les durées sont des ordres de grandeur, pas des engagements.

**Règle du plan : on ne passe pas à l'étape N+1 tant que la condition de sortie de N n'est pas remplie.** C'est ce qui empêche d'accumuler du travail à moitié fini — l'équivalent, au niveau du projet, de la règle « pas de retour en arrière ».

---

## Étape 0 — Valider ces documents *(cette semaine, avec toi)*

Rien à coder. Tu lis les docs 01 à 04 et tu tranches les points ouverts :
- doc 01 §8 : test de placement avant ou après la 1ʳᵉ leçon · méthodes de connexion · classification d'âge
- doc 02 : les 5 niveaux et leurs descripteurs · le seuil de validation par compétence
- doc 03 : la formule de difficulté et les 6 paliers
- doc 04 : les 6 décisions gelées

**Sortie :** les docs sont amendés et validés. Tout le reste en découle.

---

## Étape 1 — Le prototype cliquable *(fait — voir `prototype/`)*

Un parcours complet jouable dans un navigateur : test de placement adaptatif réel (sur les 130 lemmes), carte d'Espagne, fiche ville, leçon à 3 exercices, tampon, passeport.

**Ce n'est pas l'app.** C'est l'outil pour décider avant de coder : est-ce que la boucle donne envie ? est-ce que le placement tombe juste ? est-ce que la carte est lisible ?

**Sortie :** tu as joué le parcours 3 fois et tu sais ce que tu veux changer.

---

## Étape 2 — Fondations techniques *(~1 semaine)*

- Projet Flutter, flavors `dev` / `prod`, `analysis_options` strict.
- Firebase : projet dev + projet prod, Auth anonyme, Firestore, Remote Config, Crashlytics.
- Design system Kameo : couleurs, Fredoka/Nunito, `KButton`, `KCard`, `KProgress`, haptiques.
- CI GitHub Actions : `flutter analyze` + `flutter test` sur chaque push.
- Arborescence du doc 04 §5, avec `domain/` vide mais isolé.

**Sortie :** un écran blanc au thème Kameo tourne sur ton téléphone, la CI est verte.

---

## Étape 3 — Le moteur, sans interface *(~1,5 semaine)* ⭐

L'étape la plus importante du plan, et celle que personne ne fait dans cet ordre.

Dans `domain/`, en Dart pur, avec des tests unitaires :
- `Lexicon` : chargement, calcul de difficulté, paliers, tirage par difficulté/thème/ville.
- `PlacementEngine` : l'escalier adaptatif du doc 03 §4.2.
- `SrsScheduler` : SM-2+ du doc 02 §5.
- `MasteryModel` : les 4 échelons R1→R4 et leurs transitions.
- `LessonBuilder` : la recette 60/20/20 du doc 02 §6.
- `EventReducer` : journal → état (doc 04 §2).

**Sortie :** `flutter test` passe, avec au minimum : un placement simulé sur 1 000 profils synthétiques qui converge, un SRS qui produit les bons intervalles, un réducteur idempotent (rejouer deux fois le même événement ne change pas l'état).

---

## Étape 4 — Contenu : pack Espagne Tour 1 *(~1 semaine, en parallèle possible)*

- Lexique espagnol porté à ~500 lemmes (import fréquentiel + annotation IA + revue, doc 03 §6).
- 6 villes × 4 leçons × ~12 items = **~290 items**, générés par le pipeline, au schéma du doc 02 §8.
- 6 expressions locales + 6 épreuves de tampon.
- **Revue humaine** : les 6 expressions locales et tous les items marqués « piège » sont relus par un natif (Fiverr, ~50 €).
- Audios TTS (voix castillane) générés en lot, stockés dans Firebase Storage.

**Sortie :** le pack charge dans le moteur de l'étape 3 et un test génère 20 leçons différentes sans erreur de schéma.

---

## Étape 5 — Onboarding + placement *(~1 semaine)*

Écrans A1→A7 du doc 01, branchés sur le vrai `PlacementEngine`.

**Sortie :** sur un téléphone, en 5 minutes, un inconnu arrive à la carte avec un niveau estimé et un carnet pré-rempli.

---

## Étape 6 — La carte et la fiche ville *(~1 semaine)*

Carte d'Espagne en SVG illustré, 6 villes, itinéraire pointillé, états (validée / en cours / verrouillée), bandeau passeport, bottom sheet de ville.

**Sortie :** la carte est belle sur un petit écran (iPhone SE) comme sur une tablette. C'est l'écran signature : il doit donner envie tout seul, sans explication.

---

## Étape 7 — Le moteur d'exercices *(~2 semaines)* ⭐

- **Écrire** : banque de mots, saisie libre, texte à trous, tolérance aux accents et à la ponctuation.
- **Écouter** : dictée, QCM audio, contrôle de vitesse (×0,75).
- **Parler** : répétition + `speech_to_text` + comparaison indulgente (doc 02 §9).
- Barre de progression, cœurs, sélection d'un mot difficile **en un appui long**, écran de fin.

**Sortie :** une leçon complète se joue de bout en bout, hors-ligne, sans crash, en < 4 minutes.

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
