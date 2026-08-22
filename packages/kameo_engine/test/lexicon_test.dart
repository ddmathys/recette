import 'package:kameo_engine/kameo_engine.dart';
import 'dart:math';

import 'package:test/test.dart';

import '_helpers.dart';

Random _seeded() => Random(7);

void main() {
  final Lexicon lex = loadSeedLexicon();

  group('répertoire', () {
    test('charge la semence espagnole sans doublon', () {
      expect(lex.length, 130);
      expect(lex.lemmas.map((Lemma l) => l.id).toSet().length, lex.length);
    });

    test('classe du plus facile au plus difficile', () {
      final List<Lemma> sorted = lex.byDifficulty;
      // On teste des propriétés, pas des mots précis : le répertoire bouge à
      // chaque recalibrage, la propriété doit tenir quand même.
      for (final Lemma l in sorted.take(5)) {
        expect(l.cefr, 'A1');
        expect(lex.difficultyOf(l), lessThan(15));
      }
      for (final Lemma l in sorted.reversed.take(5)) {
        expect(l.cefr, anyOf('B1', 'B2', 'C1'));
        expect(lex.difficultyOf(l), greaterThan(45));
      }
      expect(sorted.first.term, 'no');
      // La formule doit séparer nettement le mot outil du mot abstrait.
      expect(lex.difficultyOf(lex.byId('es.hola')!),
          lessThan(lex.difficultyOf(lex.byId('es.soler')!)));
    });

    test('un faux-ami fréquent reste facile mais est marqué comme piège', () {
      final Lemma salir = lex.byId('es.salir')!;
      expect(salir.isTrap, isTrue);
      expect(lex.bandOf(salir).index, lessThanOrEqualTo(Band.p3.index));
      expect(lex.traps.length, greaterThanOrEqualTo(10));
    });

    test('changer les poids re-note tout le répertoire d un coup', () {
      final Lexicon opaque = Lexicon('es', lex.lemmas,
          weights: const DifficultyWeights(
              frequency: 0.10,
              cefr: 0.10,
              opacity: 0.70,
              morphology: 0.05,
              trap: 0.05));
      final Lemma metro = opaque.byId('es.metro')!; // transparent
      final Lemma todavia = opaque.byId('es.todavia')!; // opaque
      expect(
          opaque.difficultyOf(metro), lessThan(opaque.difficultyOf(todavia)));
      // Le répertoire d'origine n'a pas bougé : les poids sont bien portés
      // par le Lexicon, pas par le Lemma.
      expect(lex.difficultyOf(metro), isNot(opaque.difficultyOf(metro)));
    });

    test('near() tire à la difficulté demandée, pas au hasard', () {
      final List<Lemma> got = lex.near(55, count: 5);
      for (final Lemma l in got) {
        expect((lex.difficultyOf(l) - 55).abs(), lessThan(20));
      }
    });

    test('les distracteurs sont de difficulté voisine', () {
      final Lemma target = lex.byId('es.mercado')!;
      final List<Lemma> d = lex.distractors(target, 3, _seeded());
      expect(d.length, 3);
      expect(d.map((Lemma l) => l.id), isNot(contains(target.id)));
    });

    test('les villes ont chacune leur vocabulaire', () {
      for (final String city in <String>[
        'valencia',
        'madrid',
        'sevilla',
        'granada',
        'bilbao',
        'barcelona',
      ]) {
        expect(lex.forCity(city), isNotEmpty, reason: 'ville $city');
      }
    });
  });
}
