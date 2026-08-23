import 'dart:math';

import 'package:kameo_engine/kameo_engine.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  final Lexicon es = loadSeedLexicon();
  final Country espana = Country.fromJsonString(
    loadContentFile('es/countries/espana.json'),
  );
  const CityObjectiveBuilder builder = CityObjectiveBuilder();
  final Map<String, CityObjective> objectives = builder.buildAll(
    lexicon: es,
    country: espana,
    tour: 1,
  );

  group('objectif de vocabulaire par ville', () {
    test('chaque ville reçoit son lot de mots', () {
      expect(objectives, hasLength(espana.cities.length));
      for (final CityObjective o in objectives.values) {
        expect(o.words.length, greaterThanOrEqualTo(6), reason: o.cityName);
        expect(o.required, lessThan(o.total), reason: o.cityName);
      }
    });

    test('aucun mot n est enseigné par deux villes', () {
      // Sans cette règle, la neuvième étape répéterait la première.
      final List<String> all = objectives.values
          .expand((CityObjective o) => o.words.map((Lemma l) => l.id))
          .toList();
      expect(all.toSet().length, all.length);
    });

    test('une ville enseigne d abord ses propres mots', () {
      final CityObjective valence = objectives['valencia']!;
      // Ses mots, à l'exception de ceux trop durs pour le tour — « probar »
      // est en P3 et attendra le tour 2.
      final Iterable<String> siens = es
          .forCity('valencia')
          .where((Lemma l) => es.bandOf(l).index <= Band.p2.index)
          .map((Lemma l) => l.id);
      expect(siens, isNotEmpty);
      for (final String id in siens) {
        expect(
          valence.words.map((Lemma l) => l.id),
          contains(id),
          reason: '$id devrait être enseigné à Valence',
        );
      }
      // Et les mots trop durs sont bien écartés, pas repoussés ailleurs.
      final Iterable<String> tousLesMots = objectives.values
          .expand((CityObjective o) => o.words)
          .map((Lemma l) => l.id);
      expect(tousLesMots, isNot(contains('es.probar')));
    });

    test('le tour 1 n enseigne pas de vocabulaire trop dur', () {
      for (final CityObjective o in objectives.values) {
        for (final Lemma l in o.words) {
          expect(
            es.bandOf(l).index,
            lessThanOrEqualTo(Band.p2.index),
            reason: '${l.term} en ${es.bandOf(l).name} au tour 1',
          );
        }
      }
    });

    test('la répartition est stable d un lancement à l autre', () {
      // Un objectif qui change entre deux ouvertures de l'app serait
      // incompréhensible : la sélection ne doit rien devoir au hasard.
      final Map<String, CityObjective> again = builder.buildAll(
        lexicon: es,
        country: espana,
        tour: 1,
      );
      for (final String id in objectives.keys) {
        expect(
          again[id]!.words.map((Lemma l) => l.id),
          objectives[id]!.words.map((Lemma l) => l.id),
        );
      }
    });
  });

  group('assimilation', () {
    test('un seul type d exercice réussi ne suffit pas', () {
      const DrillRecord r = DrillRecord();
      final DrillRecord after = r.withResult(
        DrillKind.recognize,
        success: true,
      );
      expect(after.isAssimilated, isFalse);
      expect(
        after.withResult(DrillKind.recall, success: true).isAssimilated,
        isTrue,
      );
    });

    test('un échec n efface jamais un type déjà réussi', () {
      final DrillRecord r = const DrillRecord()
          .withResult(DrillKind.recognize, success: true)
          .withResult(DrillKind.recall, success: false);
      expect(r.passedKinds, <DrillKind>{DrillKind.recognize});
      expect(r.wrong, 1);
    });

    test('le tampon demande la plupart des mots, pas tous', () {
      final CityObjective o = objectives['valencia']!;
      final Map<String, DrillRecord> records = <String, DrillRecord>{};
      for (final Lemma l in o.words.take(o.required)) {
        records[l.id] = const DrillRecord()
            .withResult(DrillKind.recognize, success: true)
            .withResult(DrillKind.recall, success: true);
      }
      expect(o.acquiredIn(records), o.required);
      expect(o.canStamp(records), isTrue);
      expect(o.required, lessThan(o.total));
    });
  });

  group('fabrication des exercices', () {
    const DrillBuilder drills = DrillBuilder();

    test('propose le type d exercice qui manque au mot', () {
      final CityObjective o = objectives['valencia']!;
      final Lemma first = o.words.first;
      final Map<String, DrillRecord> records = <String, DrillRecord>{
        first.id: const DrillRecord().withResult(
          DrillKind.recognize,
          success: true,
        ),
      };
      final List<Drill> session = drills.session(
        lexicon: es,
        objective: o,
        records: records,
        size: 12,
        random: Random(1),
      );
      final Drill forFirst = session.firstWhere(
        (Drill d) => d.lemma.id == first.id,
      );
      expect(forFirst.kind, DrillKind.recall);
    });

    test('chaque exercice a quatre propositions dont la bonne', () {
      final List<Drill> session = drills.session(
        lexicon: es,
        objective: objectives['madrid']!,
        records: const <String, DrillRecord>{},
        random: Random(2),
      );
      expect(session, hasLength(6));
      for (final Drill d in session) {
        expect(d.options, hasLength(4), reason: d.lemma.term);
        expect(d.options, contains(d.answer));
        expect(d.options.toSet().length, 4);
      }
    });

    test('l exercice d écoute porte le texte à prononcer', () {
      final CityObjective o = objectives['sevilla']!;
      final Map<String, DrillRecord> records = <String, DrillRecord>{
        for (final Lemma l in o.words)
          l.id: const DrillRecord()
              .withResult(DrillKind.recognize, success: true)
              .withResult(DrillKind.recall, success: true),
      };
      // Tous assimilés : la session bascule en révision, sans écoute muette.
      final List<Drill> revision = drills.session(
        lexicon: es,
        objective: o,
        records: records,
        random: Random(3),
      );
      expect(revision, isNotEmpty);
      for (final Drill d in revision) {
        if (d.kind == DrillKind.listen) expect(d.spoken, isNotNull);
      }
    });

    test('travaille en priorité les mots presque acquis', () {
      final CityObjective o = objectives['granada']!;
      final Lemma presqueAcquis = o.words.last;
      final Map<String, DrillRecord> records = <String, DrillRecord>{
        presqueAcquis.id: const DrillRecord().withResult(
          DrillKind.recognize,
          success: true,
        ),
      };
      final List<Drill> session = drills.session(
        lexicon: es,
        objective: o,
        records: records,
        size: 3,
        random: Random(4),
      );
      expect(session.first.lemma.id, presqueAcquis.id);
    });
  });

  group('les trois destinations tiennent la charge', () {
    test('chaque pays peut équiper ses neuf villes', () {
      for (final (String path, String lexPath, String? variant) c
          in <(String, String, String?)>[
            ('es/countries/espana.json', 'es/lexicon-seed.json', null),
            ('en/countries/uk.json', 'en/lexicon-seed.json', 'uk'),
            ('en/countries/usa.json', 'en/lexicon-seed.json', 'us'),
          ]) {
        final Country country = Country.fromJsonString(loadContentFile(c.$1));
        final Lexicon full = Lexicon.fromJsonString(loadContentFile(c.$2));
        final Lexicon lex = variantOf(full, c.$3);
        final Map<String, CityObjective> objs = builder.buildAll(
          lexicon: lex,
          country: country,
          tour: 1,
        );
        expect(objs, hasLength(9), reason: country.shortName);
        for (final CityObjective o in objs.values) {
          expect(
            o.words,
            isNotEmpty,
            reason: '${country.shortName} · ${o.cityName}',
          );
        }
      }
    });
  });
}

Lexicon variantOf(Lexicon full, String? variant) =>
    variant == null ? full : Lexicon(full.lang, full.forVariant(variant));
