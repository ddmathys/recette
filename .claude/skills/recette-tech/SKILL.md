---
name: recette-tech
description: Spécialiste du fonctionnement technique de Recettes du Tiroir (stack, données, déploiement, zones sensibles).
---

# Technique de Recettes du Tiroir

## Stack et règles
- Next.js 16 : APIs différentes de ce que tu connais, lis node_modules/next/dist/docs/ avant de coder (AGENTS.md).
- Firebase Auth email/mot de passe + Google ; Firestore/Storage protégés par les règles.
- Clé DeepSeek uniquement côté serveur (routes API), jamais dans le navigateur.
- Le site web et app_mobile/ partagent les mêmes données : ne pas changer un format sans adapter les deux.
- Pas d'auto-deploy Vercel : vercel --prod à la main.

## Zones sensibles (jamais de merge automatique)
Règles Firestore/Storage, firebase.json, vercel.json, .github/, android/, fichiers Gradle, package.json, et tout fichier lié à l'authentification, aux sessions, à l'admin, aux secrets, aux paiements ou aux crédits.
