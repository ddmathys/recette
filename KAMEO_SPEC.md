# KAMEO — Spécification produit & technique

> App mobile d'apprentissage des langues par le voyage.
> Tu choisis une destination, tu voyages de ville en ville, chaque ville t'apprend ses spécificités. Chaque tour complet du pays = un niveau validé dans ton passeport.

**Statut** : Spec v1.0 — pré-développement
**Owner** : David
**Stack cible** : Flutter + Firebase (Firestore, Auth, Cloud Functions), API Claude pour la génération de contenu, RevenueCat pour les abonnements.

---

## 1. Concept

### 1.1 Pitch

Kameo transforme l'apprentissage d'une langue en voyage. Au lieu d'un parcours linéaire abstrait (Duolingo), l'utilisateur **voyage sur une carte du pays** de la langue apprise : l'espagnol s'apprend en traversant l'Espagne (Barcelone, Valence, Madrid, Séville, Grenade, Bilbao), l'anglais en traversant l'Angleterre ou les USA.

Chaque ville enseigne **ses spécificités culturelles et linguistiques** : la cuisine à Valence, le foot à Bilbao, la vie urbaine à Madrid, les pubs à Londres. On n'apprend pas des listes de mots, on apprend à *vivre* dans la langue.

### 1.2 Mascotte & identité

- **Kameo**, un caméléon voyageur : il change de couleur comme l'utilisateur change de langue. Il s'adapte à chaque environnement — c'est la métaphore du polyglotte.
- Direction visuelle : **pop & fun famille**, couleurs bonbon sur fond crème.
- Palette : crème `#FDF8EF`, encre `#33305E`, corail `#FF6B5E`, soleil `#FFC63F`, raisin `#7C4DFF`, lagon `#00C9A7`, ciel `#3EA8FF`.
- Typo : **Fredoka** (display, arrondie) + **Nunito** (texte).

### 1.3 Cible

- **Tout public famille** (8–99 ans), marchés **Suisse romande + France** en priorité.
- Langue de l'interface : français (i18n prévu dès le départ : EN, DE).
- Langues apprises au lancement (MVP) : **espagnol, anglais** (2 destinations pour l'anglais : Angleterre, USA).

---

## 2. Boucle de jeu principale (core loop)

```
Choisir destination → Voyager de ville en ville → Faire les leçons d'une ville
→ Obtenir le TAMPON de la ville → Compléter le tour du pays
→ VALIDER LE NIVEAU (page de passeport complète) → Repartir pour un tour plus difficile
```

### 2.1 Système de niveaux par tours (mécanique "prestige")

C'est LA mécanique différenciante de Kameo :

- Le pays se parcourt en **tours successifs**. Chaque tour = un **niveau**.
- **Tour 1 (Niveau 1)** : mêmes villes, contenu survie/débutant.
- **Tour 2 (Niveau 2)** : on refait le tour des mêmes villes, mais le contenu est **plus difficile** et **plus profond** (nouveaux dialogues, temps du passé, expressions idiomatiques).
- Et ainsi de suite. Les villes sont familières, le contenu se renouvelle.

**Correspondance CECR** (crédibilité pédagogique, argument marketing CH/FR) :

| Tour | Niveau Kameo | CECR | Contenu type | Couleur tampon |
|------|--------------|------|--------------|----------------|
| 1 | Explorateur | A1 | Survie : se présenter, commander, se repérer | Bronze |
| 2 | Voyageur | A2 | Conversation courante, passé, préférences | Argent |
| 3 | Aventurier | B1 | Nuances, opinions, récits, idiomes | Or |
| 4 | Local | B2 | Débats, humour, registres de langue | Platine |
| 5 | Ambassadeur | C1 | Subtilités, culture profonde, accents régionaux | Diamant |

### 2.2 Validation d'un niveau

- Chaque ville terminée au niveau courant = **1 tampon** dans le passeport.
- **Valider le niveau = obtenir TOUS les tampons du pays** → la page de passeport du niveau est complète → cérémonie de validation (animation, badge, partage social).
- **Anti-frustration** : le tour suivant se **débloque à N-1 villes** (ex. 5/6 en Espagne). La dernière ville reste accessible en rattrapage, mais la page de passeport (et ses récompenses bonus) n'est complète qu'à 100 %. On sépare *progression* (fluide) et *complétion* (exigeante, récompensée).

### 2.3 Progression dans une ville

Chaque ville contient au niveau courant :

- **3 à 5 leçons thématiques** liées à la spécialité de la ville (ex. Valence N1 : "Commander une paella", "Les goûts", "Au marché").
- **1 expression locale signature** à débloquer (ex. « ¡Qué guay! », « Mind the gap! ») — collectionnable.
- **1 épreuve de tampon** (boss de fin de ville) : mini-scénario mixant écrit + oral + écoute. Réussite = tampon.

---

## 3. Modes d'exercice

Trois compétences travaillées, présentes dans chaque leçon :

### 3.1 ✍️ Écrire
- Traduction par assemblage de mots (word bank), puis saisie libre aux niveaux supérieurs.
- Textes à trous, réorganisation de phrases.

### 3.2 🎙️ Parler
- Répétition de phrases avec analyse de prononciation (speech-to-text + scoring).
- Aux niveaux ≥ 2 : **mini-conversations avec Kameo** (dialogue IA sur le thème de la ville — voir §6 API Claude).
- MVP : `speech_to_text` (package Flutter) + comparaison phonétique simple. V2 : scoring de prononciation dédié.

### 3.3 🎧 Écouter
- Dictée (audio → écrire ce qu'on entend).
- Compréhension : audio + QCM.
- TTS : voix natives par destination (accent anglais UK vs US selon la destination choisie — cohérent avec le concept !).

### 3.4 Rythme
- **Session quotidienne** proposée (objectif du jour paramétrable : 1 à 5 leçons).
- **À la demande** : tout est accessible à tout moment, y compris la révision.

---

## 4. Gamification

### 4.1 Économie

| Élément | Rôle | Gagné via | Dépensé pour |
|---------|------|-----------|--------------|
| **XP** | Progression du profil global | Toute activité | — (niveau de profil) |
| **Gemmes 💎** | Monnaie douce | Leçons parfaites, streaks, tampons | Gel de streak, tenues de Kameo, indices |
| **Cœurs ❤️** | Vies (5 max, régén. 1/4h) | Temps, révision de mots, gemmes | Perdus sur erreur (version gratuite) |
| **Streak 🔥** | Rétention quotidienne | 1 leçon/jour minimum | — |

### 4.2 Le passeport 🛂 (signature du produit)

- **1 page de passeport par niveau et par pays.** Chaque page contient les emplacements de tampons des villes.
- Tampon obtenu = animation de tamponnage satisfaisante (haptics + son).
- Couleur du tampon = niveau (bronze/argent/or/platine/diamant).
- **Partage social** : export image de la page de passeport (format Stories/TikTok) — levier d'acquisition organique majeur.
- Visa de niveau : quand la page est complète, un grand visa décoratif est apposé.

### 4.3 Bibliothèque de mots difficiles 📚

- **N'importe quel mot rencontré est sélectionnable** (appui long ou tap sur mot souligné) → ajouté à "Mes mots difficiles".
- Chaque mot garde son **contexte de voyage** : "📍 appris à Madrid, leçon Le métro".
- **Révision espacée** (algorithme SM-2 simplifié) : sessions express de 3 min, mots triés par urgence de révision.
- Niveau de maîtrise par mot (0–3 points), un mot maîtrisé 3× sort du cycle actif.

### 4.4 Social & rétention

- **Ligues hebdomadaires** (classement par XP, promotion/relégation) — V2.
- **Badges de voyage** : "7 jours", "1er tampon", "Espagne 100 %", "3 pays", "50 oraux"...
- **Défis famille** (V2) : un foyer, plusieurs profils, défi commun de la semaine — cohérent avec la cible famille.

---

## 5. Écrans (MVP)

1. **Onboarding** : choix langue → destination → test de placement optionnel (permet de commencer au Tour 2 si niveau réel A2) → objectif quotidien.
2. **Carte du voyage** (home) : sélecteur de destination, carte stylisée du pays avec itinéraire pointillé, villes (validée ✓ / en cours ★ pulsante / verrouillée 🔒), carte "Étape en cours", strip passeport.
3. **Fiche ville** (bottom sheet) : spécialité, expression locale (audio), progression leçons, CTA.
4. **Leçon / Exercice** : barre de progression + cœurs, onglets Écrire/Parler/Écouter, sélection de mots difficiles inline, écran de fin (+XP, +gemmes, progression tampon).
5. **Bibliothèque de mots** : liste avec contexte de ville, maîtrise, bouton "Réviser X mots · 3 min".
6. **Profil** : niveau global, stats (streak, tampons, mots), calendrier de semaine, badges, (ligue en V2).
7. **Passeport** (plein écran) : pages par pays/niveau, partage social.

Maquettes interactives : voir `design/kameo-maquette-v2.jsx` (React, à conserver comme référence visuelle).

---

## 6. Architecture technique

### 6.1 Stack

- **Flutter** (iOS + Android) — réutilisation des acquis Carnet (Firebase, patterns, CI/CD).
- **Firebase** : Auth (anonyme → email/Google/Apple), Firestore, Cloud Functions (génération de contenu, validation anti-triche), Remote Config (tuning de l'économie sans release), Analytics + Crashlytics.
- **API Claude** via Cloud Functions (jamais d'appel direct client → clé protégée) :
  - Génération des leçons par (langue, ville, thème, niveau CECR) — voir §6.3.
  - Mini-conversations orales niveau ≥ 2.
  - Explications grammaticales à la demande ("Pourquoi cette réponse ?").
- **TTS/STT** : MVP avec TTS cloud (voix par accent) + `speech_to_text`; scoring prononciation dédié en V2.
- **Paiements** : RevenueCat (abonnements cross-platform, essai gratuit, paywall A/B testable).

### 6.2 Modèle de données Firestore (simplifié)

```
/content/{lang}/countries/{countryId}
  name, flag, mapAsset, cities: [cityId...]

/content/{lang}/countries/{countryId}/cities/{cityId}
  name, emoji, theme, position {x,y}, order

/content/{lang}/countries/{countryId}/cities/{cityId}/levels/{tourN}/lessons/{lessonId}
  title, type, exercises: [
    { kind: "translate|speak|listen|gap|dialogue", prompt, answer,
      wordBank: [...], audioRef, difficultWords: [{word, translation}] }
  ]
  localExpression: { text, translation, audioRef }
  stampChallenge: { exercises: [...] }

/users/{uid}
  displayName, uiLang, dailyGoal, streak, streakFreezeCount,
  xp, gems, hearts { count, lastRefill }, createdAt

/users/{uid}/journeys/{lang_countryId}
  currentTour, unlockedCities: [...],
  stamps: { cityId: { tour: n, earnedAt } },
  passportPages: { tourN: complete|partial }

/users/{uid}/vocab/{wordId}
  word, translation, lang, cityId, lessonId, mastery (0-3),
  nextReviewAt, easeFactor, addedAt
```

**Règles clés** : contenu en lecture seule côté client ; toute écriture de progression validée par Cloud Function (anti-triche sur XP/gemmes) ; vocab en écriture directe utilisateur (faible enjeu).

### 6.3 Pipeline de contenu par IA (le vrai levier de scalabilité)

Le contenu n'est **pas généré en temps réel** côté utilisateur (coût, latence, contrôle qualité). Pipeline en 3 temps :

1. **Génération** (script + Cloud Function admin) : prompt structuré → Claude génère un pack ville complet en JSON `(langue, ville, thème, niveau CECR, nb leçons)` avec schéma strict.
2. **Revue** : validation manuelle (toi + éventuellement un natif via Fiverr pour les expressions locales) avant publication dans `/content`.
3. **Publication** : versionnée, Remote Config pointe la version active.

→ Ajouter une langue = ajouter un pays, ses villes, et lancer le pipeline. **Coût marginal quasi nul**, c'est ça qui rend Kameo scalable sur les langues là où Duolingo a des équipes de contenu.

Exception temps réel : les **mini-conversations** (Parler, niveau ≥ 2) passent par l'API en live, réservées aux abonnés Premium (le coût API devient un argument de pricing).

### 6.4 CI/CD

- GitHub Actions → Firebase App Distribution (bêta) puis stores — pipeline identique à Éclosion.
- Flavors dev/prod, Remote Config par environnement.

---

## 7. Monétisation

### 7.1 Freemium

**Gratuit** :
- Tour 1 complet d'une destination (toute la valeur A1 — génère l'attachement au passeport).
- Cœurs limités (5, régénération lente).
- Bibliothèque de mots plafonnée (30 mots).

**Kameo Premium** (abonnement) :
- Cœurs illimités.
- **Tours 2+** (déblocage des niveaux supérieurs) — c'est le mur de paiement principal, aligné sur la valeur perçue ("je veux continuer mon voyage").
- Conversations IA avec Kameo (Parler avancé).
- Mots illimités + statistiques de révision.
- Toutes les destinations en parallèle.

### 7.2 Pricing (hypothèses à tester)

- Mensuel : **9.90 CHF / 9.99 €**
- Annuel : **59 CHF / 59 €** (~50 % de réduction, plan poussé)
- **Famille** : 89 CHF/an jusqu'à 4 profils — différenciateur fort vs Duolingo pour la cible famille, et panier moyen supérieur.
- Essai gratuit 7 jours sur l'annuel.

### 7.3 Acquisition

- **TikTok/Instagram** (réutiliser les acquis Carnet) : formats "expression locale du jour" par ville, partages de pages de passeport, duos "prononce ça".
- **Build in public** LinkedIn : le pipeline de contenu IA est une super histoire à raconter.
- ASO : `Kameo : apprendre en voyageant` — mots-clés voyage + langue, moins concurrentiels que "apprendre l'anglais" seul.
- Marché CH : angle CECR + multilinguisme suisse (l'allemand comme destination V2 : Berlin, Munich, Zurich ? 😉).

---

## 8. Roadmap

### Phase 1 — MVP (8–10 semaines à temps partiel)
- [ ] Setup projet Flutter + Firebase + CI/CD
- [ ] Onboarding + Auth anonyme
- [ ] Carte Espagne (6 villes) + fiche ville + passeport Tour 1
- [ ] Moteur d'exercices : Écrire (word bank, gap) + Écouter (dictée, QCM)
- [ ] Parler v1 : répétition + STT basique
- [ ] Bibliothèque de mots + révision espacée
- [ ] Économie : XP, gemmes, cœurs, streak
- [ ] Pipeline contenu Claude → pack Espagne Tour 1 complet
- [ ] Analytics des événements clés (funnel leçon, D1/D7)

### Phase 2 — Bêta & monétisation (4–6 semaines)
- [ ] Tours 2 (Espagne) + destination Angleterre Tour 1
- [ ] Paywall RevenueCat + Premium
- [ ] Partage social du passeport
- [ ] Bêta fermée (Firebase App Distribution) : 30–50 testeurs, cible familles CH/FR
- [ ] Cérémonie de validation de niveau (animation)

### Phase 3 — Croissance
- [ ] USA, tours 3+, conversations IA
- [ ] Ligues, défis famille
- [ ] Destination Allemagne (marché suisse)
- [ ] Localisation UI EN/DE

---

## 9. KPIs

| Métrique | Cible MVP |
|----------|-----------|
| Activation (1 leçon terminée J0) | > 60 % |
| Rétention D1 / D7 / D30 | 40 % / 20 % / 10 % |
| Taux de complétion Tour 1 | > 15 % |
| Conversion free → Premium (à la fin du Tour 1) | 3–5 % |
| Mots ajoutés / utilisateur actif / semaine | > 5 |
| Partages de passeport / 100 validations de niveau | > 10 |

---

## 10. Risques & points ouverts

- **Qualité du contenu généré** : la revue humaine des expressions locales est indispensable (une expression fausse détruit la crédibilité "authentique" du concept).
- **Coût API conversations live** : réservé Premium + plafond mensuel par utilisateur.
- **Scoring prononciation** : le STT simple du MVP sera indulgent ; à assumer dans la comm ("Kameo t'encourage") puis améliorer.
- **Cartes** : cartes stylisées dessinées (SVG), pas de vraies cartes géo — assumer le style illustré, plus chaleureux et sans licence.
- **Nom & marque** : vérifier disponibilité "Kameo" (App Store, domaine, marque CH/EU) avant tout investissement branding.

---

*Fichier de référence pour le développement. À faire évoluer à chaque décision produit — les maquettes font foi pour l'UI.*
