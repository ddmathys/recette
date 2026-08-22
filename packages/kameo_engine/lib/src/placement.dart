import 'dart:math';

import 'lexicon.dart';
import 'models.dart';

/// Le format d'une question de placement. On alterne pour mesurer les
/// compétences séparément (doc 03 §4.2).
enum PlacementFormat {
  /// ES → FR : reconnaître.
  recognize,

  /// FR → ES : rappeler.
  produce,

  /// audio → sens : écouter.
  listen,
}

extension PlacementFormatSkill on PlacementFormat {
  Skill get skill => switch (this) {
        PlacementFormat.recognize => Skill.ecrire,
        PlacementFormat.produce => Skill.ecrire,
        PlacementFormat.listen => Skill.ecouter,
      };
}

class PlacementConfig {
  const PlacementConfig({
    this.theta0 = 40,
    this.step0 = 20,
    this.decay = 0.75,
    this.minStep = 4,
    this.seStop = 5.5,
    this.minItems = 8,
    this.maxItems = 18,
    this.trapCount = 2,
    this.maxTour = 3,
  });

  final double theta0;
  final double step0;
  final double decay;
  final double minStep;

  /// On s'arrête quand l'estimation est assez sûre, pas après un nombre fixe
  /// de questions. Mesuré : s'arrêter sur le pas de l'escalier coûtait un
  /// tiers de la précision pour six questions gagnées.
  final double seStop;

  final int minItems;
  final int maxItems;

  /// Nombre de faux-amis glissés dans le test. Ils ne comptent pas dans le
  /// score : ils alimentent le carnet.
  final int trapCount;

  /// On ne place jamais au-dessus du contenu qui existe (doc 03 §4.3).
  final int maxTour;
}

class PlacementQuestion {
  const PlacementQuestion({
    required this.lemma,
    required this.format,
    required this.isTrap,
    required this.index,
  });

  final Lemma lemma;
  final PlacementFormat format;
  final bool isTrap;
  final int index;

  String get prompt => switch (format) {
        PlacementFormat.recognize => 'Que veut dire « ${lemma.es} » ?',
        PlacementFormat.produce => 'Comment dit-on « ${lemma.fr} » ?',
        PlacementFormat.listen => 'Écoute et choisis le sens',
      };

  String get expected =>
      format == PlacementFormat.produce ? lemma.es : lemma.fr;
}

class PlacementResult {
  const PlacementResult({
    required this.theta,
    required this.standardError,
    required this.isBankLimited,
    required this.skills,
    required this.itemsAsked,
    required this.level,
    required this.cefr,
    required this.startTour,
    required this.knownLemmaIds,
    required this.toWorkLemmaIds,
  });

  final double theta;

  /// Incertitude de l'estimation, sur la même échelle 0-100.
  final double standardError;

  final Map<Skill, double> skills;
  final int itemsAsked;
  final String level;
  final String cefr;
  final int startTour;

  /// Les lemmes crédités comme connus : ils entrent au carnet à R1 acquis.
  final List<String> knownLemmaIds;

  /// Les pièges où l'utilisateur est tombé : ils entrent au carnet à revoir.
  final List<String> toWorkLemmaIds;

  Band get band => Band.of(theta);

  /// Vrai quand l'utilisateur a atteint le plafond du répertoire : ses
  /// réponses justes sur les items les plus durs disponibles ne permettent
  /// plus de le situer. On le dit, plutôt que d'inventer un niveau.
  final bool isBankLimited;

  /// On n'impose jamais le résultat, mais on sait quand il est solide.
  bool get isConfident => standardError <= 10 && !isBankLimited;
}

/// L'escalier adaptatif du doc 03 §4.2.
///
/// Volontairement simple : pas de modèle IRT complet, mais une convergence
/// mesurable en 8 à 14 questions, et un θ sur la même échelle 0-100 que la
/// difficulté du répertoire — donc directement interprétable.
class PlacementEngine {
  PlacementEngine(
    this.lexicon, {
    this.config = const PlacementConfig(),
    Random? random,
  })  : _rng = random ?? Random(),
        _theta = config.theta0,
        _step = config.step0;

  final Lexicon lexicon;
  final PlacementConfig config;
  final Random _rng;

  double _theta;
  double _step;
  final List<({double difficulty, bool correct})> _responses =
      <({double difficulty, bool correct})>[];
  int _asked = 0;
  int _trapsAsked = 0;
  final Set<String> _seen = <String>{};
  final List<String> _known = <String>[];
  final List<String> _toWork = <String>[];
  final Map<Skill, List<bool>> _perSkill = <Skill, List<bool>>{
    for (final Skill s in Skill.values) s: <bool>[],
  };
  PlacementQuestion? _current;

  /// La position courante de l'escalier. Elle sert à **choisir** l'item
  /// suivant — pas à noter l'utilisateur.
  double get theta => _theta;

  double get step => _step;
  int get asked => _asked;

  /// L'estimation finale du niveau.
  ///
  /// L'escalier converge vite mais s'arrête là où il se trouve, à un demi-pas
  /// près. On note donc l'utilisateur sur **toutes** ses réponses, par
  /// maximum a posteriori (Rasch régularisé) : deux fois moins d'erreur pour
  /// quelques microsecondes de calcul.
  double get estimate => _posterior().theta;

  /// L'incertitude de l'estimation. Elle grandit quand le répertoire n'a plus
  /// d'items à la hauteur de l'utilisateur : c'est le signal honnête qu'il
  /// faut enrichir le contenu plutôt que de prétendre mesurer.
  double get standardError => _posterior().se;

  /// Vrai quand l'estimation touche le plafond de difficulté du répertoire.
  bool get isBankLimited {
    if (_responses.isEmpty) return false;
    final double ceiling = lexicon.byDifficulty.isEmpty
        ? 100
        : lexicon.difficultyOf(lexicon.byDifficulty.last);
    return estimate + standardError > ceiling;
  }

  /// La logistique du modèle : probabilité de réussir un item de difficulté
  /// [d] quand on a un niveau [theta].
  static double _p(double theta, double d) =>
      1 / (1 + exp((d - theta) / _scale));

  static const double _scale = 10;
  static const double _priorMean = 40;
  static const double _priorSigma = 22;

  ({double theta, double se}) _posterior() {
    if (_responses.isEmpty) {
      return (theta: config.theta0, se: _priorSigma);
    }
    double best = _priorMean;
    double bestLl = double.negativeInfinity;
    for (double t = 0; t <= 100; t += 0.25) {
      double ll = -pow((t - _priorMean) / _priorSigma, 2).toDouble() / 2;
      for (final ({double difficulty, bool correct}) r in _responses) {
        final double p = _p(t, r.difficulty).clamp(1e-6, 1 - 1e-6);
        ll += r.correct ? log(p) : log(1 - p);
      }
      if (ll > bestLl) {
        bestLl = ll;
        best = t;
      }
    }
    // Information de Fisher : Σ p(1-p)/s², plus le poids du prior.
    double info = 1 / (_priorSigma * _priorSigma);
    for (final ({double difficulty, bool correct}) r in _responses) {
      final double p = _p(best, r.difficulty);
      info += p * (1 - p) / (_scale * _scale);
    }
    return (theta: best, se: 1 / sqrt(info));
  }

  bool get isFinished =>
      _asked >= config.maxItems ||
      (_asked >= config.minItems && standardError <= config.seStop);

  /// La question suivante, ou `null` si le test est terminé.
  PlacementQuestion? next() {
    if (isFinished) return null;
    // Les pièges sont placés en milieu de test, une fois que θ s'est
    // dégrossi : un piège posé en question 1 n'apprend rien.
    final bool wantTrap =
        _trapsAsked < config.trapCount && _asked >= 3 && _asked % 4 == 3;
    // L'escalier sert à démarrer vite ; dès qu'il y a assez de réponses, on
    // cible l'estimation, qui est plus juste et évite de continuer à poser
    // des questions hors de portée après un enchaînement chanceux.
    final double target = _responses.length >= 4 ? _posterior().theta : _theta;
    final Lemma? lemma = wantTrap
        ? _pickTrap()
        : lexicon.pickNear(target, _rng, exclude: _seen, includeTraps: false);
    if (lemma == null) {
      _asked = config.maxItems;
      return null;
    }
    final bool isTrap = wantTrap && lemma.isTrap;
    if (isTrap) _trapsAsked++;
    _seen.add(lemma.id);
    final PlacementFormat format = isTrap
        ? PlacementFormat.recognize
        : PlacementFormat.values[_asked % PlacementFormat.values.length];
    _current = PlacementQuestion(
      lemma: lemma,
      format: format,
      isTrap: isTrap,
      index: _asked,
    );
    return _current;
  }

  Lemma? _pickTrap() {
    final List<Lemma> pool = lexicon.traps
        .where((Lemma l) => !_seen.contains(l.id))
        .toList()
      ..sort((Lemma a, Lemma b) => (lexicon.difficultyOf(a) - _theta)
          .abs()
          .compareTo((lexicon.difficultyOf(b) - _theta).abs()));
    if (pool.isEmpty) {
      return lexicon.pickNear(_theta, _rng, exclude: _seen);
    }
    return pool[_rng.nextInt(min(4, pool.length))];
  }

  /// Enregistre la réponse à la question courante.
  void submit({required bool correct}) {
    final PlacementQuestion? q = _current;
    if (q == null) {
      throw StateError('submit() appelé sans question courante');
    }
    _asked++;
    _perSkill[q.format.skill]!.add(correct);
    if (correct) {
      _known.add(q.lemma.id);
    } else {
      _toWork.add(q.lemma.id);
    }
    // Un piège ne bouge pas θ : il mesure un savoir culturel, pas un niveau.
    if (!q.isTrap) {
      _responses.add((
        difficulty: lexicon.difficultyOf(q.lemma),
        correct: correct,
      ));
      _theta = (_theta + (correct ? _step : -_step)).clamp(0, 100);
      _step = max(config.minStep, _step * config.decay);
    }
    _current = null;
  }

  /// Le résultat, calculable à tout moment — y compris si l'utilisateur
  /// abandonne le test en cours de route.
  PlacementResult result({DateTime? now}) {
    final ({double theta, double se}) p = _posterior();
    final (String level, String cefr, int tour) = _levelFor(p.theta);
    return PlacementResult(
      theta: p.theta,
      standardError: p.se,
      isBankLimited: isBankLimited,
      skills: _skillVector(),
      itemsAsked: _asked,
      level: level,
      cefr: cefr,
      startTour: min(tour, config.maxTour),
      knownLemmaIds: List<String>.unmodifiable(_known),
      toWorkLemmaIds: List<String>.unmodifiable(_toWork),
    );
  }

  /// Les lemmes du répertoire sous le niveau estimé : ce sont eux qu'on
  /// crédite au carnet (« 47 mots déjà connus »).
  List<Lemma> creditedLemmas() {
    final double t = estimate;
    return lexicon.lemmas
        .where((Lemma l) => lexicon.difficultyOf(l) < t)
        .toList(growable: false);
  }

  Map<Skill, double> _skillVector() {
    final List<bool> all = <bool>[
      for (final List<bool> v in _perSkill.values) ...v,
    ];
    final double global = _accuracy(all);
    final double t = _posterior().theta;
    return <Skill, double>{
      for (final Skill s in Skill.values)
        s: switch (s) {
          // L'oral n'est pas mesuré par le test au MVP : on l'estime en
          // retrait, et on le dit à l'utilisateur plutôt que de bluffer.
          Skill.parler => (t - 9).clamp(0, 100),
          _ => _perSkill[s]!.isEmpty
              ? t.clamp(0, 100)
              : (t + 14 * (_accuracy(_perSkill[s]!) - global)).clamp(0, 100),
        },
    };
  }

  static double _accuracy(List<bool> v) =>
      v.isEmpty ? 0.5 : v.where((bool b) => b).length / v.length;

  static (String, String, int) _levelFor(double theta) {
    if (theta < 25) return ('Explorateur', 'A1', 1);
    if (theta < 40) return ('Explorateur +', 'A1', 1);
    if (theta < 55) return ('Voyageur', 'A2', 2);
    if (theta < 70) return ('Aventurier', 'B1', 3);
    return ('Aventurier +', 'B1/B2', 3);
  }
}
