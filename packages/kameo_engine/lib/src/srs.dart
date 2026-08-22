import 'dart:math';

import 'models.dart';

/// La note donnée à une révision.
enum Grade { again, hard, good, easy }

/// Configuration de la répétition espacée (doc 02 §5).
///
/// SM-2 avec trois ajustements Kameo : modulateur d'échelon, plafond
/// quotidien, et une descente d'échelon rare et lente.
class SrsConfig {
  const SrsConfig({
    this.minEase = 1.3,
    this.maxEase = 2.7,
    this.easeStep = 0.15,
    this.firstIntervalDays = 1,
    this.lapseIntervalDays = 1,
    this.successesToPromote = 2,
    this.lapsesToDemote = 3,
    this.masteredToRetire = 3,
    this.retiredIntervalDays = 180,
    this.dailyReviewCap = 25,
    this.promotionSpacing = const Duration(hours: 24),
  });

  final double minEase;
  final double maxEase;
  final double easeStep;
  final double firstIntervalDays;
  final double lapseIntervalDays;

  /// Deux réussites espacées d'au moins 24 h pour monter d'un échelon.
  final int successesToPromote;

  /// Trois échecs consécutifs pour redescendre — jamais un seul.
  final int lapsesToDemote;

  final int masteredToRetire;
  final double retiredIntervalDays;
  final int dailyReviewCap;
  final Duration promotionSpacing;
}

class SrsScheduler {
  const SrsScheduler({this.config = const SrsConfig()});

  final SrsConfig config;

  /// Applique une révision et renvoie la carte mise à jour.
  ///
  /// Invariant vérifié par les tests : un échec isolé ne fait jamais perdre
  /// d'échelon, il ne fait que rapprocher la prochaine révision.
  VocabCard review(VocabCard card, Grade grade, DateTime now) {
    final bool failed = grade == Grade.again;
    if (failed) return _lapse(card, now);

    final double ease = _adjustEase(card.ease, grade);
    final bool spaced = card.lastSuccessAt == null ||
        now.difference(card.lastSuccessAt!) >= config.promotionSpacing;
    final int successes = card.successesAtRung + (spaced ? 1 : 0);
    final bool promote =
        successes >= config.successesToPromote && card.rung != Rung.r4;
    final bool mastering =
        card.rung == Rung.r4 && successes >= config.successesToPromote;

    final Rung rung = promote ? card.rung.next : card.rung;
    final int masteredCount =
        mastering ? card.masteredCount + 1 : card.masteredCount;
    final bool retired = masteredCount >= config.masteredToRetire;

    final double interval = retired
        ? config.retiredIntervalDays
        : _nextInterval(card, ease, rung, grade);

    return card.copyWith(
      rung: rung,
      ease: ease,
      // Monter d'échelon remet le compteur à zéro : chaque échelon se gagne.
      successesAtRung: promote || mastering ? 0 : successes,
      consecutiveLapses: 0,
      intervalDays: interval,
      dueAt: _addDays(now, interval),
      lastSuccessAt: now,
      masteredCount: masteredCount,
      retired: retired,
    );
  }

  VocabCard _lapse(VocabCard card, DateTime now) {
    final int consecutive = card.consecutiveLapses + 1;
    final bool demote =
        consecutive >= config.lapsesToDemote && card.rung != Rung.r1;
    return card.copyWith(
      rung: demote ? card.rung.previous : card.rung,
      ease: max(config.minEase, card.ease - config.easeStep * 2),
      intervalDays: config.lapseIntervalDays,
      dueAt: _addDays(now, config.lapseIntervalDays),
      successesAtRung: 0,
      consecutiveLapses: demote ? 0 : consecutive,
      lapses: card.lapses + 1,
    );
  }

  double _nextInterval(VocabCard card, double ease, Rung rung, Grade grade) {
    final double base = card.intervalDays <= 0
        ? config.firstIntervalDays
        : card.intervalDays * ease * rung.intervalModifier;
    final double graded = switch (grade) {
      Grade.hard => base * 0.7,
      Grade.easy => base * 1.3,
      _ => base,
    };
    return max(config.firstIntervalDays, graded);
  }

  double _adjustEase(double ease, Grade grade) {
    final double delta = switch (grade) {
      Grade.hard => -config.easeStep,
      Grade.easy => config.easeStep,
      _ => 0.0,
    };
    return (ease + delta).clamp(config.minEase, config.maxEase);
  }

  static DateTime _addDays(DateTime from, double days) =>
      from.add(Duration(minutes: (days * 24 * 60).round()));

  /// La file de révision du jour : triée par urgence, plafonnée.
  ///
  /// Le plafond est ce qui évite l'arriéré à la Anki — le surplus est
  /// simplement réétalé, sans dette affichée (doc 02 §5.2).
  List<VocabCard> dueToday(Iterable<VocabCard> cards, DateTime now) {
    final List<VocabCard> due =
        cards.where((VocabCard c) => !c.retired && c.isDue(now)).toList()
          ..sort((VocabCard a, VocabCard b) {
            final int byRung = a.rung.index.compareTo(b.rung.index);
            return byRung != 0 ? byRung : a.dueAt.compareTo(b.dueAt);
          });
    return due.take(config.dailyReviewCap).toList(growable: false);
  }
}
