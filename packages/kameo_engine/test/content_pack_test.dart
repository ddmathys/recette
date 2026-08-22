import 'dart:convert';
import 'dart:math';

import 'package:kameo_engine/kameo_engine.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  final Lexicon lex = loadSeedLexicon();
  final CityPack pack = CityPack.fromJsonString(
    loadContentFile('es/packs/2026-08-22_v1/valencia.t1.json'),
  );

  group('pack de ville', () {
    test('se charge et expose son contenu', () {
      expect(pack.cityId, 'valencia');
      expect(pack.tour, 1);
      expect(pack.lessons, hasLength(3));
      expect(pack.allItems, hasLength(17));
      expect(pack.localExpression.text, '¡Qué rico!');
    });

    test('refuse un schéma d une autre version', () {
      expect(
        () => CityPack.fromJson(const <String, dynamic>{'schemaVersion': 99}),
        throwsA(isA<FormatException>()),
      );
    });

    test('tous ses lexèmes existent dans le répertoire', () {
      for (final String id in pack.lexemes) {
        expect(lex.byId(id), isNotNull, reason: 'lexème orphelin : $id');
      }
    });

    test('son vocabulaire reste à portée du tour 1', () {
      for (final String id in pack.lexemes) {
        expect(
          lex.bandOf(lex.byId(id)!).index,
          lessThanOrEqualTo(Band.p3.index),
          reason: '${lex.byId(id)!.term} est trop dur pour le tour 1',
        );
      }
    });

    test('chaque leçon travaille les trois compétences', () {
      for (final PackLesson l in pack.lessons) {
        final Set<Skill> skills = l.items.map((Item i) => i.skill).toSet();
        expect(skills, containsAll(Skill.values), reason: l.id);
      }
    });

    test('tout ce qui se prononce a un texte à prononcer', () {
      for (final Item i in pack.allItems) {
        if (i.kind == ItemKind.listen ||
            i.kind == ItemKind.speak ||
            i.kind == ItemKind.dialogue) {
          expect(i.spokenText, isNotNull, reason: i.id);
          expect(i.audioRef, isNotNull, reason: i.id);
        }
      }
    });

    test('l épreuve de tampon mélange les compétences et contient un oral', () {
      final Set<Skill> skills =
          pack.stampChallenge.items.map((Item i) => i.skill).toSet();
      expect(skills, contains(Skill.parler));
      expect(skills.length, greaterThanOrEqualTo(2));
    });

    test('un pack non relu par un humain est signalé comme tel', () {
      // Le pack de référence n'a pas encore été relu par un natif : le moteur
      // doit le dire, pour que l'app puisse refuser de le servir.
      expect(pack.humanReviewed, isFalse);
    });
  });

  group('du contenu à la leçon jouée', () {
    test('le moteur compose une leçon à partir du pack réel', () {
      const LessonBuilder builder = LessonBuilder(
        recipe: LessonRecipe(size: 5),
      );
      final PackLesson source = pack.lessons.first;
      final BuiltLesson built = builder.build(
        lessonId: source.id,
        title: source.title,
        pool: source.items,
        city: pack.cityId,
        random: Random(1),
      );
      expect(built.items, hasLength(5));
      for (final Skill s in Skill.values) {
        expect(built.skillCounts[s], greaterThanOrEqualTo(1));
      }
    });

    test('la révision d un mot dû ramène l item de la bonne ville', () {
      const LessonBuilder builder = LessonBuilder(
        recipe: LessonRecipe(size: 5),
      );
      final BuiltLesson built = builder.build(
        lessonId: 'mix',
        title: 'Révision',
        pool: pack.allItems,
        dueCards: <VocabCard>[
          VocabCard(lemmaId: 'es.gustar', dueAt: DateTime(2026, 9, 1)),
        ],
        city: pack.cityId,
        random: Random(2),
      );
      expect(built.reviewCount, greaterThanOrEqualTo(1));
      expect(
        built.items.any((Item i) => i.lexemes.contains('es.gustar')),
        isTrue,
      );
    });

    test('la correction accepte les accents et la ponctuation approximatifs',
        () {
      final Item translate = pack.lessons.first.items
          .firstWhere((Item i) => i.kind == ItemKind.translate);
      expect(translate.accepts('quiero una paella por favor'), isTrue);
      expect(translate.accepts('QUIERO  una  paella, por favor !'), isTrue);
      expect(translate.accepts('quiero una tortilla'), isFalse);
    });
  });

  group('parité de la formule de difficulté', () {
    test('Dart et le pipeline Node calculent la même chose', () {
      // Le témoin est produit par tools/emit-difficulty-fixture.mjs. Si un
      // poids change d'un seul côté, ce test casse — c'est tout son intérêt.
      final Map<String, dynamic> fixture =
          jsonDecode(loadContentFile('es/difficulty-fixture.json'))
              as Map<String, dynamic>;
      final Map<String, dynamic> expected =
          fixture['difficulties'] as Map<String, dynamic>;
      expect(expected, hasLength(lex.length));
      for (final MapEntry<String, dynamic> e in expected.entries) {
        final Lemma? lemma = lex.byId(e.key);
        expect(lemma, isNotNull, reason: e.key);
        expect(
          lex.difficultyOf(lemma!),
          closeTo((e.value as num).toDouble(), 0.0001),
          reason: '${lemma.term} : Dart ${lex.difficultyOf(lemma)} '
              'vs Node ${e.value}',
        );
      }
    });

    test('et les mêmes paliers', () {
      final Map<String, dynamic> fixture =
          jsonDecode(loadContentFile('es/difficulty-fixture.json'))
              as Map<String, dynamic>;
      final Map<String, dynamic> bands =
          fixture['bands'] as Map<String, dynamic>;
      for (final MapEntry<String, dynamic> e in bands.entries) {
        expect(lex.bandOf(lex.byId(e.key)!).name.toUpperCase(), e.value);
      }
    });
  });
}
