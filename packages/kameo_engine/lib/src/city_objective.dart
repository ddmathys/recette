import 'dart:math';

import 'country.dart';
import 'lexicon.dart';
import 'models.dart';

/// Les trois façons d'interroger un mot, sans écrire une seule phrase de
/// contenu.
///
/// C'est ce qui permet de faire tourner l'apprentissage du vocabulaire dès
/// aujourd'hui : les exercices se fabriquent depuis le répertoire, l'IA n'est
/// nécessaire que pour les phrases en contexte et les dialogues.
enum DrillKind {
  /// Reconnaître : le mot étranger, choisir le sens.
  recognize,

  /// Restituer : le sens français, choisir le mot étranger.
  recall,

  /// Écouter : le mot prononcé, choisir le sens.
  listen,
}

/// Ce qu'un utilisateur a déjà réussi sur un mot.
class DrillRecord {
  const DrillRecord({
    this.passedKinds = const <DrillKind>{},
    this.correct = 0,
    this.wrong = 0,
  });

  final Set<DrillKind> passedKinds;
  final int correct;
  final int wrong;

  /// Un mot compte comme assimilé quand il a été réussi sur **deux types
  /// d'exercice différents** — reconnaître ne suffit pas, il faut aussi savoir
  /// le retrouver.
  ///
  /// C'est volontairement distinct de la maîtrise durable, qui relève de la
  /// répétition espacée : celle-ci exige des réussites espacées de 24 h, et
  /// aucune ville ne serait finissable en une session si le tampon en
  /// dépendait (doc 02 §2, les trois axes).
  bool get isAssimilated => passedKinds.length >= 2;

  DrillRecord withResult(DrillKind kind, {required bool success}) => DrillRecord(
    passedKinds: success
        ? <DrillKind>{...passedKinds, kind}
        : passedKinds,
    correct: correct + (success ? 1 : 0),
    wrong: wrong + (success ? 0 : 1),
  );
}

/// Le vocabulaire qu'une ville se charge d'enseigner à un tour donné.
class CityObjective {
  const CityObjective({
    required this.cityId,
    required this.cityName,
    required this.tour,
    required this.words,
    required this.required,
  });

  final String cityId;
  final String cityName;
  final int tour;
  final List<Lemma> words;

  /// Combien de mots doivent être assimilés pour décrocher le tampon.
  ///
  /// Jamais la totalité : la progression reste fluide, la complétion reste
  /// exigeante (doc 02 §7).
  final int required;

  int get total => words.length;

  int acquiredIn(Map<String, DrillRecord> records) => words
      .where((Lemma l) => records[l.id]?.isAssimilated ?? false)
      .length;

  bool canStamp(Map<String, DrillRecord> records) =>
      acquiredIn(records) >= required;

  /// Les mots qui restent à travailler, les moins avancés d'abord.
  List<Lemma> remaining(Map<String, DrillRecord> records) {
    final List<Lemma> left = words
        .where((Lemma l) => !(records[l.id]?.isAssimilated ?? false))
        .toList();
    left.sort((Lemma a, Lemma b) {
      final int pa = records[a.id]?.passedKinds.length ?? 0;
      final int pb = records[b.id]?.passedKinds.length ?? 0;
      return pb.compareTo(pa);
    });
    return left;
  }
}

/// Répartit le vocabulaire du répertoire entre les villes d'un pays.
///
/// Deux règles : chaque ville enseigne d'abord **ses** mots, et **aucun mot
/// n'est enseigné par deux villes** du même tour — sinon la neuvième étape
/// répéterait la première.
class CityObjectiveBuilder {
  const CityObjectiveBuilder({
    this.maxWordsPerCity = 12,
    this.minWordsPerCity = 6,
    this.requiredRatio = 0.8,
  });

  final int maxWordsPerCity;
  final int minWordsPerCity;
  final double requiredRatio;

  Map<String, CityObjective> buildAll({
    required Lexicon lexicon,
    required Country country,
    required int tour,
  }) {
    // On enseigne un palier au-dessus du tour, jamais deux (zone proximale).
    final int maxBand = min(Band.values.length - 1, tour);
    final List<Lemma> eligible =
        lexicon.lemmas
            .where((Lemma l) => lexicon.bandOf(l).index <= maxBand)
            .toList()
          ..sort(
            (Lemma a, Lemma b) => lexicon
                .difficultyOf(a)
                .compareTo(lexicon.difficultyOf(b)),
          );

    final int perCity = (eligible.length ~/ country.cities.length).clamp(
      minWordsPerCity,
      maxWordsPerCity,
    );

    final Set<String> taken = <String>{};
    final Map<String, CityObjective> out = <String, CityObjective>{};

    for (final City city in country.cities) {
      final List<Lemma> chosen = <Lemma>[];
      // 1. Les mots qui appartiennent à la ville.
      for (final Lemma l in eligible) {
        if (chosen.length >= perCity) break;
        if (l.city == city.id && taken.add(l.id)) chosen.add(l);
      }
      // 2. Puis le vocabulaire général, du plus utile au moins utile.
      for (final Lemma l in eligible) {
        if (chosen.length >= perCity) break;
        if (l.city == null && taken.add(l.id)) chosen.add(l);
      }
      // 3. En dernier recours, ce qui reste — un répertoire trop maigre ne
      //    doit pas produire une ville vide.
      for (final Lemma l in eligible) {
        if (chosen.length >= perCity) break;
        if (taken.add(l.id)) chosen.add(l);
      }
      out[city.id] = CityObjective(
        cityId: city.id,
        cityName: city.name,
        tour: tour,
        words: List<Lemma>.unmodifiable(chosen),
        required: max(1, (chosen.length * requiredRatio).round()),
      );
    }
    return out;
  }
}

/// Un exercice, fabriqué à la volée depuis le répertoire.
class Drill {
  const Drill({
    required this.lemma,
    required this.kind,
    required this.prompt,
    required this.answer,
    required this.options,
    this.spoken,
  });

  final Lemma lemma;
  final DrillKind kind;
  final String prompt;
  final String answer;
  final List<String> options;

  /// Le texte à faire prononcer, pour les exercices d'écoute.
  final String? spoken;
}

class DrillBuilder {
  const DrillBuilder();

  /// Compose une session courte.
  ///
  /// On travaille en priorité les mots les plus proches d'être assimilés :
  /// finir un mot vaut mieux qu'en effleurer trois.
  List<Drill> session({
    required Lexicon lexicon,
    required CityObjective objective,
    required Map<String, DrillRecord> records,
    int size = 6,
    Random? random,
  }) {
    final Random rng = random ?? Random();
    final List<Lemma> queue = objective.remaining(records);
    final List<Drill> drills = <Drill>[];
    for (final Lemma lemma in queue) {
      if (drills.length >= size) break;
      final DrillKind kind = _nextKindFor(records[lemma.id]);
      drills.add(_build(lexicon, lemma, kind, rng));
    }
    // Objectif atteint mais l'utilisateur veut continuer : on révise.
    if (drills.isEmpty) {
      final List<Lemma> all = List<Lemma>.from(objective.words)..shuffle(rng);
      for (final Lemma lemma in all.take(size)) {
        drills.add(_build(lexicon, lemma, DrillKind.recall, rng));
      }
    }
    return drills;
  }

  DrillKind _nextKindFor(DrillRecord? record) {
    final Set<DrillKind> passed = record?.passedKinds ?? const <DrillKind>{};
    for (final DrillKind k in DrillKind.values) {
      if (!passed.contains(k)) return k;
    }
    return DrillKind.recall;
  }

  Drill _build(Lexicon lexicon, Lemma lemma, DrillKind kind, Random rng) {
    final bool wantTerm = kind == DrillKind.recall;
    final List<Lemma> others = lexicon.distractors(lemma, 3, rng);
    final String answer = wantTerm ? lemma.term : lemma.fr;
    final List<String> options = <String>[
      answer,
      for (final Lemma l in others) wantTerm ? l.term : l.fr,
    ];
    final List<String> unique = <String>[];
    for (final String o in options) {
      if (!unique.any((String x) => x.toLowerCase() == o.toLowerCase())) {
        unique.add(o);
      }
    }
    unique.shuffle(rng);
    return Drill(
      lemma: lemma,
      kind: kind,
      prompt: switch (kind) {
        DrillKind.recognize => 'Que veut dire « ${lemma.term} » ?',
        DrillKind.recall => 'Comment dit-on « ${lemma.fr} » ?',
        DrillKind.listen => 'Écoute et choisis le sens',
      },
      answer: answer,
      options: unique,
      spoken: kind == DrillKind.listen ? lemma.term : null,
    );
  }
}
