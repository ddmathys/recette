import 'package:flutter/foundation.dart';
import 'package:kameo_engine/kameo_engine.dart';

/// L'état de la session en cours.
///
/// Volontairement minimal : au MVP il vit en mémoire. Il sera alimenté par le
/// journal d'événements (doc 04 §2) à l'étape 10 — d'où les méthodes qui
/// ressemblent déjà à des événements plutôt qu'à des affectations.
class KameoSession extends ChangeNotifier {
  String? lang;
  Country? country;
  Lexicon? lexicon;
  PlacementResult? placement;

  int currentTour = 1;
  int xp = 0;
  int gems = 0;
  final Set<String> stamps = <String>{};

  /// Le vocabulaire que chaque ville se charge d'enseigner à ce tour.
  Map<String, CityObjective> objectives = <String, CityObjective>{};

  /// Ce que l'utilisateur a déjà réussi, mot par mot.
  final Map<String, DrillRecord> drills = <String, DrillRecord>{};

  static const CityObjectiveBuilder _objectives = CityObjectiveBuilder();

  /// Le répertoire filtré pour la destination : à New York, on n'apprend pas
  /// « pavement ».
  Lexicon get travelLexicon {
    final Lexicon l = lexicon!;
    final String? variant = country?.variant;
    if (variant == null) return l;
    return Lexicon(l.lang, l.forVariant(variant), weights: l.weights);
  }

  void chooseLanguage(String code) {
    lang = code;
    country = null;
    placement = null;
    notifyListeners();
  }

  void chooseDestination(Country c, Lexicon lex) {
    country = c;
    lexicon = lex;
    _rebuildObjectives();
    notifyListeners();
  }

  void _rebuildObjectives() {
    final Country? c = country;
    if (c == null || lexicon == null) return;
    objectives = _objectives.buildAll(
      lexicon: travelLexicon,
      country: c,
      tour: currentTour,
    );
  }

  CityObjective? objectiveFor(String cityId) => objectives[cityId];

  /// Enregistre le résultat d'un exercice.
  void recordDrill(String lemmaId, DrillKind kind, {required bool success}) {
    drills[lemmaId] = (drills[lemmaId] ?? const DrillRecord()).withResult(
      kind,
      success: success,
    );
    xp += success ? 2 : 0;
    notifyListeners();
  }

  /// Le tampon d'une ville. Il ne se reprend jamais (doc 02 §2).
  void awardStamp(String cityId) {
    if (stamps.add(cityId)) {
      xp += 40;
      gems += 10;
      notifyListeners();
    }
  }

  int get wordsLearned =>
      drills.values.where((DrillRecord r) => r.isAssimilated).length;

  void completePlacement(PlacementResult result) {
    placement = result;
    currentTour = result.startTour;
    _rebuildObjectives();
    notifyListeners();
  }

  void startFromScratch() {
    placement = null;
    currentTour = 1;
    _rebuildObjectives();
    notifyListeners();
  }

  /// La ville où l'utilisateur en est : la première non tamponnée.
  City? get currentCity {
    final Country? c = country;
    if (c == null) return null;
    for (final City city in c.cities) {
      if (!stamps.contains(city.id)) return city;
    }
    return c.cities.last;
  }

  bool isDone(City city) => stamps.contains(city.id);

  bool isLocked(City city) {
    final City? cur = currentCity;
    return cur != null && city.order > cur.order;
  }
}
