import 'dart:math';

import 'package:kameo_engine/kameo_engine.dart';
import 'package:test/test.dart';

import '_helpers.dart';

/// Un apprenant simulé : il a une vraie capacité [ability] sur l'échelle
/// 0-100, et répond juste avec une probabilité logistique (modèle de Rasch).
bool _answers(double ability, double itemDifficulty, Random rng) {
  final double p = 1 / (1 + exp((itemDifficulty - ability) / 9));
  return rng.nextDouble() < p;
}

PlacementEngine _run(Lexicon lex, double ability, Random rng) {
  final PlacementEngine e = PlacementEngine(lex, random: rng);
  PlacementQuestion? q;
  while ((q = e.next()) != null) {
    e.submit(correct: _answers(ability, lex.difficultyOf(q!.lemma), rng));
  }
  return e;
}

void main() {
  final Lexicon lex = loadSeedLexicon();

  group('test de placement', () {
    test('converge en 8 à 18 questions', () {
      final Random rng = Random(1);
      for (int i = 0; i < 200; i++) {
        final PlacementEngine e = PlacementEngine(lex, random: rng);
        PlacementQuestion? q;
        while ((q = e.next()) != null) {
          e.submit(correct: _answers(35, lex.difficultyOf(q!.lemma), rng));
        }
        expect(e.asked, inInclusiveRange(8, 18));
      }
    });

    test('estime correctement 1 000 apprenants synthétiques', () {
      final Random rng = Random(42);
      final List<double> errors = <double>[];
      for (int i = 0; i < 1000; i++) {
        // Le répertoire semence couvre P1 à P4 : on teste sur cette plage.
        final double ability = 8 + rng.nextDouble() * 50;
        errors.add((_run(lex, ability, rng).estimate - ability).abs());
      }
      final double mean =
          errors.reduce((double a, double b) => a + b) / errors.length;
      final List<double> sorted = List<double>.from(errors)..sort();
      final double p90 = sorted[(errors.length * 0.9).floor()];
      // Huit à quatorze questions ne peuvent pas faire mieux que quelques
      // points d'erreur : ce qui compte est de ne pas se tromper de palier.
      // Mesuré sur la semence : 4,2 de moyenne, 8,6 au 90e centile.
      expect(mean, lessThan(5), reason: 'erreur moyenne $mean');
      expect(p90, lessThan(10), reason: 'erreur au 90e centile $p90');
    });

    test('sépare un débutant d un avancé', () {
      final Random rng = Random(3);
      final List<double> low = <double>[
        for (int i = 0; i < 50; i++) _run(lex, 12, rng).estimate,
      ];
      final List<double> high = <double>[
        for (int i = 0; i < 50; i++) _run(lex, 55, rng).estimate,
      ];
      final double avgLow =
          low.reduce((double a, double b) => a + b) / low.length;
      final double avgHigh =
          high.reduce((double a, double b) => a + b) / high.length;
      expect(avgLow, lessThan(30));
      expect(avgHigh, greaterThan(42));
    });

    test('un sans-faute part au tour 3, un zéro pointé au tour 1', () {
      final PlacementEngine best = PlacementEngine(lex, random: Random(5));
      while (best.next() != null) {
        best.submit(correct: true);
      }
      expect(best.result().startTour, 3);
      expect(best.result().cefr, anyOf('B1', 'B1/B2'));

      final PlacementEngine worst = PlacementEngine(lex, random: Random(5));
      while (worst.next() != null) {
        worst.submit(correct: false);
      }
      expect(worst.result().startTour, 1);
      expect(worst.result().level, 'Explorateur');
    });

    test('ne place jamais au-dessus du contenu qui existe', () {
      final PlacementEngine e = PlacementEngine(lex,
          config: const PlacementConfig(maxTour: 2), random: Random(9));
      while (e.next() != null) {
        e.submit(correct: true);
      }
      expect(e.result().startTour, lessThanOrEqualTo(2));
    });

    test('les pièges ne comptent pas dans le score mais nourrissent le carnet',
        () {
      final PlacementEngine e = PlacementEngine(lex, random: Random(11));
      int traps = 0;
      PlacementQuestion? q;
      while ((q = e.next()) != null) {
        if (q!.isTrap) {
          traps++;
          final double before = e.theta;
          final double stepBefore = e.step;
          e.submit(correct: false);
          expect(e.theta, before, reason: 'un piège raté ne baisse pas θ');
          expect(e.step, stepBefore);
        } else {
          e.submit(correct: true);
        }
      }
      expect(traps, 2);
      expect(e.result().toWorkLemmaIds, isNotEmpty);
    });

    test('alterne les formats pour mesurer les compétences séparément', () {
      final PlacementEngine e = PlacementEngine(lex, random: Random(13));
      final Set<PlacementFormat> seen = <PlacementFormat>{};
      PlacementQuestion? q;
      while ((q = e.next()) != null) {
        seen.add(q!.format);
        e.submit(correct: true);
      }
      expect(seen, containsAll(PlacementFormat.values));
      final Map<Skill, double> v = e.result().skills;
      expect(v.keys, containsAll(Skill.values));
      // L'oral n'est pas mesuré : il est annoncé en retrait, pas bluffé.
      expect(v[Skill.parler]!, lessThan(v[Skill.ecrire]!));
    });

    test('l estimation sur toutes les réponses bat la position de l escalier',
        () {
      final Random rng = Random(23);
      final List<double> stair = <double>[], map = <double>[];
      for (int i = 0; i < 300; i++) {
        final double ability = 30 + rng.nextDouble() * 30;
        final PlacementEngine e = _run(lex, ability, rng);
        stair.add((e.theta - ability).abs());
        map.add((e.estimate - ability).abs());
      }
      double avg(List<double> v) =>
          v.reduce((double a, double b) => a + b) / v.length;
      expect(avg(map), lessThan(avg(stair) * 0.8),
          reason: 'escalier ${avg(stair)} · MAP ${avg(map)}');
    });

    test('place dans le bon tour dans plus de 3 cas sur 4', () {
      // C'est la vraie question produit : l'erreur en points compte moins que
      // le tour proposé à l'arrivée.
      final Random rng = Random(31);
      int exact = 0;
      int within1 = 0;
      const int n = 600;
      for (int i = 0; i < n; i++) {
        final double ability = 8 + rng.nextDouble() * 50;
        final int expected = ability < 40 ? 1 : (ability < 55 ? 2 : 3);
        final int got = _run(lex, ability, rng).result().startTour;
        if (got == expected) exact++;
        if ((got - expected).abs() <= 1) within1++;
      }
      expect(exact / n, greaterThan(0.78), reason: 'tour exact ${exact / n}');
      expect(within1, n, reason: 'jamais plus d un tour d écart');
    });

    test('la précision se paie en questions, et le moteur le sait', () {
      // Forcer un nombre fixe de questions permet de mesurer le rendement de
      // chaque question supplémentaire. Au-delà de 30, ça ne vaut plus le
      // temps de l'utilisateur.
      final Lexicon dense = syntheticLexicon();
      double meanErrorWith(int items) {
        final Random rng = Random(101);
        final List<double> errors = <double>[];
        for (int i = 0; i < 300; i++) {
          final double ability = 10 + rng.nextDouble() * 70;
          final PlacementEngine e = PlacementEngine(
            dense,
            config:
                PlacementConfig(minItems: items, maxItems: items, seStop: 0),
            random: rng,
          );
          PlacementQuestion? q;
          while ((q = e.next()) != null) {
            e.submit(
                correct: _answers(ability, dense.difficultyOf(q!.lemma), rng));
          }
          errors.add((e.estimate - ability).abs());
        }
        return errors.reduce((double a, double b) => a + b) / errors.length;
      }

      final double at14 = meanErrorWith(14);
      final double at30 = meanErrorWith(30);
      expect(at14, lessThan(6), reason: '14 questions → $at14');
      expect(at30, lessThan(at14), reason: '30 questions → $at30');
      expect(at30, greaterThan(at14 * 0.5),
          reason: 'rendement décroissant : doubler les questions ne divise '
              'pas l erreur par deux ($at14 → $at30)');
    });

    test('quand le répertoire plafonne, l incertitude le dit', () {
      final Random rng = Random(29);
      // La semence s'arrête vers 62 : un apprenant B2 ne peut pas être mesuré
      // par ce répertoire, et le moteur doit l'annoncer plutôt que d'inventer.
      final PlacementEngine e = _run(lex, 85, rng);
      expect(e.isBankLimited, isTrue);
      expect(e.result().isConfident, isFalse);

      final PlacementEngine mesurable = _run(lex, 30, rng);
      expect(mesurable.isBankLimited, isFalse);
      expect(mesurable.result().isConfident, isTrue);
    });

    test('le résultat est disponible même si le test est abandonné', () {
      final PlacementEngine e = PlacementEngine(lex, random: Random(17));
      e.next();
      e.submit(correct: true);
      final PlacementResult r = e.result();
      expect(r.itemsAsked, 1);
      expect(r.startTour, greaterThanOrEqualTo(1));
    });

    test('crédite les mots sous le niveau estimé', () {
      final PlacementEngine e = PlacementEngine(lex, random: Random(19));
      while (e.next() != null) {
        e.submit(correct: true);
      }
      final List<Lemma> credited = e.creditedLemmas();
      expect(credited.length, greaterThan(50));
      for (final Lemma l in credited) {
        expect(lex.difficultyOf(l), lessThan(e.estimate));
      }
    });
  });
}
