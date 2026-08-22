# Pipeline de contenu

> Le contenu n'est **jamais** généré en direct chez l'utilisateur : coût, latence,
> et surtout contrôle qualité. Il est produit ici, relu, puis publié — doc 03 §6.

```bash
npm ci
npm run validate            # tourne aussi en CI, sans clé API
```

## Les quatre outils

| Commande | Ce qu'elle fait | Clé API |
|---|---|---|
| `node validate-content.mjs` | Valide tout `/content` : schéma **et** règles pédagogiques | non |
| `node normalize-lexicon.mjs es` | Recalcule ce qui se calcule (l'opacité) | non |
| `node annotate-lexicon.mjs --input freq.txt` | Annote un lot de lemmes bruts | **oui** |
| `node generate-pack.mjs --city valencia --tour 1` | Écrit un pack de ville sous schéma strict | **oui** |
| `node recalibrate.mjs --telemetry t.json` | Corrige la difficulté avec les réponses réelles | non |
| `node emit-difficulty-fixture.mjs es` | Régénère le témoin de parité Node ↔ Dart | non |

## Le circuit complet

```
liste de fréquence (libre)
      │
      ├─► annotate-lexicon.mjs ──► lexicon-draft-N.json ──► revue humaine ──┐
      │                                                                      │
      └─► normalize-lexicon.mjs (opacité calculée) ◄────────────────────────┘
                    │
                    ▼
            lexicon-seed.json ──► emit-difficulty-fixture.mjs ──► parité Dart
                    │
                    ▼
            generate-pack.mjs ──► packs/{date}_draft/  (humanReviewed: false)
                    │
                    ├─► validate-content.mjs        ← bloquant
                    ├─► relecture par un natif       ← les expressions locales
                    │
                    ▼
            packs/{date}_v{n}/  (humanReviewed: true) ──► Remote Config pointe ici
```

**L'app refuse de servir un pack dont `humanReviewed` est faux.** Mieux vaut une
ville verrouillée qu'une faute d'espagnol devant un utilisateur — la crédibilité
« authentique » est tout le concept.

## Ce que le validateur attrape

Le schéma Zod attrape les fautes de forme. Les règles suivantes attrapent celles
qui coûtent cher :

- un item qui référence un lemme absent du répertoire ;
- du vocabulaire trop dur pour le tour (on enseigne un palier au-dessus, pas deux) ;
- une leçon qui ne travaille pas les trois compétences ;
- un exercice oral ou d'écoute sans `audioText` ou sans `audioRef` ;
- un QCM dont la bonne réponse n'est pas dans les propositions, ou deux propositions identiques une fois les accents pliés ;
- une banque de mots à laquelle il manque un mot de la réponse ;
- un descripteur CECR annoncé par une leçon que ne couvre aucun item ;
- une épreuve de tampon sans oral ;
- un piège (`t ≥ 70`) sans note qui l'explique ;
- une opacité annotée qui s'écarte de l'opacité calculée.

Sur la semence, ces règles ont trouvé deux vraies erreurs et vingt annotations
approximatives dès le premier passage.

## Choix d'implémentation

**L'opacité n'est pas demandée à l'IA.** C'est une distance de Levenshtein entre
le mot espagnol et sa traduction : un calcul ne peut pas halluciner. On ne demande
au modèle que ce qu'un calcul ne sait pas faire.

**La formule de difficulté existe deux fois** (ici en JS, dans le moteur en Dart)
et ne peut pas diverger : `emit-difficulty-fixture.mjs` écrit un témoin que le
test `parité de la formule` du moteur relit. Changer un poids d'un seul côté
casse un des deux.

**Le prompt est du code.** Il vit dans `lib/prompt.mjs` et se relit comme tel :
c'est le paramètre le plus sensible du pipeline. Il donne à Claude le vocabulaire
autorisé, les descripteurs à couvrir et les contraintes de forme — la qualité
vient de la contrainte, pas de la créativité laissée libre.

**Pas de repli automatique sur un autre modèle.** `messages.parse()` est la voie
documentée pour la sortie structurée ; la combiner avec les `fallbacks`
côté serveur n'est pas documentée, et on ne devine pas une API. Un refus de
génération est signalé et le lot se relance — un travail par lots peut se
permettre de réessayer.
