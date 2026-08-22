import 'package:kameo_engine/kameo_engine.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  final Map<String, Country> countries = <String, Country>{
    for (final String path in <String>[
      'es/countries/espana.json',
      'en/countries/uk.json',
      'en/countries/usa.json',
    ])
      path: Country.fromJsonString(loadContentFile(path)),
  };

  group('destinations', () {
    test('les trois pays se chargent', () {
      expect(countries, hasLength(3));
      for (final Country c in countries.values) {
        expect(c.cities, hasLength(6), reason: c.shortName);
        expect(c.outline.length, greaterThan(12), reason: c.shortName);
      }
    });

    test('chaque ville tombe bien à l intérieur de sa carte', () {
      // Une ville hors du contour se voit à l'œil nu : autant que le test
      // l'attrape avant l'utilisateur.
      for (final Country c in countries.values) {
        for (final City city in c.cities) {
          expect(
            c.contains(city.position),
            isTrue,
            reason: '${city.name} est hors de la carte de ${c.shortName}',
          );
        }
      }
    });

    test('les villes sont ordonnées et uniques', () {
      for (final Country c in countries.values) {
        expect(
          c.cities.map((City x) => x.order),
          <int>[1, 2, 3, 4, 5, 6],
          reason: c.shortName,
        );
        expect(c.cities.map((City x) => x.id).toSet(), hasLength(6));
      }
    });

    test('chaque ville porte une expression locale expliquée', () {
      for (final Country c in countries.values) {
        for (final City city in c.cities) {
          expect(city.expression.text, isNotEmpty);
          expect(
            city.expression.note.length,
            greaterThan(30),
            reason: '${city.name} : la note doit expliquer quand on l emploie',
          );
        }
      }
    });

    test('l identifiant de voyage combine langue et pays', () {
      expect(countries['en/countries/uk.json']!.journeyId, 'en_uk');
      expect(countries['en/countries/usa.json']!.journeyId, 'en_usa');
      // Deux destinations d'une même langue sont deux voyages distincts,
      // mais partagent le carnet de vocabulaire.
      expect(
        countries['en/countries/uk.json']!.lang,
        countries['en/countries/usa.json']!.lang,
      );
    });

    test('chaque destination a son accent', () {
      expect(countries['en/countries/uk.json']!.ttsLocale, 'en-GB');
      expect(countries['en/countries/usa.json']!.ttsLocale, 'en-US');
      expect(countries['es/countries/espana.json']!.ttsLocale, 'es-ES');
    });
  });

  group('vocabulaire par destination', () {
    final Lexicon en = Lexicon.fromJsonString(
      loadContentFile('en/lexicon-seed.json'),
    );

    test('le répertoire anglais distingue les deux rives', () {
      final List<Lemma> uk = en.forVariant('uk');
      final List<Lemma> us = en.forVariant('us');
      expect(uk.map((Lemma l) => l.term), contains('the tube'));
      expect(uk.map((Lemma l) => l.term), isNot(contains('subway')));
      expect(us.map((Lemma l) => l.term), contains('subway'));
      expect(us.map((Lemma l) => l.term), isNot(contains('the tube')));
      // Le vocabulaire commun reste dans les deux.
      expect(uk.map((Lemma l) => l.term), contains('water'));
      expect(us.map((Lemma l) => l.term), contains('water'));
    });

    test('les faux-amis du francophone sont marqués et expliqués', () {
      for (final String id in <String>[
        'en.actually',
        'en.library',
        'en.journey',
        'en.attend',
      ]) {
        final Lemma? l = en.byId(id);
        expect(l, isNotNull, reason: id);
        expect(l!.isTrap, isTrue, reason: id);
        expect(l.note, isNotNull, reason: id);
      }
    });

    test('un test de placement peut tourner sur l anglais', () {
      final PlacementEngine e = PlacementEngine(
        Lexicon('en', en.forVariant('uk')),
      );
      while (e.next() != null) {
        e.submit(correct: true);
      }
      expect(e.asked, inInclusiveRange(8, 18));
      expect(e.result().startTour, greaterThanOrEqualTo(1));
    });
  });
}
