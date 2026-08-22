import 'package:kameo_engine/kameo_engine.dart';
import 'package:test/test.dart';

void main() {
  const SrsScheduler srs = SrsScheduler();
  final DateTime t0 = DateTime(2026, 9, 1, 9);
  VocabCard fresh() => VocabCard(lemmaId: 'es.paella', dueAt: t0);

  group('répétition espacée', () {
    test('les intervalles s allongent à chaque réussite', () {
      VocabCard c = fresh();
      final List<double> intervals = <double>[];
      DateTime now = t0;
      for (int i = 0; i < 5; i++) {
        c = srs.review(c, Grade.good, now);
        intervals.add(c.intervalDays);
        now = c.dueAt;
      }
      for (int i = 1; i < intervals.length; i++) {
        expect(intervals[i], greaterThan(intervals[i - 1]),
            reason: 'intervalles $intervals');
      }
    });

    test('un échec isolé ne fait jamais perdre d échelon', () {
      VocabCard c = fresh().copyWith(rung: Rung.r3, intervalDays: 30);
      c = srs.review(c, Grade.again, t0);
      expect(c.rung, Rung.r3);
      expect(c.intervalDays, 1);
      expect(c.dueAt, t0.add(const Duration(days: 1)));
      expect(c.lapses, 1);
    });

    test('trois échecs consécutifs font redescendre d un seul échelon', () {
      VocabCard c = fresh().copyWith(rung: Rung.r3);
      DateTime now = t0;
      for (int i = 0; i < 3; i++) {
        c = srs.review(c, Grade.again, now);
        now = now.add(const Duration(days: 1));
      }
      expect(c.rung, Rung.r2);
      expect(c.consecutiveLapses, 0,
          reason: 'le compteur repart après la descente');
    });

    test('une réussite après un échec remet le compteur d échecs à zéro', () {
      VocabCard c = fresh().copyWith(rung: Rung.r3);
      c = srs.review(c, Grade.again, t0);
      c = srs.review(c, Grade.good, t0.add(const Duration(days: 1)));
      expect(c.consecutiveLapses, 0);
      expect(c.rung, Rung.r3);
    });

    test('monter d échelon exige deux réussites espacées de 24 h', () {
      VocabCard c = fresh();
      c = srs.review(c, Grade.good, t0);
      expect(c.rung, Rung.r1);
      // Deux réussites le même jour ne suffisent pas : on ne monte pas
      // d'échelon en bachotant.
      c = srs.review(c, Grade.good, t0.add(const Duration(hours: 2)));
      expect(c.rung, Rung.r1);
      c = srs.review(c, Grade.good, t0.add(const Duration(days: 2)));
      expect(c.rung, Rung.r2);
    });

    test('un mot maîtrisé trois fois à R4 sort du cycle actif', () {
      VocabCard c = fresh().copyWith(rung: Rung.r4);
      DateTime now = t0;
      for (int i = 0; i < 6; i++) {
        c = srs.review(c, Grade.good, now);
        now = now.add(const Duration(days: 2));
      }
      expect(c.retired, isTrue);
      expect(c.intervalDays, 180);
      expect(c.rung, Rung.r4, reason: 'un mot acquis ne redescend pas');
    });

    test('un mot ajouté par l utilisateur démarre à R2', () {
      final VocabCard c =
          VocabCard.saved(lemmaId: 'es.guay', now: t0, city: 'madrid');
      expect(c.rung, Rung.r2);
      expect(c.source, 'user');
      expect(c.city, 'madrid');
    });

    test('le placement crédite les mots connus à J+7 et les ratés à J+1', () {
      final VocabCard known =
          VocabCard.fromPlacement(lemmaId: 'es.casa', now: t0, known: true);
      final VocabCard todo =
          VocabCard.fromPlacement(lemmaId: 'es.salir', now: t0, known: false);
      expect(known.dueAt, t0.add(const Duration(days: 7)));
      expect(todo.dueAt, t0.add(const Duration(days: 1)));
    });

    test('la file du jour est plafonnée et triée par échelon', () {
      final List<VocabCard> cards = <VocabCard>[
        for (int i = 0; i < 40; i++)
          VocabCard(
            lemmaId: 'l$i',
            dueAt: t0.subtract(Duration(minutes: i)),
            rung: Rung.values[i % 4],
          ),
        VocabCard(lemmaId: 'plus-tard', dueAt: t0.add(const Duration(days: 3))),
        VocabCard(lemmaId: 'acquis', dueAt: t0, retired: true),
      ];
      final List<VocabCard> due = srs.dueToday(cards, t0);
      expect(due.length, 25);
      expect(due.first.rung, Rung.r1);
      expect(due.map((VocabCard c) => c.lemmaId), isNot(contains('plus-tard')));
      expect(due.map((VocabCard c) => c.lemmaId), isNot(contains('acquis')));
    });

    test('la facilité reste dans ses bornes', () {
      VocabCard c = fresh();
      for (int i = 0; i < 30; i++) {
        c = srs.review(c, Grade.easy, t0.add(Duration(days: i * 2)));
      }
      expect(c.ease, lessThanOrEqualTo(2.7));
      for (int i = 0; i < 30; i++) {
        c = srs.review(c, Grade.again, t0.add(Duration(days: 100 + i)));
      }
      expect(c.ease, greaterThanOrEqualTo(1.3));
    });
  });
}
