import 'dart:math';

import 'models.dart';

/// Le journal d'événements (doc 04 §2).
///
/// On ne stocke pas « l'utilisateur a 2 340 XP », on stocke ce qui s'est
/// passé, et on en déduit l'état. Trois propriétés en découlent : rien ne
/// peut régresser, les règles peuvent changer rétroactivement, et le debug
/// devient lisible.
sealed class KEvent {
  const KEvent({required this.id, required this.ts, this.v = 1});

  /// Identifiant émis par le client : c'est lui qui rend le rejeu inoffensif.
  final String id;
  final DateTime ts;
  final int v;

  String get type;
}

final class PlacementCompleted extends KEvent {
  const PlacementCompleted({
    required super.id,
    required super.ts,
    required this.theta,
    required this.skills,
    required this.startTour,
    required this.journeyId,
  });

  final double theta;
  final Map<Skill, double> skills;
  final int startTour;
  final String journeyId;

  @override
  String get type => 'placement_completed';
}

final class LessonCompleted extends KEvent {
  const LessonCompleted({
    required super.id,
    required super.ts,
    required this.journeyId,
    required this.cityId,
    required this.lessonId,
    required this.tour,
    required this.correct,
    required this.total,
    this.heartsLost = 0,
    this.skillCounts = const <Skill, int>{},
  });

  final String journeyId;
  final String cityId;
  final String lessonId;
  final int tour;
  final int correct;
  final int total;
  final int heartsLost;
  final Map<Skill, int> skillCounts;

  double get accuracy => total == 0 ? 0 : correct / total;
  bool get isPerfect => total > 0 && correct == total;

  @override
  String get type => 'lesson_completed';
}

final class StampEarned extends KEvent {
  const StampEarned({
    required super.id,
    required super.ts,
    required this.journeyId,
    required this.cityId,
    required this.tour,
  });

  final String journeyId;
  final String cityId;
  final int tour;

  @override
  String get type => 'stamp_earned';
}

final class TourValidated extends KEvent {
  const TourValidated({
    required super.id,
    required super.ts,
    required this.journeyId,
    required this.tour,
  });

  final String journeyId;
  final int tour;

  @override
  String get type => 'tour_validated';
}

final class WordSaved extends KEvent {
  const WordSaved({
    required super.id,
    required super.ts,
    required this.lemmaId,
    this.cityId,
  });

  final String lemmaId;
  final String? cityId;

  @override
  String get type => 'word_saved';
}

final class WordReviewed extends KEvent {
  const WordReviewed({
    required super.id,
    required super.ts,
    required this.lemmaId,
    required this.correct,
  });

  final String lemmaId;
  final bool correct;

  @override
  String get type => 'word_reviewed';
}

final class HeartSpent extends KEvent {
  const HeartSpent({required super.id, required super.ts});

  @override
  String get type => 'heart_spent';
}

final class StreakExtended extends KEvent {
  const StreakExtended({
    required super.id,
    required super.ts,
    required this.day,
  });

  /// Le jour civil concerné, normalisé à minuit.
  final DateTime day;

  @override
  String get type => 'streak_extended';
}

final class GoalChanged extends KEvent {
  const GoalChanged({
    required super.id,
    required super.ts,
    required this.dailyGoal,
  });

  final int dailyGoal;

  @override
  String get type => 'goal_changed';
}

/// Les paramètres d'économie. Ils vivent dans Remote Config, pas dans le
/// code : on doit pouvoir rééquilibrer sans passer par une release.
class EconomyConfig {
  const EconomyConfig({
    this.xpPerLesson = 12,
    this.xpPerfectBonus = 6,
    this.xpPerStamp = 40,
    this.xpPerTour = 250,
    this.gemsPerLesson = 1,
    this.gemsPerfectBonus = 2,
    this.gemsPerStamp = 10,
    this.maxHearts = 5,
    this.heartRefill = const Duration(hours: 4),
  });

  final int xpPerLesson;
  final int xpPerfectBonus;
  final int xpPerStamp;
  final int xpPerTour;
  final int gemsPerLesson;
  final int gemsPerfectBonus;
  final int gemsPerStamp;
  final int maxHearts;
  final Duration heartRefill;
}

/// L'état d'un voyage (un couple langue × pays).
class JourneyState {
  const JourneyState({
    this.currentTour = 1,
    this.stamps = const <String, int>{},
    this.validatedTours = const <int>{},
  });

  final int currentTour;

  /// cityId → tour le plus élevé auquel la ville a été tamponnée.
  final Map<String, int> stamps;
  final Set<int> validatedTours;

  int stampsAtTour(int tour) =>
      stamps.values.where((int t) => t >= tour).length;

  JourneyState copyWith({
    int? currentTour,
    Map<String, int>? stamps,
    Set<int>? validatedTours,
  }) =>
      JourneyState(
        currentTour: currentTour ?? this.currentTour,
        stamps: stamps ?? this.stamps,
        validatedTours: validatedTours ?? this.validatedTours,
      );
}

/// L'état dérivé d'un profil. Recalculable à tout moment depuis le journal.
class ProfileState {
  const ProfileState({
    this.xp = 0,
    this.gems = 0,
    this.hearts = 5,
    this.lastHeartSpentAt,
    this.streak = 0,
    this.lastStreakDay,
    this.dailyGoal = 2,
    this.skills = const <Skill, double>{},
    this.journeys = const <String, JourneyState>{},
    this.savedLemmaIds = const <String>{},
    this.appliedEventIds = const <String>{},
    this.lastEventId,
  });

  final int xp;
  final int gems;
  final int hearts;
  final DateTime? lastHeartSpentAt;
  final int streak;
  final DateTime? lastStreakDay;
  final int dailyGoal;
  final Map<Skill, double> skills;
  final Map<String, JourneyState> journeys;
  final Set<String> savedLemmaIds;
  final Set<String> appliedEventIds;
  final String? lastEventId;

  JourneyState journey(String id) => journeys[id] ?? const JourneyState();

  int get totalStamps =>
      journeys.values.fold(0, (int a, JourneyState j) => a + j.stamps.length);

  ProfileState copyWith({
    int? xp,
    int? gems,
    int? hearts,
    DateTime? lastHeartSpentAt,
    int? streak,
    DateTime? lastStreakDay,
    int? dailyGoal,
    Map<Skill, double>? skills,
    Map<String, JourneyState>? journeys,
    Set<String>? savedLemmaIds,
    Set<String>? appliedEventIds,
    String? lastEventId,
  }) =>
      ProfileState(
        xp: xp ?? this.xp,
        gems: gems ?? this.gems,
        hearts: hearts ?? this.hearts,
        lastHeartSpentAt: lastHeartSpentAt ?? this.lastHeartSpentAt,
        streak: streak ?? this.streak,
        lastStreakDay: lastStreakDay ?? this.lastStreakDay,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        skills: skills ?? this.skills,
        journeys: journeys ?? this.journeys,
        savedLemmaIds: savedLemmaIds ?? this.savedLemmaIds,
        appliedEventIds: appliedEventIds ?? this.appliedEventIds,
        lastEventId: lastEventId ?? this.lastEventId,
      );
}

/// Le réducteur : journal → état.
class EventReducer {
  const EventReducer({this.economy = const EconomyConfig()});

  final EconomyConfig economy;

  /// Applique un événement. Idempotent : rejouer le même `id` ne change rien.
  ProfileState reduce(ProfileState s, KEvent e) {
    if (s.appliedEventIds.contains(e.id)) return s;
    final ProfileState next = switch (e) {
      PlacementCompleted() => _placement(s, e),
      LessonCompleted() => _lesson(s, e),
      StampEarned() => _stamp(s, e),
      TourValidated() => _tour(s, e),
      WordSaved() => s.copyWith(
          savedLemmaIds: <String>{...s.savedLemmaIds, e.lemmaId},
        ),
      WordReviewed() => s,
      HeartSpent() => s.copyWith(
          hearts: max(0, s.hearts - 1),
          lastHeartSpentAt: e.ts,
        ),
      StreakExtended() => _streak(s, e),
      GoalChanged() => s.copyWith(dailyGoal: e.dailyGoal),
    };
    return next.copyWith(
      appliedEventIds: <String>{...s.appliedEventIds, e.id},
      lastEventId: e.id,
    );
  }

  ProfileState replay(Iterable<KEvent> events, {ProfileState? from}) {
    ProfileState s = from ?? const ProfileState();
    for (final KEvent e in events) {
      s = reduce(s, e);
    }
    return s;
  }

  ProfileState _placement(ProfileState s, PlacementCompleted e) {
    final JourneyState j = s.journey(e.journeyId);
    return s.copyWith(
      skills: e.skills,
      journeys: <String, JourneyState>{
        ...s.journeys,
        // Un placement ne peut que faire avancer : refaire le test plus tard
        // avec un mauvais jour ne doit pas renvoyer l'utilisateur en arrière.
        e.journeyId: j.copyWith(currentTour: max(j.currentTour, e.startTour)),
      },
    );
  }

  ProfileState _lesson(ProfileState s, LessonCompleted e) {
    final int xp =
        economy.xpPerLesson + (e.isPerfect ? economy.xpPerfectBonus : 0);
    final int gems =
        economy.gemsPerLesson + (e.isPerfect ? economy.gemsPerfectBonus : 0);
    return s.copyWith(xp: s.xp + xp, gems: s.gems + gems);
  }

  ProfileState _stamp(ProfileState s, StampEarned e) {
    final JourneyState j = s.journey(e.journeyId);
    final int had = j.stamps[e.cityId] ?? 0;
    // Un tampon ne se reprend jamais et ne redescend jamais de niveau.
    if (had >= e.tour) return s;
    return s.copyWith(
      xp: s.xp + economy.xpPerStamp,
      gems: s.gems + economy.gemsPerStamp,
      journeys: <String, JourneyState>{
        ...s.journeys,
        e.journeyId: j.copyWith(
          stamps: <String, int>{...j.stamps, e.cityId: e.tour},
        ),
      },
    );
  }

  ProfileState _tour(ProfileState s, TourValidated e) {
    final JourneyState j = s.journey(e.journeyId);
    if (j.validatedTours.contains(e.tour)) return s;
    return s.copyWith(
      xp: s.xp + economy.xpPerTour,
      journeys: <String, JourneyState>{
        ...s.journeys,
        e.journeyId: j.copyWith(
          validatedTours: <int>{...j.validatedTours, e.tour},
          currentTour: max(j.currentTour, e.tour + 1),
        ),
      },
    );
  }

  ProfileState _streak(ProfileState s, StreakExtended e) {
    final DateTime day = DateTime(e.day.year, e.day.month, e.day.day);
    final DateTime? last = s.lastStreakDay;
    if (last != null && !day.isAfter(last)) return s;
    final bool consecutive = last != null && day.difference(last).inDays == 1;
    return s.copyWith(
      streak: consecutive ? s.streak + 1 : 1,
      lastStreakDay: day,
    );
  }

  /// Les cœurs se régénèrent avec le temps, pas avec un événement : c'est une
  /// fonction de l'horloge, calculée à l'affichage.
  int heartsAt(ProfileState s, DateTime now) {
    if (s.hearts >= economy.maxHearts) return economy.maxHearts;
    final DateTime? since = s.lastHeartSpentAt;
    if (since == null) return s.hearts;
    final int gained =
        now.difference(since).inMinutes ~/ economy.heartRefill.inMinutes;
    return min(economy.maxHearts, s.hearts + gained);
  }
}
