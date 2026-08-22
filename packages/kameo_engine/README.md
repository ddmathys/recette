# kameo_engine

Le moteur d'apprentissage de Kameo, en **Dart pur** : ni Flutter, ni Firebase,
ni réseau. C'est la frontière qui rend tout le reste testable — si un
`import 'package:cloud_firestore'` apparaît ici un jour, c'est qu'elle a été
franchie.

```bash
dart pub get && dart analyze && dart test    # 48 tests, ~12 s
```

| Fichier | Rôle | Doc |
|---|---|---|
| `lexicon.dart` | Le répertoire : notation, paliers, tirage à une difficulté donnée | 03 |
| `placement.dart` | Test adaptatif : escalier pour choisir, MAP pour noter | 03 §4 |
| `srs.dart` | Répétition espacée SM-2+, file du jour plafonnée | 02 §5 |
| `lesson_builder.dart` | Composition 60 / 20 / 20, couverture des 3 compétences | 02 §6 |
| `events.dart` | Journal append-only et réducteur idempotent | 04 §2 |
| `models.dart` | Lemme, item, échelons, carte de vocabulaire | 02 §4 |

## Ce que les tests garantissent

- **Placement** : 84 % des apprenants simulés dans le bon tour, 100 % à un tour
  près ; les pièges ne comptent pas dans le score ; le plafond du répertoire est
  annoncé au lieu d'être masqué.
- **Mémoire** : un échec isolé ne fait jamais perdre d'échelon ; monter en exige
  deux, espacés de 24 h ; un mot acquis sort du cycle actif.
- **Progression** : rejouer un événement ne change rien ; un tampon ne redescend
  jamais ; le tour courant ne recule pas, même après un placement raté.
