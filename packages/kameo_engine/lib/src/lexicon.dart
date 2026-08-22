import 'dart:convert';
import 'dart:math';

import 'models.dart';

/// Le répertoire d'une langue (doc 03 §1).
///
/// Un seul objet, quatre usages : le test de placement, les leçons, le carnet
/// de l'utilisateur et la contrainte de génération de contenu.
class Lexicon {
  Lexicon(this.lang, List<Lemma> lemmas,
      {this.weights = DifficultyWeights.standard})
      : _lemmas = List<Lemma>.unmodifiable(lemmas) {
    for (final Lemma l in _lemmas) {
      if (_byId.containsKey(l.id)) {
        throw ArgumentError('Identifiant de lemme en double : ${l.id}');
      }
      _byId[l.id] = l;
      _difficulty[l.id] = l.difficulty(weights);
    }
    _sorted = List<Lemma>.from(_lemmas)
      ..sort((Lemma a, Lemma b) => difficultyOf(a).compareTo(difficultyOf(b)));
  }

  factory Lexicon.fromJson(Map<String, dynamic> json,
      {DifficultyWeights weights = DifficultyWeights.standard}) {
    final Map<String, dynamic> meta =
        (json['meta'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<dynamic> raw = json['lemmas'] as List<dynamic>;
    return Lexicon(
      meta['lang'] as String? ?? 'es',
      raw
          .map((dynamic e) => Lemma.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      weights: weights,
    );
  }

  factory Lexicon.fromJsonString(String source,
          {DifficultyWeights weights = DifficultyWeights.standard}) =>
      Lexicon.fromJson(jsonDecode(source) as Map<String, dynamic>,
          weights: weights);

  final String lang;
  final DifficultyWeights weights;
  final List<Lemma> _lemmas;
  final Map<String, Lemma> _byId = <String, Lemma>{};
  final Map<String, double> _difficulty = <String, double>{};
  late final List<Lemma> _sorted;

  List<Lemma> get lemmas => _lemmas;

  /// Les lemmes triés du plus facile au plus difficile.
  List<Lemma> get byDifficulty => List<Lemma>.unmodifiable(_sorted);

  int get length => _lemmas.length;

  Lemma? byId(String id) => _byId[id];

  double difficultyOf(Lemma l) => _difficulty[l.id] ?? l.difficulty(weights);

  Band bandOf(Lemma l) => Band.of(difficultyOf(l));

  List<Lemma> inBand(Band b) =>
      _sorted.where((Lemma l) => bandOf(l) == b).toList(growable: false);

  List<Lemma> forCity(String city) =>
      _lemmas.where((Lemma l) => l.city == city).toList(growable: false);

  List<Lemma> forTheme(String theme) => _lemmas
      .where((Lemma l) => l.themes.contains(theme))
      .toList(growable: false);

  /// Le vocabulaire valable pour une destination donnée.
  ///
  /// Un voyageur qui part à New York n'a rien à faire avec « pavement » :
  /// filtrer ici évite d'enseigner un mot qu'on n'entendra jamais sur place.
  List<Lemma> forVariant(String? variant) => _lemmas
      .where((Lemma l) => l.variant == null || l.variant == variant)
      .toList(growable: false);

  List<Lemma> get traps =>
      _lemmas.where((Lemma l) => l.isTrap).toList(growable: false);

  /// Les [count] lemmes les plus proches d'une difficulté cible.
  ///
  /// C'est la primitive du test de placement : on ne tire jamais au hasard,
  /// on tire à la difficulté courante.
  List<Lemma> near(
    double target, {
    int count = 6,
    Set<String> exclude = const <String>{},
    bool includeTraps = true,
  }) {
    final List<Lemma> pool = _lemmas
        .where(
            (Lemma l) => !exclude.contains(l.id) && (includeTraps || !l.isTrap))
        .toList()
      ..sort((Lemma a, Lemma b) => (difficultyOf(a) - target)
          .abs()
          .compareTo((difficultyOf(b) - target).abs()));
    return pool.take(count).toList(growable: false);
  }

  /// Un lemme tiré parmi les plus proches de la cible — assez déterministe
  /// pour être testable, assez varié pour ne pas répéter le même item.
  Lemma? pickNear(
    double target,
    Random rng, {
    Set<String> exclude = const <String>{},
    int spread = 6,
    bool includeTraps = true,
  }) {
    final List<Lemma> pool = near(target,
        count: spread, exclude: exclude, includeTraps: includeTraps);
    if (pool.isEmpty) return null;
    return pool[rng.nextInt(pool.length)];
  }

  /// Distracteurs plausibles : des lemmes de difficulté voisine, jamais le
  /// lemme lui-même. Un QCM dont les mauvaises réponses sont trop faciles ne
  /// mesure rien.
  List<Lemma> distractors(Lemma target, int count, Random rng) {
    final List<Lemma> pool = near(difficultyOf(target),
        count: count * 4 + 1, exclude: <String>{target.id});
    pool.shuffle(rng);
    return pool.take(count).toList(growable: false);
  }

  Map<Band, int> get distribution {
    final Map<Band, int> out = <Band, int>{
      for (final Band b in Band.values) b: 0
    };
    for (final Lemma l in _lemmas) {
      out[bandOf(l)] = out[bandOf(l)]! + 1;
    }
    return out;
  }
}
