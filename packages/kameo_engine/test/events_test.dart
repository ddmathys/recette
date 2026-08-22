import 'package:kameo_engine/kameo_engine.dart';
import 'package:test/test.dart';

void main() {
  const EventReducer reducer = EventReducer();
  final DateTime t0 = DateTime(2026, 9, 1, 9);
  const String journey = 'es_espana';

  LessonCompleted lesson(String id, {int correct = 10}) => LessonCompleted(
        id: id,
        ts: t0,
        journeyId: journey,
        cityId: 'valencia',
        lessonId: 'val.t1.paella',
        tour: 1,
        correct: correct,
        total: 10,
      );

  group('journal d événements', () {
    test('rejouer le même événement ne change rien', () {
      final ProfileState once =
          reducer.reduce(const ProfileState(), lesson('e1'));
      final ProfileState twice = reducer.reduce(once, lesson('e1'));
      expect(twice.xp, once.xp);
      expect(twice.gems, once.gems);
      expect(once.xp, 18, reason: '12 + 6 de bonus sans faute');
    });

    test('rejouer tout le journal donne le même état que l incrémental', () {
      final List<KEvent> journal = <KEvent>[
        lesson('e1'),
        lesson('e2', correct: 8),
        StampEarned(
            id: 'e3', ts: t0, journeyId: journey, cityId: 'valencia', tour: 1),
        WordSaved(id: 'e4', ts: t0, lemmaId: 'es.guay', cityId: 'madrid'),
        StreakExtended(id: 'e5', ts: t0, day: t0),
      ];
      ProfileState incremental = const ProfileState();
      for (final KEvent e in journal) {
        incremental = reducer.reduce(incremental, e);
      }
      final ProfileState replayed = reducer.replay(journal);
      expect(replayed.xp, incremental.xp);
      expect(replayed.totalStamps, incremental.totalStamps);
      expect(replayed.savedLemmaIds, incremental.savedLemmaIds);
      expect(replayed.streak, incremental.streak);
    });

    test('un tampon ne se reprend jamais et ne redescend jamais', () {
      ProfileState s = reducer.replay(<KEvent>[
        StampEarned(
            id: 'a', ts: t0, journeyId: journey, cityId: 'valencia', tour: 2),
        // Un événement plus ancien, arrivé en retard depuis un autre appareil.
        StampEarned(
            id: 'b', ts: t0, journeyId: journey, cityId: 'valencia', tour: 1),
      ]);
      expect(s.journey(journey).stamps['valencia'], 2);
      s = reducer.reduce(
          s,
          StampEarned(
              id: 'c', ts: t0, journeyId: journey, cityId: 'bilbao', tour: 1));
      expect(s.totalStamps, 2);
    });

    test('le tour courant ne recule jamais, même après un placement raté', () {
      ProfileState s = reducer.reduce(
        const ProfileState(),
        TourValidated(id: 'v1', ts: t0, journeyId: journey, tour: 2),
      );
      expect(s.journey(journey).currentTour, 3);
      s = reducer.reduce(
        s,
        PlacementCompleted(
          id: 'p1',
          ts: t0,
          theta: 12,
          skills: const <Skill, double>{},
          startTour: 1,
          journeyId: journey,
        ),
      );
      expect(s.journey(journey).currentTour, 3,
          reason: 'refaire le test un mauvais jour ne renvoie pas en arrière');
    });

    test('valider deux fois le même tour ne double pas l XP', () {
      final ProfileState s = reducer.replay(<KEvent>[
        TourValidated(id: 'v1', ts: t0, journeyId: journey, tour: 1),
        TourValidated(id: 'v2', ts: t0, journeyId: journey, tour: 1),
      ]);
      expect(s.xp, 250);
      expect(s.journey(journey).validatedTours, <int>{1});
    });

    test('l XP ne décroît jamais, quel que soit le journal', () {
      final List<KEvent> journal = <KEvent>[
        for (int i = 0; i < 20; i++) lesson('e$i', correct: i % 11),
        StampEarned(
            id: 's1', ts: t0, journeyId: journey, cityId: 'valencia', tour: 1),
        HeartSpent(id: 'h1', ts: t0),
        WordReviewed(id: 'w1', ts: t0, lemmaId: 'es.paella', correct: false),
      ];
      int previous = 0;
      ProfileState s = const ProfileState();
      for (final KEvent e in journal) {
        s = reducer.reduce(s, e);
        expect(s.xp, greaterThanOrEqualTo(previous));
        previous = s.xp;
      }
    });

    test('le streak compte les jours consécutifs et ignore les doublons', () {
      final ProfileState s = reducer.replay(<KEvent>[
        StreakExtended(id: 'd1', ts: t0, day: DateTime(2026, 9, 1)),
        StreakExtended(id: 'd2', ts: t0, day: DateTime(2026, 9, 1, 22)),
        StreakExtended(id: 'd3', ts: t0, day: DateTime(2026, 9, 2)),
        StreakExtended(id: 'd4', ts: t0, day: DateTime(2026, 9, 3)),
      ]);
      expect(s.streak, 3);
    });

    test('un jour sauté repart à 1', () {
      final ProfileState s = reducer.replay(<KEvent>[
        StreakExtended(id: 'd1', ts: t0, day: DateTime(2026, 9, 1)),
        StreakExtended(id: 'd2', ts: t0, day: DateTime(2026, 9, 5)),
      ]);
      expect(s.streak, 1);
    });

    test('les cœurs se régénèrent avec l horloge', () {
      final ProfileState s = reducer.replay(<KEvent>[
        HeartSpent(id: 'h1', ts: t0),
        HeartSpent(id: 'h2', ts: t0),
      ]);
      expect(s.hearts, 3);
      expect(reducer.heartsAt(s, t0), 3);
      expect(reducer.heartsAt(s, t0.add(const Duration(hours: 4))), 4);
      expect(reducer.heartsAt(s, t0.add(const Duration(days: 1))), 5);
    });

    test('changer les règles d économie re-calcule tout le passé', () {
      final List<KEvent> journal = <KEvent>[lesson('e1'), lesson('e2')];
      const EventReducer genereux = EventReducer(
          economy: EconomyConfig(xpPerLesson: 24, xpPerfectBonus: 12));
      expect(reducer.replay(journal).xp, 36);
      expect(genereux.replay(journal).xp, 72);
    });
  });
}
