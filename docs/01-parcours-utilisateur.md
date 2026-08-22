# 01 — Parcours utilisateurs

> Statut : proposition v1 · à valider avant toute ligne de code
> Portée : compte, onboarding, placement, reprise, multi-appareil, RGPD.

---

## 0. Principes directeurs

Quatre principes qui décident de tout le reste. Si on en change un plus tard, on repaie cher.

| # | Principe | Conséquence concrète |
|---|----------|----------------------|
| **P1** | **Aucun mur avant la valeur.** On ne demande jamais de compte pour essayer. | Auth anonyme silencieuse au 1er lancement. |
| **P2** | **La progression ne se perd jamais.** | Journal d'événements append-only côté serveur (doc 04), pas d'état écrasable. |
| **P3** | **Le compte se demande au pic émotionnel**, pas au démarrage. | L'invitation à créer un compte arrive juste après le **1er tampon**. |
| **P4** | **Un compte porte N profils dès le jour 1** (structure, pas forcément UI). | `users/{uid}/profiles/{pid}` existe au MVP avec un seul profil. Le plan Famille (§7.2 de la spec) n'imposera aucune migration. |

---

## 1. Machine à états du compte

```
        signInAnonymously()          linkWithCredential()          RevenueCat
[néant] ────────────────► ANONYME ──────────────────────► IDENTIFIÉ ──────────► PREMIUM
                             │                                │                    │
                             │ désinstallation                │ déconnexion        │ fin d'abo
                             ▼                                ▼                    ▼
                        PERDU (irrécupérable)            IDENTIFIÉ (autre appareil)  IDENTIFIÉ
```

Points non négociables :

- Le passage **ANONYME → IDENTIFIÉ** se fait par `linkWithCredential` : **l'`uid` ne change pas**. Toute la progression reste en place, aucun transfert de données, aucun risque de doublon.
- **PERDU** est le seul état destructeur : un utilisateur anonyme qui désinstalle perd tout. C'est exactement ce que P3 sert à éviter. On mesure ce taux (`account_lost_estimated`) dès le MVP.
- Un profil supprimé est **archivé 30 jours** avant purge (annulation possible, exigence RGPD satisfaite quand même).

---

## 2. Parcours A — Premier lancement

| Étape | Écran | Ce que l'utilisateur fait | Ce que le système fait |
|-------|-------|---------------------------|------------------------|
| A1 | Splash | rien (1,5 s) | `signInAnonymously()` → `uid`. Crée `users/{uid}` + `profiles/default`. Charge le pack de contenu actif via Remote Config. |
| A2 | « Quelle langue veux-tu vivre ? » | Espagnol / Anglais | `profile.targetLang` |
| A3 | « Où veux-tu voyager ? » | Espagne (🇪🇸) — Angleterre / USA pour l'anglais | `profile.destination`. La destination détermine l'**accent des voix TTS** : c'est le premier moment où le concept se prouve. |
| A4 | « Tu pars d'où ? » | 3 réponses : *Zéro / Quelques bases / Je me débrouille* | Aiguille vers le test ou non |
| A5 | Test de placement (voir doc 03) | ~4 min, **sautable à tout moment** | Estime un niveau **par compétence**, pas un score global |
| A6 | Résultat | « Tu démarres **Voyageur (A2)** — et 47 mots sont déjà dans ton carnet » | Crée le `journey`, pré-crédite le vocabulaire reconnu |
| A7 | Objectif quotidien | Tranquille (1 leçon) / Régulier (2) / Intense (4) | `profile.dailyGoal` — modifiable, jamais punitif |
| A8 | **Carte** | Voit le pays, les villes, l'itinéraire | Première fois qu'il voit le produit. C'est le moment « ah, d'accord ». |
| A9 | Leçon 1 | ~3 min | +XP, +gemmes. **Toujours aucun compte demandé.** |
| A10 | Épreuve de tampon | | Cérémonie de tamponnage (haptique + son) |
| A11 | **« Sauvegarde ton passeport »** | Apple / Google / e-mail | `linkWithCredential`. Refus possible → l'app continue normalement. |

**Règle A11 :** si l'utilisateur refuse, on ne redemande pas avant : (a) le 2ᵉ tampon, (b) le lendemain à l'ouverture, (c) un bandeau discret et permanent dans le Profil. **Jamais de modale bloquante.**

### Pourquoi A4 avant A5
Proposer un test à un vrai débutant est décourageant (« je ne sais rien »). Proposer de sauter le test à quelqu'un qui a 5 ans d'espagnol scolaire est frustrant (« je vais devoir refaire *hola* »). La question A4 coûte 3 secondes et évite les deux.

---

## 3. Parcours B — Retour quotidien

1. Ouverture → restauration silencieuse de la session (le token Firebase persiste).
2. **Recalcul local** : cœurs régénérés, streak (voir §6), mots dus à réviser.
3. Atterrissage sur la **Carte**, avec la carte « Étape en cours » en avant.
4. Si des mots sont dus : pastille sur le carnet + proposition « Révise 8 mots · 3 min » — **jamais imposée**.

---

## 4. Parcours C — Nouvel appareil / réinstallation

| Cas | Résultat | Traitement |
|-----|----------|------------|
| Compte identifié | Reconnexion → **restauration complète** depuis Firestore | Écran « On récupère ton passeport… », rejoue l'état serveur |
| Compte anonyme | **Progression perdue** | Message honnête, pas de faux espoir : « On n'a pas retrouvé de passeport sur cet appareil. » + proposition de repartir avec un test de placement pour ne pas tout refaire |
| Compte identifié, 2 appareils simultanés | Dernier écrivain gagne **au niveau événement, pas au niveau état** | Le journal append-only (doc 04) rend ce cas inoffensif : deux appareils produisent des événements disjoints, le réducteur serveur fusionne. |

C'est précisément là que l'architecture « pas de retour en arrière » paie : **aucun scénario multi-appareil ne peut faire régresser un passeport.**

---

## 5. Parcours D à H

### D — Ajouter une destination / une langue
Depuis le sélecteur en haut de la Carte. Chaque couple `(langue, pays)` = un **journey** indépendant, avec son passeport et son tour courant. Le carnet de vocabulaire est **par langue**, pas par pays (Barcelone et Mexico nourrissent le même espagnol).

### E — Profils multiples (V2, structuré aujourd'hui)
Un `user` (le compte payant) contient N `profiles`. Chaque profil a ses journeys, son passeport, son carnet. Au MVP : 1 profil, créé automatiquement, jamais montré. En V2 : sélecteur de profil au lancement, plan Famille. **Aucune migration de données** puisque le chemin `users/{uid}/profiles/{pid}/...` existe depuis le premier commit.

### F — Premium
Le paywall n'apparaît **jamais pendant une leçon**. Trois points de contact :
1. Fin du **Tour 1** (mur principal — la valeur est prouvée, l'attachement au passeport est créé).
2. Cœurs à zéro (proposition, avec toujours une alternative gratuite : attendre, ou réviser des mots pour regagner un cœur).
3. Onglet Profil, permanent et calme.

### G — Suppression de compte (obligation App Store)
Accessible en 2 taps depuis le Profil. Supprime : profils, journeys, vocab, événements. Conserve 30 jours en zone d'archive, puis purge définitive par Cloud Function. Export des données sur demande (RGPD, e-mail avec JSON).

### H — Hors-ligne
Le contenu de la **ville en cours** est pré-téléchargé (pack JSON + audios). Une leçon jouée hors-ligne produit des événements mis en file locale, envoyés à la reconnexion. Le tampon n'est **délivré qu'après validation serveur** (anti-triche), mais l'UI l'affiche en « en attente » plutôt que de bloquer.

---

## 6. Deux règles anti-frustration à graver

**1. Le streak ne se perd pas en silence.** Un streak perdu est la première cause de désinstallation chez les concurrents. Règles Kameo :
- 1 gel de streak automatique offert tous les 10 jours (max 2 en réserve).
- Le week-end compte pour 1 jour si l'objectif hebdomadaire est atteint (option « rythme famille »).
- Notification à J+0 22 h **uniquement si** l'utilisateur a joué la veille (sinon c'est du harcèlement).

**2. Rien de gagné ne se reprend.** Voir doc 02 §5 — c'est structurel, pas cosmétique.

---

## 7. Évènements analytics à poser dès le MVP

Sans ces événements, on pilotera à l'aveugle. Ils sont peu nombreux et suffisent au funnel complet.

```
app_first_open · lang_selected · destination_selected · placement_started
placement_completed {level, per_skill, items, duration} · placement_skipped
onboarding_completed · lesson_started {city, tour, lessonId}
lesson_completed {score, hearts_lost, duration} · lesson_abandoned {at_exercise}
word_saved {word, city} · review_session_completed {n, accuracy}
stamp_earned {city, tour} · tour_completed {tour} · passport_shared
account_link_prompted {trigger} · account_linked {method} · account_link_dismissed
paywall_shown {trigger} · trial_started · subscription_started {plan}
```

---

## 8. Décisions ouvertes (à trancher avec toi)

1. **Test de placement au 1er lancement ou après la 1ʳᵉ leçon ?** Je recommande *avant* (l'utilisateur qui a des bases décroche s'il doit d'abord subir « hola = bonjour »), mais on peut A/B tester.
2. **E-mail/mot de passe au MVP ?** Je recommande **Apple + Google uniquement** au départ : moins de code, moins de support, pas de reset de mot de passe à écrire. E-mail en V2 si besoin.
3. **Âge minimum / mode enfant.** Cible « 8–99 ans » = App Store demandera une classification et potentiellement du COPPA/RGPD-K. À trancher avant la soumission, pas avant le code.
