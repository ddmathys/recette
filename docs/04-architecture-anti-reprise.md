# 04 — Architecture : les décisions qu'on ne veut pas refaire

> Statut : proposition v1 · réponse directe à « une structure intelligente pour ne pas devoir revenir en arrière ».

---

## 1. Ce qui coûte cher quand on se trompe

Dans une app de ce type, refaire coûte cher sur exactement **six points**. Le reste se refactorise tranquillement. Voici les six, et la décision proposée pour chacun.

| # | Décision | Si on se trompe | Décision proposée |
|---|---|---|---|
| **D1** | Forme des identifiants de contenu | Toutes les progressions utilisateurs pointent dans le vide | IDs **stables, lisibles, jamais réutilisés** : `es.valencia.t1.paella.04` |
| **D2** | Où vit la progression | Migration de données vivantes = risque de perte | **Journal d'événements append-only** + état dérivé recalculable |
| **D3** | Chemin du profil utilisateur | Ajouter le plan Famille = tout déplacer | `users/{uid}/profiles/{pid}/…` **dès le premier commit** |
| **D4** | Versionnement du contenu | Corriger une faute casse la progression en cours | Packs **immuables et versionnés**, pointeur d'activation |
| **D5** | Ce qu'on enregistre des réponses | On ne peut pas reconstruire un historique qu'on n'a pas | On journalise **chaque réponse** (item, résultat, latence) dès J1 |
| **D6** | Qui calcule les récompenses | XP triché, impossible à corriger a posteriori | XP / gemmes / tampons **écrits uniquement par Cloud Function** |

Le reste — l'UI, la navigation, le moteur d'exercices, le thème, l'économie, les prix — peut changer autant qu'on veut. **Ce sont ces six-là qu'on gèle maintenant.**

---

## 2. D2 en détail : le journal d'événements

C'est la pièce centrale. Au lieu de stocker « l'utilisateur a 2 340 XP » et de l'écraser, on stocke **ce qui s'est passé**, et on en déduit l'état.

```
/users/{uid}/profiles/{pid}/events/{eventId}     ← APPEND ONLY, jamais modifié, jamais supprimé
   { type: "lesson_completed", ts, payload: {...}, clientId, v: 1 }

/users/{uid}/profiles/{pid}/state                ← DÉRIVÉ, recalculable à tout moment
   { xp, gems, hearts, streak, journeys{...}, updatedAt, lastEventId }
```

Types d'événements (le vocabulaire du système, à figer maintenant) :

```
lesson_completed · exercise_answered · stamp_earned · tour_validated
word_saved · word_reviewed · placement_completed · heart_spent · heart_refilled
streak_extended · streak_frozen · purchase_completed · goal_changed
```

Ce que ça achète, concrètement :

1. **Rien ne peut régresser.** Un bug, un conflit multi-appareil, une mauvaise fusion : l'état se recalcule à partir du journal, qui est intact. La règle produit « un tampon ne se reprend jamais » (doc 02 §2) devient une **propriété de l'architecture**, pas une promesse.
2. **Changer les règles rétroactivement devient possible.** On veut rééquilibrer l'XP en semaine 12 ? On rejoue le journal avec le nouveau réducteur. Impossible avec un compteur écrasé.
3. **On peut entraîner FSRS plus tard** (doc 02 §5.3) parce que `exercise_answered` contient déjà tout.
4. **Le debug devient trivial** : « montre-moi les 40 derniers événements de cet utilisateur » explique n'importe quel bug de progression.

Coût à payer : les écritures sont un peu plus nombreuses (on écrit l'événement **et** l'état dérivé). Sur Firestore, c'est négligeable à notre échelle et compressible par lots.

**Garde-fous obligatoires** — sans eux le journal se retourne contre nous :
- **Idempotence** : chaque événement porte un `clientId` (UUID généré à l'émission). Un rejeu réseau ne crée pas de doublon.
- **Compaction** : au-delà de 5 000 événements, on écrit un `snapshot` et on archive les événements plus anciens (froid, pas supprimés).
- **Versionnement du réducteur** : `v: 1` sur chaque événement, pour que les vieux événements restent lisibles quand la logique change.

---

## 3. D4 en détail : le contenu immuable

```
/content/es/packs/2026-09-01_v3/…      ← publié, IMMUABLE. On ne corrige jamais en place.
/content/es/packs/2026-09-14_v4/…      ← la correction crée une nouvelle version
Remote Config : content.es.active = "2026-09-14_v4"
```

Règles :
- Un item corrigé **garde son ID** (D1) : la progression de l'utilisateur suit.
- Un item supprimé n'est jamais effacé : il passe à `retired: true`. Le carnet d'un utilisateur qui l'avait appris continue de fonctionner.
- L'app **met en cache le pack** et ne le recharge qu'au changement de pointeur. Coût de lecture Firestore quasi nul, fonctionnement hors-ligne gratuit.
- Un rollback = **changer un pointeur**, pas redéployer l'app. C'est ce qui permet de corriger une faute d'espagnol un dimanche soir sans passer par la revue App Store.

---

## 4. Schéma Firestore complet (MVP)

```
/content/{lang}/packs/{version}/countries/{countryId}
      name, flag, mapAsset, cities[]
/content/{lang}/packs/{version}/countries/{countryId}/cities/{cityId}
      name, emoji, theme, position{x,y}, order, localExpression
/content/{lang}/packs/{version}/…/cities/{cityId}/tours/{n}/lessons/{lessonId}
      title, canDo[], items[]        ← items = doc 02 §8
/content/{lang}/lexicon/{lemmaId}
      es, fr, pos, cefr, f, o, m, t, themes[], city, note     ← doc 03

/users/{uid}
      createdAt, activeProfile, entitlement{plan, until}, uiLang
/users/{uid}/profiles/{pid}
      displayName, avatar, targetLang, dailyGoal, createdAt
/users/{uid}/profiles/{pid}/state
      xp, gems, hearts{n,lastRefill}, streak{n,lastDay,freezes},
      skills{ecrire,parler,ecouter}, journeys{...}, lastEventId
/users/{uid}/profiles/{pid}/events/{eventId}        ← append only
/users/{uid}/profiles/{pid}/vocab/{lemmaId}
      rung, ease, interval, dueAt, lapses, city, source, history[]
```

**Règles de sécurité, en une phrase par ligne :**
- `/content/**` : lecture pour tout utilisateur authentifié, **écriture interdite au client** (admin SDK seulement).
- `/users/{uid}/**` : lecture/écriture par `uid` **uniquement**.
- `state` : **écriture client interdite**. Seule la Cloud Function y touche (D6).
- `events` : le client peut **créer** (create), jamais modifier ni supprimer (`allow create: if …; allow update, delete: if false;`).
- `vocab` : écriture client autorisée (faible enjeu, gros gain de latence).

---

## 5. Découpage du code Flutter

Le but : que le moteur d'apprentissage ne sache rien de Firebase, et que l'UI ne sache rien de l'algorithme. Sinon on ne peut ni tester ni changer d'avis.

```
lib/
  core/            thème, design system Kameo, i18n, routing, résultats/erreurs
  domain/          ❗ Dart pur, zéro dépendance externe, 100 % testable
    learning/      srs.dart · mastery.dart · placement.dart · lesson_builder.dart
    models/        lemma · item · lesson · journey · stamp · profile
  data/            firestore_*.dart · content_repository · event_log · cache local
  features/
    onboarding/  placement/  map/  city/  lesson/  vocab/  passport/  profile/
  app.dart
packages/
  kameo_engine/    (option) le domaine extrait en package, réutilisable côté scripts
```

**Le test qui garantit tout le reste** : `domain/` doit pouvoir tourner dans un test unitaire sans Firebase, sans Flutter, sans réseau. Si un jour il faut un `import 'package:cloud_firestore'` dans `domain/`, c'est que la frontière a été franchie.

---

## 6. Les trois pièges à éviter dès maintenant

1. **Ne pas mettre le contenu dans le code Dart.** Tentant au début (« juste 3 leçons en dur pour tester »). Résultat : chaque correction de contenu devient une release. Le contenu est en JSON dès le premier jour, chargé depuis les assets locaux au début, depuis Firestore ensuite. **Même format dans les deux cas.**
2. **Ne pas confondre « ville terminée » et « niveau atteint ».** L'un est un fait de parcours, l'autre une mesure de compétence (doc 02 §2). Deux champs distincts, toujours.
3. **Ne pas coder l'espagnol en dur.** Aucune règle de type « les verbes en -ar… » dans le moteur. Tout ce qui est spécifique à une langue vit dans le contenu ou le lexique. C'est la condition pour que l'allemand ne coûte que du contenu.
