# 03 — Répertoire de vocabulaire & test de placement

> Statut : proposition v1 · c'est le sujet sur lequel tu m'as demandé une proposition ferme.

---

## 1. L'idée : un répertoire, pas des listes

La plupart des apps stockent des listes de mots par leçon. Kameo stocke **un répertoire unique par langue** (le *lexique*), et les leçons **pointent** vers lui.

```
LEXIQUE espagnol  (≈ 3 000 lemmes à terme, 500 au MVP)
   │  chaque entrée est notée, classée, thématisée
   ├──► le TEST DE PLACEMENT y pioche pour situer l'utilisateur
   ├──► les LEÇONS y pointent (une leçon = des items qui référencent des lemmes)
   ├──► le CARNET DE MOTS de l'utilisateur y référence ses mots difficiles
   └──► la GÉNÉRATION IA y est contrainte (« écris un dialogue en n'utilisant que P1–P3 »)
```

**Un seul objet, quatre usages.** C'est ce qui évite les incohérences (un mot « facile » dans le test et « difficile » en leçon) et ce qui rend l'ajout d'une langue mécanique.

---

## 2. Comment on note la difficulté d'un mot

La difficulté n'est pas une opinion. Elle se calcule, avec 5 composantes, **spécifiquement pour un francophone** — c'est notre avantage sur les apps anglo-centrées.

| Composante | Poids | Source | Exemple |
|---|---|---|---|
| **Fréquence** `f` | 45 % | rang dans un corpus libre (OpenSubtitles / CREA) | *casa* rang 120 → 5/100 ; *hueco* rang 4 800 → 78/100 |
| **Palier CECR** `c` | 20 % | annoté par l'IA puis revu | A1 → 0, C1 → 100 |
| **Opacité** `o` | 15 % | distance orthographique au français (Levenshtein normalisé) | *hotel/hôtel* → 8 ; *rincón/coin* → 100 |
| **Irrégularité** `m` | 10 % | verbe irrégulier, genre inattendu, pluriel piégeux | *ir*, *ser*, *el agua* (féminin mais « el ») |
| **Piège** `t` | 10 % | faux-ami ou polysémie trompeuse | *salir* (= sortir, pas salir), *largo* (= long), *ropa* (= vêtements) |

```
difficulté = 0.45·f + 0.20·c + 0.15·o + 0.10·m + 0.10·t        → 0 à 100
```

Un faux-ami très fréquent comme *salir* est donc **facile à reconnaître mais piégeux** : il sort avec un score moyen et sera introduit tôt, **explicitement comme piège**. C'est exactement le genre de mot qui crée le sentiment « cette app est intelligente ».

### 2.1 Les paliers (P1 → P6)

| Palier | Difficulté | CECR | Volume cible | Ce qu'on peut faire avec |
|---|---|---|---|---|
| **P1** | 0–20 | A1.1 | 150 mots | survivre : saluer, compter, nommer |
| **P2** | 20–35 | A1.2 | 250 | commander, acheter, se repérer |
| **P3** | 35–50 | A2.1 | 400 | raconter au passé, préférer, comparer |
| **P4** | 50–65 | A2.2 / B1 | 600 | nuancer, expliquer, se plaindre |
| **P5** | 65–80 | B1/B2 | 800 | argumenter, l'implicite, l'abstrait |
| **P6** | 80–100 | B2/C1 | 800 | registres, idiomes, régionalismes |

Le palier n'est **pas** le tour du voyage : un tour puise majoritairement dans son palier, plus 20 % du palier suivant (zone proximale de développement — on apprend au-dessus de son niveau, pas dedans).

### 2.2 Rattachement aux villes

Chaque lemme porte `themes: []` et une **affinité ville** (0–3). *Paella*, *arroz*, *mercado* → Valence (3). *Metro*, *entrada*, *prisa* → Madrid. Un mot sans affinité forte (*porque*, *hacer*) est disponible partout. C'est ce qui fait qu'une ville « enseigne ses spécificités » sans qu'on écrive le contenu ville par ville à la main.

---

## 3. La progression facile → difficile, concrètement

Un mot ne devient pas « connu » : il traverse les 4 échelons du doc 02 (**R1 reconnaître → R2 rappeler → R3 produire → R4 dire**). Croisé avec les paliers, ça donne la vraie carte de progression :

```
              R1 reconnaître   R2 rappeler   R3 produire   R4 dire
   P1  ██████████████████████████████████████████████████  acquis
   P2  ████████████████████████████████████░░░░░░░░░░░░░░  en cours
   P3  ██████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  démarré
   P4  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  à venir
```

Cette grille est **l'écran de progression le plus honnête qu'on puisse montrer** — et je propose qu'elle devienne un écran du produit (« Ma carte de langue »), parce qu'elle répond exactement à ton objectif personnel : voir progresser la fluidité, pas un compteur d'XP.

Pour ton cas d'usage (fluidité à l'écrit), la même grille filtrée sur `skill = écrire` devient ton tableau de bord.

---

## 4. Le test de placement

### 4.1 Objectif
En **4 minutes**, produire : (a) un tour de départ, (b) un vecteur de compétences, (c) **un pré-remplissage du carnet** avec les mots visiblement déjà connus. Le (c) est sous-estimé : c'est ce qui évite de faire réviser *hola* à quelqu'un qui a fait 5 ans d'espagnol.

### 4.2 Algorithme — escalier adaptatif (Rasch simplifié)

```
θ ← 40                       // estimation de niveau, échelle 0-100 (= échelle de difficulté)
pas ← 20
pour i de 1 à 20 :
    item ← tirer un lemme non vu de difficulté ≈ θ (±5), format alterné
    si réussi : θ ← θ + pas   sinon : θ ← θ − pas
    pas ← max(4, pas × 0.75)                  // convergence
    si i ≥ 8 et erreur_standard(θ) < 4 : arrêter
```

- **8 items minimum, 20 maximum.** Convergence typique en 12–14 items ≈ 3 min.
- Les items sont **alternés par compétence** : reconnaissance (ES→FR), rappel (FR→ES), écoute (audio→sens), production (une phrase à écrire). On obtient trois θ partiels : `θ_écrire`, `θ_écouter`, `θ_parler` (dérivé, faible confiance au MVP).
- **Deux items pièges obligatoires** (faux-amis) : ils ne comptent pas dans θ mais alimentent le carnet — un utilisateur qui tombe dans *salir* reçoit ce mot en priorité.

### 4.3 Du score au tour de départ

| θ final | Niveau estimé | Départ proposé |
|---|---|---|
| < 25 | A1.1 | Tour 1, ville 1 |
| 25–40 | A1.2 | Tour 1, ville 3 (on saute les bases) |
| 40–55 | A2 | **Tour 2**, ville 1 |
| 55–70 | B1 | Tour 3, ville 1 |
| > 70 | B2+ | Tour 3 + message « le contenu avancé arrive » |

Trois garde-fous :
1. **Le résultat est une proposition, pas une sentence.** L'écran de résultat offre toujours « je préfère commencer au début » — et c'est un bouton normal, pas un lien gris.
2. **On ne place jamais au-dessus du contenu existant** (Tour 3 max au MVP).
3. **Un placement peut être refait** une fois par mois depuis le Profil (« je me sens à l'étroit »).

### 4.4 Pré-remplissage du carnet
Chaque lemme réussi au test entre au carnet à **R1 acquis** avec `source: "placement"` et une première révision à J+7. Chaque lemme raté entre à **R1 à travailler**, révision à J+1. L'écran de résultat le dit : « 47 mots déjà crédités, 9 à travailler ». Valeur perçue immédiate, coût nul.

---

## 5. Le fichier semence

`content/es/lexicon-seed.json` — **130 lemmes espagnols réels**, notés sur les 5 composantes, thématisés par ville, avec 11 faux-amis marqués. Il sert **tout de suite** : c'est lui qui alimente le prototype de test de placement.

Répartition obtenue avec la formule ci-dessus : **P1 59 · P2 48 · P3 16 · P4 7 · P5–P6 0**. C'est normal et voulu — une semence tirée du vocabulaire courant couvre les paliers bas ; les paliers 5 et 6 arriveront par l'import fréquentiel (§6). Les extrêmes calculés : *no* (2), *hola* (6) … *soler* (59), *echar de menos* (62). La formule classe donc correctement sans intervention humaine.

Format :

```jsonc
{
  "id": "es.salir",
  "es": "salir", "fr": "sortir",
  "pos": "verbe",
  "cefr": "A1",
  "f": 12,      // fréquence  0-100 (0 = très fréquent)
  "o": 15,      // opacité vs français
  "m": 60,      // irrégularité morphologique (salgo)
  "t": 100,     // piège : faux-ami majeur
  "themes": ["quotidien"], "city": null,
  "note": "Faux-ami : ne veut PAS dire salir."
}
```

`difficulté` et `palier` ne sont **pas stockés** : ils sont **calculés** par la formule §2. Ainsi, si on ajuste les poids, tout le répertoire se re-note d'un coup, sans réécrire une seule entrée. (Encore une décision « sans retour en arrière ».)

---

## 6. Comment on passe de 110 à 3 000 mots

1. **Import fréquentiel** : liste de fréquence libre (OpenSubtitles es) → 3 000 premiers lemmes, dédoublonnés.
2. **Annotation IA par lots de 100** : traduction FR, POS, CECR, thèmes, affinité ville, piège éventuel, note pédagogique. Schéma JSON strict, température basse.
3. **Calcul automatique** de `o` (Levenshtein ES/FR) — pas d'IA nécessaire, donc pas d'erreur possible.
4. **Revue humaine ciblée** : on ne relit pas 3 000 mots. On relit (a) les 150 pièges détectés, (b) les expressions locales, (c) un échantillon aléatoire de 5 % pour mesurer le taux d'erreur. Si le taux dépasse 2 %, on relit tout le lot.
5. **Recalibrage par la télémétrie** : après 200 réponses réelles sur un lemme, `f` est corrigé par le taux de réussite observé. Le répertoire devient plus juste avec l'usage.

Coût estimé pour 3 000 lemmes annotés : **quelques euros d'API et 2 soirées de revue**. C'est ça, l'avantage structurel dont parle la spec §6.3.
