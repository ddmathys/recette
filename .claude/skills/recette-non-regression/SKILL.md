---
name: recette-non-regression
description: Garde-fou de non-régression de Recettes du Tiroir : vérifications, tests à ajouter, niveau de risque.
---

# Non-régression de Recettes du Tiroir

## Vérifications automatiques
types Next + compilation TypeScript + lint (workflow claude-validate.yml). Elles doivent rester vertes.

## Parcours critiques
| Parcours | Tests existants |
|---|---|
| Ajout de recette (texte/lien → DeepSeek) | (pas de test automatisé : vérifier à la main) |
| Recettes de base hors connexion | src/data/seed-recipes.ts |

## Règles
- Un bug corrigé = un test ajouté quand un test existe pour cette zone.
- Ne jamais affaiblir, supprimer ou sauter un test pour faire passer les vérifications.

## Niveau de risque
- **Faible** : texte, couleur, mise en page d'un écran.
- **Moyen** : logique d'un écran, nouveau composant, calcul couvert par un test.
- **Élevé** : données (structure Firestore), authentification, paiements, déploiement, calcul non testé → jamais d'approbation automatique.
