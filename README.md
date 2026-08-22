# Kameo

> App mobile d'apprentissage des langues par le voyage.
> Tu choisis une destination, tu voyages de ville en ville, chaque ville t'apprend ses spécificités.
> Un tour complet du pays = un niveau validé dans ton passeport.

**Statut : pré-développement.** Aucune ligne d'app n'est écrite — et c'est volontaire. On fige d'abord les parcours, le modèle d'apprentissage et les décisions structurantes.

## Lire dans cet ordre

| | Document | Ce qu'il tranche |
|---|---|---|
| — | [`KAMEO_SPEC.md`](KAMEO_SPEC.md) | La spec produit d'origine : concept, gamification, monétisation, roadmap |
| 01 | [`docs/01-parcours-utilisateur.md`](docs/01-parcours-utilisateur.md) | Compte, onboarding, reprise, multi-appareil, RGPD |
| 02 | [`docs/02-modele-apprentissage.md`](docs/02-modele-apprentissage.md) | Ce qu'est un niveau · les 3 axes · les 4 échelons de maîtrise · la répétition espacée |
| 03 | [`docs/03-vocabulaire-et-placement.md`](docs/03-vocabulaire-et-placement.md) | Le répertoire de vocabulaire noté, et le test de placement adaptatif |
| 04 | [`docs/04-architecture-anti-reprise.md`](docs/04-architecture-anti-reprise.md) | Les 6 décisions qu'on ne veut pas refaire · le journal d'événements |
| 05 | [`docs/05-plan-mvp.md`](docs/05-plan-mvp.md) | Le plan en 13 étapes, de la première à la dernière |

## Contenu

- `content/es/lexicon-seed.json` — 130 lemmes espagnols notés sur 5 composantes (fréquence, CECR, opacité vs français, irrégularité, piège), thématisés par ville. La difficulté n'est pas stockée : elle se calcule.

## Prototype

- `prototype/kameo-proto.html` — parcours complet cliquable, à ouvrir dans un navigateur. Le test de placement y est **réellement adaptatif** et tourne sur le fichier semence ci-dessus. Sert à décider, pas à livrer.

## L'idée directrice

Trois choses sont mesurées séparément et ne se mélangent jamais :

- **le parcours** (tampons, tours) — monotone, il ne recule jamais ;
- **la compétence** (écrire / parler / écouter) — un vecteur, pas un chiffre ;
- **la mémoire** (le carnet de mots) — elle décroît, et c'est normal.

L'oubli n'attaque que la mémoire. Un tampon obtenu ne se reprend jamais.
