# 02 — Modèle d'apprentissage : niveaux, compétences, mémoire

> Statut : proposition v1 · le cœur intellectuel du produit.
> Objectif : que « Niveau 3 · Aventurier · B1 » veuille dire quelque chose de vrai.

---

## 1. Le problème à résoudre

La plupart des apps d'apprentissage confondent trois choses :

| Ce qui est mesuré | Ce que ça prouve | Le piège |
|---|---|---|
| **Avancement** (leçons faites) | Que l'utilisateur a cliqué | Duolingo : on peut finir un arbre sans savoir parler |
| **Performance** (score du jour) | Qu'il a réussi *aujourd'hui* | Bachotage, oubli en 3 jours |
| **Compétence** (ce qu'il sait faire) | Ce qui compte vraiment | Difficile à mesurer, donc rarement mesuré |

Kameo mesure les trois, **séparément**, et n'en fait jamais un seul chiffre.

---

## 2. Les trois axes de Kameo

```
        AXE 1 — PARCOURS (monotone, ne recule jamais)
        Tour 1 ──► Tour 2 ──► Tour 3 ──► ...
        Ville A ✓  Ville B ✓  Ville C ★  Ville D 🔒
        Matérialisé par : le PASSEPORT

        AXE 2 — COMPÉTENCE (vectoriel, évolue lentement)
        écrire ▓▓▓▓▓▓░░  parler ▓▓▓░░░░░  écouter ▓▓▓▓▓░░░
        Matérialisé par : le PROFIL et la validation de niveau

        AXE 3 — MÉMOIRE (décroît sans entretien, c'est normal)
        847 mots vus · 312 en cours · 41 dus aujourd'hui
        Matérialisé par : le CARNET DE MOTS
```

**La règle qui découle de ce découpage — et qui répond directement à ta demande d'une structure sans retour en arrière :**

> **Un tampon obtenu ne se reprend jamais. Une page de passeport validée ne se dévalide jamais.**
> L'oubli n'attaque que l'axe 3 (la mémoire), jamais l'axe 1 (le parcours).

Concrètement : si tu ne joues pas pendant 3 mois, tu retrouves ton passeport intact — mais Kameo te dira « 180 mots ont besoin d'un rafraîchissement » et te proposera un *tour de chauffe*, pas une rétrogradation. Psychologiquement c'est décisif : l'utilisateur n'a jamais peur d'ouvrir l'app.

---

## 3. Qu'est-ce qu'un niveau, exactement

Un niveau Kameo n'est **pas** « un paquet de leçons ». C'est une **affirmation vérifiable** sur ce que l'utilisateur sait faire, adossée au CECR.

### 3.1 Définition par les descripteurs

| Tour | Niveau | CECR | Affirmation testable (extrait) |
|---|---|---|---|
| 1 | Explorateur | A1 | « Je peux me présenter, commander, demander mon chemin, comprendre des consignes très simples dites lentement. » |
| 2 | Voyageur | A2 | « Je peux raconter ma journée au passé, exprimer une préférence, gérer un échange simple imprévu (une erreur de commande). » |
| 3 | Aventurier | B1 | « Je peux donner un avis argumenté, raconter une anecdote, comprendre l'essentiel d'une conversation entre natifs sur un sujet familier. » |
| 4 | Local | B2 | « Je peux débattre, saisir l'humour et l'implicite, adapter mon registre. » |
| 5 | Ambassadeur | C1 | « Je peux suivre un débat rapide, comprendre les accents régionaux, jouer avec la langue. » |

Chaque **ville × tour** porte un sous-ensemble de ces descripteurs (`canDo: ["A2.ORAL.3", "A2.ECRIT.1"]`). La page de passeport complète = tous les descripteurs du tour couverts et validés. **C'est ce qui rend l'argument CECR honnête** au lieu d'être un habillage marketing.

### 3.2 Le niveau est un vecteur, pas un nombre

On stocke trois compétences séparées :

```
level: { ecrire: 2.4, parler: 1.6, ecouter: 2.1 }   // échelle continue, tour fractionnaire
```

Conséquences produit, toutes bonnes :
- On peut dire à l'utilisateur quelque chose de **vrai et utile** : « Ton écrit est A2, ton oral est A1. On va bosser l'oral à Séville. »
- La validation d'un tour exige un **minimum sur chaque compétence** → impossible de valider un niveau en ne faisant que du QCM. C'est le garde-fou anti-Duolingo.
- Ton objectif personnel (fluidité à l'écrit) devient **paramétrable** : le mix d'exercices s'adapte à la compétence la plus faible *ou* à celle que l'utilisateur veut pousser.

---

## 4. Le modèle de maîtrise, item par item

Chaque unité de savoir (mot, tournure, point de grammaire) traverse **4 échelons**. C'est la colonne vertébrale du système, et c'est aussi ce qui structure le répertoire de vocabulaire (doc 03).

| Échelon | Ce qu'on demande | Exercice type | Coût cognitif |
|---|---|---|---|
| **R1 — Reconnaître** | Comprendre en contexte | QCM ES→FR, écoute + image | faible |
| **R2 — Rappeler** | Retrouver la forme | FR→ES en banque de mots | moyen |
| **R3 — Produire** | Écrire sans appui | traduction libre, texte à trous | élevé |
| **R4 — Dire** | Produire à l'oral, au bon rythme | répétition notée, mini-dialogue | maximal |

Règles :
- Un item **monte** d'un échelon après 2 réussites espacées d'au moins 24 h à l'échelon courant.
- Un item **ne redescend jamais d'échelon** sur un seul échec : un échec **repousse la prochaine révision au lendemain**, sans perte. (Trois échecs consécutifs = redescente d'un seul échelon, et on le dit gentiment.)
- Un item à **R4 maîtrisé 3 fois** sort du cycle actif → il rejoint les « acquis », révisé tous les 6 mois par sécurité.

Cette asymétrie (monter est dur, descendre est rare et lent) est exactement ta demande de « pas de remise en arrière » appliquée à la mémoire.

---

## 5. Répétition espacée : quel algorithme

La spec dit « SM-2 simplifié ». Je propose de garder SM-2 comme **base** mais avec trois ajustements qui coûtent peu et changent beaucoup.

### 5.1 Le schéma retenu

```
intervalle_suivant = intervalle_courant × facteur_facilité × modulateur_échelon
facteur_facilité ∈ [1.3 , 2.7], ajusté de ±0.15 selon la réponse
modulateur_échelon : R1 ×1.0 · R2 ×0.9 · R3 ×0.8 · R4 ×0.7
```

Paliers de départ : **10 min → 1 j → 3 j → 7 j → 16 j → 35 j → 90 j**.

### 5.2 Les trois ajustements Kameo

1. **Le contexte de voyage compte.** Un mot appris à Valence est ré-exposé *en priorité dans les leçons de Valence des tours suivants*. On ne révise pas dans le vide : la révision est déguisée en voyage. Techniquement : le sélecteur d'exercices d'une leçon puise 20 % de ses items dans les mots dus de la même ville.
2. **Plafond quotidien de révisions.** Jamais plus de 25 mots dus affichés, triés par urgence. Anki échoue en famille à cause des « 340 cartes en retard ». Le surplus est réétalé silencieusement.
3. **Le mot difficile choisi par l'utilisateur démarre à R2**, pas à R1 : s'il l'a sélectionné, c'est qu'il l'a rencontré et compris en contexte.

### 5.3 Pourquoi pas FSRS
FSRS est meilleur mais demande un historique de révisions pour être calibré, et une implémentation plus lourde. **Décision : SM-2+ au MVP, avec le journal de révisions complet stocké dès le jour 1** (`{itemId, ts, grade, latency}`). Le jour où on veut FSRS, on a les données pour l'entraîner. C'est encore une décision « sans retour en arrière » : on ne peut pas reconstruire un historique qu'on n'a pas enregistré.

---

## 6. Composition d'une leçon (le moteur)

Une leçon n'est pas une liste figée d'exercices : c'est une **recette** appliquée à un vivier d'items. Ça change tout pour la rejouabilité et le coût de contenu.

```
Leçon « Commander une paella » (Valence, Tour 1)
├─ 60 % items neufs du thème        (le contenu du pack)
├─ 20 % items dus en révision       (choisis par SM-2, même ville en priorité)
├─ 20 % items « faux-amis / erreurs personnelles » (ce que CET utilisateur rate)
└─ mix de compétences imposé : ≥1 écrire, ≥1 écouter, ≥1 parler
```

Deux propriétés importantes :
- **Chaque leçon est différente** pour chaque utilisateur, sans multiplier le contenu à produire.
- **Le moteur est neutre vis-à-vis de la langue** : ajouter l'allemand = ajouter des items, pas du code.

---

## 7. Validation d'un tour (la cérémonie)

Conditions pour valider une page de passeport (tour N, pays P) :

1. **Tous les tampons** des villes de P au tour N. *(Le tour N+1, lui, se débloque à N−1 villes — progression fluide, complétion exigeante, cf. spec §2.2.)*
2. **Seuil minimal par compétence** : `min(ecrire, parler, ecouter) ≥ N − 0.3`. Impossible de valider A2 avec un oral A1.
3. **Épreuve de visa** : 10 items tirés au hasard dans *tout* le tour, dont 3 oraux, à ≥ 80 %. Ce n'est pas un examen surprise : on prévient, on peut le repasser sans pénalité, et il n'y a **aucune conséquence négative en cas d'échec** (on propose une remise en forme ciblée).

L'échec ne retire rien. Il ajoute une étape. C'est la traduction pédagogique de ton exigence.

---

## 8. Ce que ça implique pour le contenu

Chaque item de contenu doit porter ces métadonnées **dès la première génération**, sinon il faudra tout regénérer :

```jsonc
{
  "id": "es.val.t1.paella.04",
  "kind": "translate",              // translate | speak | listen | gap | dialogue | mcq
  "skill": "ecrire",                // ecrire | parler | ecouter
  "rung": "R2",                     // échelon visé
  "cefr": "A1",
  "canDo": ["A1.ORAL.2"],           // descripteur couvert
  "city": "valencia", "tour": 1, "theme": "restaurant",
  "lexemes": ["paella", "querer", "para"],   // liens vers le répertoire (doc 03)
  "grammar": ["pres.querer"],
  "prompt": "…", "answer": "…", "alternates": ["…"],  // réponses acceptées
  "difficulty": 34,                 // 0-100, recalibré par la télémétrie
  "audioRef": "…"
}
```

`difficulty` est initialisée par l'IA puis **recalibrée automatiquement** avec le taux de réussite réel (`p`) une fois 200 réponses collectées. C'est la boucle qui rend le contenu meilleur avec le temps sans travail humain.

---

## 9. Ce qu'on ne fait pas au MVP

- Pas de scoring de prononciation fin (on assume l'indulgence, cf. spec §10).
- Pas de génération de leçon en temps réel (coût, latence, qualité).
- Pas de ligues ni de social. La rétention du MVP doit venir de la **boucle d'apprentissage**, pas de la compétition. Si elle ne tient pas sans ligues, le produit a un problème qu'aucune ligue ne réparera.
