import 'dart:math';

import 'models.dart';

/// La recette de composition d'une leçon (doc 02 §6).
class LessonRecipe {
  const LessonRecipe({
    this.fresh = 0.6,
    this.review = 0.2,
    this.personal = 0.2,
    this.size = 10,
    this.minPerSkill = 1,
    this.sameCityReviewBias = true,
  });

  final double fresh;
  final double review;
  final double personal;
  final int size;

  /// Chaque leçon travaille les trois compétences. C'est le garde-fou
  /// anti-Duolingo : impossible d'avancer en ne faisant que du QCM.
  final int minPerSkill;

  /// On révise en priorité les mots de la même ville : la révision est
  /// déguisée en voyage plutôt qu'affichée comme une corvée.
  final bool sameCityReviewBias;
}

class BuiltLesson {
  const BuiltLesson({
    required this.id,
    required this.title,
    required this.items,
    required this.freshCount,
    required this.reviewCount,
    required this.personalCount,
  });

  final String id;
  final String title;
  final List<Item> items;
  final int freshCount;
  final int reviewCount;
  final int personalCount;

  Map<Skill, int> get skillCounts {
    final Map<Skill, int> out = <Skill, int>{
      for (final Skill s in Skill.values) s: 0,
    };
    for (final Item i in items) {
      out[i.skill] = out[i.skill]! + 1;
    }
    return out;
  }
}

/// Assemble une leçon à partir d'un vivier d'items.
///
/// Conséquence importante : chaque leçon est différente pour chaque
/// utilisateur, sans multiplier le contenu à produire.
class LessonBuilder {
  const LessonBuilder({this.recipe = const LessonRecipe()});

  final LessonRecipe recipe;

  BuiltLesson build({
    required String lessonId,
    required String title,
    required List<Item> pool,
    List<VocabCard> dueCards = const <VocabCard>[],
    List<String> personalErrorLemmaIds = const <String>[],
    Set<String> completedItemIds = const <String>{},
    String? city,
    Random? random,
  }) {
    final Random rng = random ?? Random();
    final int size = min(recipe.size, pool.length);
    final Set<String> dueLemmas =
        dueCards.map((VocabCard c) => c.lemmaId).toSet();
    final Set<String> personal = personalErrorLemmaIds.toSet();

    bool touches(Item i, Set<String> ids) =>
        i.lexemes.any((String l) => ids.contains(l));

    final List<Item> reviewPool = pool
        .where((Item i) => touches(i, dueLemmas) && !touches(i, personal))
        .toList();
    final List<Item> personalPool =
        pool.where((Item i) => touches(i, personal)).toList();
    final List<Item> freshPool = pool
        .where((Item i) =>
            !completedItemIds.contains(i.id) &&
            !touches(i, dueLemmas) &&
            !touches(i, personal))
        .toList();

    if (recipe.sameCityReviewBias && city != null) {
      int cityFirst(Item a, Item b) =>
          (b.city == city ? 1 : 0).compareTo(a.city == city ? 1 : 0);
      reviewPool.sort(cityFirst);
      personalPool.sort(cityFirst);
    }
    freshPool.shuffle(rng);
    reviewPool.shuffle(rng);

    final List<Item> chosen = <Item>[];
    final Set<String> taken = <String>{};
    void takeFrom(List<Item> from, int n) {
      for (final Item i in from) {
        if (chosen.length >= size || n <= 0) return;
        if (taken.add(i.id)) {
          chosen.add(i);
          n--;
        }
      }
    }

    final int wantReview = (size * recipe.review).round();
    final int wantPersonal = (size * recipe.personal).round();
    takeFrom(personalPool, wantPersonal);
    final int personalCount = chosen.length;
    takeFrom(reviewPool, wantReview);
    final int reviewCount = chosen.length - personalCount;
    takeFrom(freshPool, size - chosen.length);
    // Les viviers peuvent être trop maigres : on complète avec ce qui reste
    // plutôt que de livrer une leçon tronquée.
    if (chosen.length < size) {
      takeFrom(pool, size - chosen.length);
    }

    _ensureSkillCoverage(chosen, pool, taken, size);
    chosen.shuffle(rng);

    return BuiltLesson(
      id: lessonId,
      title: title,
      items: List<Item>.unmodifiable(chosen),
      freshCount: chosen.length - reviewCount - personalCount,
      reviewCount: reviewCount,
      personalCount: personalCount,
    );
  }

  void _ensureSkillCoverage(
    List<Item> chosen,
    List<Item> pool,
    Set<String> taken,
    int size,
  ) {
    for (final Skill s in Skill.values) {
      if (chosen.where((Item i) => i.skill == s).length >= recipe.minPerSkill) {
        continue;
      }
      final Item? candidate = pool
          .where((Item i) => i.skill == s && !taken.contains(i.id))
          .firstOrNull;
      if (candidate == null) continue;
      // On remplace un item de la compétence la plus représentée : la leçon
      // garde sa taille, mais elle couvre les trois compétences.
      final Map<Skill, int> counts = <Skill, int>{
        for (final Skill k in Skill.values)
          k: chosen.where((Item i) => i.skill == k).length,
      };
      final Skill fattest = counts.entries
          .reduce((MapEntry<Skill, int> a, MapEntry<Skill, int> b) =>
              a.value >= b.value ? a : b)
          .key;
      final int idx = chosen.indexWhere((Item i) => i.skill == fattest);
      if (idx == -1 || counts[fattest]! <= recipe.minPerSkill) {
        if (chosen.length < size) chosen.add(candidate);
        continue;
      }
      taken.remove(chosen[idx].id);
      chosen[idx] = candidate;
      taken.add(candidate.id);
    }
  }
}
