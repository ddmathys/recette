import 'dart:math';

import 'package:kameo_engine/kameo_engine.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  List<Item> pool() => <Item>[
        for (int i = 0; i < 12; i++)
          item(id: 'neuf$i', lexemes: <String>['lex$i'], city: 'valencia'),
        for (int i = 0; i < 6; i++)
          item(
            id: 'oral$i',
            skill: Skill.parler,
            kind: ItemKind.speak,
            lexemes: <String>['oral$i'],
          ),
        for (int i = 0; i < 6; i++)
          item(
            id: 'ecoute$i',
            skill: Skill.ecouter,
            kind: ItemKind.listen,
            lexemes: <String>['ecoute$i'],
          ),
        for (int i = 0; i < 5; i++)
          item(id: 'revu$i', lexemes: <String>['due$i'], city: 'valencia'),
        for (int i = 0; i < 5; i++)
          item(id: 'perso$i', lexemes: <String>['err$i']),
      ];

  const LessonBuilder builder = LessonBuilder();
  final DateTime now = DateTime(2026, 9, 1);

  group('composition de leçon', () {
    test('respecte la recette 60 / 20 / 20', () {
      final BuiltLesson l = builder.build(
        lessonId: 'val.t1.paella',
        title: 'Commander une paella',
        pool: pool(),
        dueCards: <VocabCard>[
          for (int i = 0; i < 5; i++) VocabCard(lemmaId: 'due$i', dueAt: now),
        ],
        personalErrorLemmaIds: <String>['err0', 'err1', 'err2'],
        city: 'valencia',
        random: Random(1),
      );
      expect(l.items.length, 10);
      expect(l.reviewCount, 2);
      expect(l.personalCount, 2);
      expect(l.freshCount, 6);
    });

    test('couvre toujours les trois compétences', () {
      for (int seed = 0; seed < 50; seed++) {
        final BuiltLesson l = builder.build(
          lessonId: 'l',
          title: 't',
          pool: pool(),
          random: Random(seed),
        );
        for (final Skill s in Skill.values) {
          expect(l.skillCounts[s], greaterThanOrEqualTo(1),
              reason: 'graine $seed, compétence ${s.name}');
        }
      }
    });

    test('ne répète jamais un item dans la même leçon', () {
      final BuiltLesson l = builder.build(
        lessonId: 'l',
        title: 't',
        pool: pool(),
        dueCards: <VocabCard>[VocabCard(lemmaId: 'due0', dueAt: now)],
        personalErrorLemmaIds: <String>['err0'],
        random: Random(2),
      );
      final List<String> ids = l.items.map((Item i) => i.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('deux utilisateurs reçoivent des leçons différentes', () {
      final BuiltLesson a = builder.build(
          lessonId: 'l', title: 't', pool: pool(), random: Random(1));
      final BuiltLesson b = builder.build(
          lessonId: 'l', title: 't', pool: pool(), random: Random(2));
      expect(a.items.map((Item i) => i.id).toList(),
          isNot(b.items.map((Item i) => i.id).toList()));
    });

    test('est déterministe à graine égale', () {
      final BuiltLesson a = builder.build(
          lessonId: 'l', title: 't', pool: pool(), random: Random(7));
      final BuiltLesson b = builder.build(
          lessonId: 'l', title: 't', pool: pool(), random: Random(7));
      expect(a.items.map((Item i) => i.id), b.items.map((Item i) => i.id));
    });

    test('ne livre pas une leçon tronquée si un vivier est vide', () {
      final BuiltLesson l = builder.build(
        lessonId: 'l',
        title: 't',
        pool: pool(),
        dueCards: const <VocabCard>[],
        personalErrorLemmaIds: const <String>[],
        random: Random(3),
      );
      expect(l.items.length, 10);
    });

    test('révise en priorité les mots de la ville en cours', () {
      final BuiltLesson l = builder.build(
        lessonId: 'l',
        title: 't',
        pool: <Item>[
          ...pool(),
          item(id: 'ailleurs', lexemes: <String>['due0'], city: 'madrid'),
        ],
        dueCards: <VocabCard>[VocabCard(lemmaId: 'due0', dueAt: now)],
        city: 'valencia',
        random: Random(4),
      );
      final Iterable<Item> revus =
          l.items.where((Item i) => i.lexemes.contains('due0'));
      expect(revus, isNotEmpty);
      expect(revus.first.city, 'valencia');
    });
  });

  group('tolérance de correction', () {
    test('ignore accents, casse et ponctuation', () {
      const Item i = Item(
        id: 'x',
        kind: ItemKind.translate,
        skill: Skill.ecrire,
        rung: Rung.r3,
        cefr: 'A1',
        prompt: 'Je voudrais une paella',
        answer: 'Quiero una paella, por favor',
        alternates: <String>['Querría una paella, por favor'],
      );
      expect(i.accepts('quiero una paella por favor'), isTrue);
      expect(i.accepts('QUIERO  una paella,  por favor!'), isTrue);
      expect(i.accepts('Querria una paella por favor'), isTrue);
      expect(i.accepts('quiero una tortilla'), isFalse);
    });
  });
}
