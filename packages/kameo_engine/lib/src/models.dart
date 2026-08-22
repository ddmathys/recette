/// Les objets de base du moteur : lemmes, paliers, items, compétences,
/// échelons de maîtrise et cartes de vocabulaire.
library;

/// Les trois compétences travaillées (doc 02 §3.2). Un niveau est un vecteur
/// sur ces trois axes, jamais un chiffre unique.
enum Skill { ecrire, parler, ecouter }

/// Les six paliers de difficulté du répertoire (doc 03 §2.1).
enum Band {
  p1(0, 20),
  p2(20, 35),
  p3(35, 50),
  p4(50, 65),
  p5(65, 80),
  p6(80, 101);

  const Band(this.min, this.max);
  final double min;
  final double max;

  static Band of(double difficulty) {
    for (final b in Band.values) {
      if (difficulty >= b.min && difficulty < b.max) return b;
    }
    return difficulty < 0 ? Band.p1 : Band.p6;
  }
}

/// Les quatre échelons de maîtrise (doc 02 §4).
///
/// Monter est difficile, redescendre est rare et lent : c'est la traduction
/// mémorielle de « rien de gagné ne se reprend ».
enum Rung {
  /// Reconnaître : comprendre en contexte.
  r1,

  /// Rappeler : retrouver la forme avec appui.
  r2,

  /// Produire : écrire sans appui.
  r3,

  /// Dire : produire à l'oral.
  r4;

  Rung get next => this == Rung.r4 ? Rung.r4 : Rung.values[index + 1];
  Rung get previous => this == Rung.r1 ? Rung.r1 : Rung.values[index - 1];

  /// Modulateur d'intervalle : plus l'échelon est exigeant, plus on révise
  /// souvent (doc 02 §5.1).
  double get intervalModifier => const [1.0, 0.9, 0.8, 0.7][index];
}

/// Poids de la formule de difficulté (doc 03 §2).
///
/// Ils vivent ici, en un seul endroit : changer un poids re-note tout le
/// répertoire sans réécrire une seule entrée.
class DifficultyWeights {
  const DifficultyWeights({
    this.frequency = 0.45,
    this.cefr = 0.20,
    this.opacity = 0.15,
    this.morphology = 0.10,
    this.trap = 0.10,
  });

  final double frequency;
  final double cefr;
  final double opacity;
  final double morphology;
  final double trap;

  static const DifficultyWeights standard = DifficultyWeights();
}

/// Une entrée du répertoire.
class Lemma {
  const Lemma({
    required this.id,
    required this.term,
    required this.fr,
    required this.cefr,
    required this.f,
    required this.o,
    required this.m,
    required this.t,
    this.pos,
    this.themes = const <String>[],
    this.city,
    this.variant,
    this.note,
  });

  factory Lemma.fromJson(Map<String, dynamic> json) => Lemma(
        id: json['id'] as String,
        term: json['term'] as String,
        fr: json['fr'] as String,
        cefr: json['cefr'] as String,
        f: (json['f'] as num).toDouble(),
        o: (json['o'] as num).toDouble(),
        m: (json['m'] as num).toDouble(),
        t: (json['t'] as num).toDouble(),
        pos: json['pos'] as String?,
        themes: (json['themes'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => e as String)
            .toList(growable: false),
        city: json['city'] as String?,
        variant: json['variant'] as String?,
        note: json['note'] as String?,
      );

  final String id;
  final String term;
  final String fr;
  final String cefr;

  /// Difficulté de fréquence (0 = très fréquent).
  final double f;

  /// Opacité orthographique vis-à-vis du français.
  final double o;

  /// Irrégularité morphologique.
  final double m;

  /// Piège : faux-ami, polysémie trompeuse, construction inversée.
  final double t;

  final String? pos;
  final List<String> themes;
  final String? city;

  /// `uk` ou `us` quand le mot ne s'emploie que d'un côté de l'Atlantique.
  /// `null` = valable partout.
  final String? variant;

  final String? note;

  /// Un lemme est un piège à partir de 70 : c'est le seuil au-delà duquel il
  /// mérite d'être enseigné explicitement comme tel.
  bool get isTrap => t >= 70;

  static const Map<String, double> cefrScore = <String, double>{
    'A1': 0,
    'A2': 30,
    'B1': 60,
    'B2': 80,
    'C1': 100,
  };

  double difficulty([DifficultyWeights w = DifficultyWeights.standard]) =>
      w.frequency * f +
      w.cefr * (cefrScore[cefr] ?? 50) +
      w.opacity * o +
      w.morphology * m +
      w.trap * t;

  @override
  String toString() => 'Lemma($id, $term)';
}

/// La nature d'un exercice.
enum ItemKind { translate, speak, listen, gap, dialogue, mcq }

/// Un item de contenu (doc 02 §8).
class Item {
  const Item({
    required this.id,
    required this.kind,
    required this.skill,
    required this.rung,
    required this.cefr,
    required this.prompt,
    required this.answer,
    this.canDo = const <String>[],
    this.city,
    this.tour = 1,
    this.theme,
    this.lexemes = const <String>[],
    this.alternates = const <String>[],
    this.wordBank = const <String>[],
    this.options = const <String>[],
    this.difficulty = 50,
    this.audioText,
    this.audioRef,
    this.note,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        kind: ItemKind.values.byName(json['kind'] as String),
        skill: Skill.values.byName(json['skill'] as String),
        rung: Rung.values.byName((json['rung'] as String).toLowerCase()),
        cefr: json['cefr'] as String,
        prompt: json['prompt'] as String,
        answer: json['answer'] as String,
        canDo: _strings(json['canDo']),
        city: json['city'] as String?,
        tour: (json['tour'] as num?)?.toInt() ?? 1,
        theme: json['theme'] as String?,
        lexemes: _strings(json['lexemes']),
        alternates: _strings(json['alternates']),
        wordBank: _strings(json['wordBank']),
        options: _strings(json['options']),
        difficulty: (json['difficulty'] as num?)?.toDouble() ?? 50,
        audioText: json['audioText'] as String?,
        audioRef: json['audioRef'] as String?,
        note: json['note'] as String?,
      );

  static List<String> _strings(Object? v) =>
      (v as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e as String)
          .toList(growable: false);

  final String id;
  final ItemKind kind;
  final Skill skill;
  final Rung rung;
  final String cefr;
  final String prompt;
  final String answer;
  final List<String> canDo;
  final String? city;
  final int tour;
  final String? theme;
  final List<String> lexemes;
  final List<String> alternates;
  final List<String> wordBank;

  /// Les propositions d'un QCM ou d'un exercice d'écoute.
  final List<String> options;

  final double difficulty;

  /// Le texte espagnol à faire dire par la synthèse vocale. Séparé de
  /// [prompt] (la consigne) et de [answer] (ce qu'on attend).
  final String? audioText;

  final String? audioRef;

  /// L'explication montrée après une erreur. Elle doit apprendre quelque
  /// chose, pas répéter la correction.
  final String? note;

  /// Ce qu'il faut prononcer : le texte d'audio s'il existe, sinon la réponse
  /// attendue (cas des exercices de répétition).
  String? get spokenText => audioText ?? (kind == ItemKind.speak ? answer : null);

  /// Comparaison indulgente : on ignore la casse, les accents, la ponctuation
  /// et les espaces multiples. Un apprenant ne doit pas perdre un cœur sur un
  /// accent manquant (doc 02 §9).
  bool accepts(String given) {
    final String g = normalize(given);
    if (g == normalize(answer)) return true;
    return alternates.any((String a) => normalize(a) == g);
  }

  static String normalize(String s) {
    const Map<String, String> folds = <String, String>{
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
    };
    final StringBuffer out = StringBuffer();
    for (final String ch in s.toLowerCase().split('')) {
      final String folded = folds[ch] ?? ch;
      if (RegExp(r'[a-z0-9 ]').hasMatch(folded)) out.write(folded);
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  String toString() => 'Item($id, ${skill.name})';
}

/// L'état d'un mot dans le carnet d'un utilisateur.
class VocabCard {
  const VocabCard({
    required this.lemmaId,
    required this.dueAt,
    this.rung = Rung.r1,
    this.ease = 2.3,
    this.intervalDays = 0,
    this.successesAtRung = 0,
    this.consecutiveLapses = 0,
    this.lapses = 0,
    this.lastSuccessAt,
    this.masteredCount = 0,
    this.retired = false,
    this.city,
    this.lessonId,
    this.source = 'lesson',
  });

  /// Un mot que l'utilisateur choisit lui-même démarre à R2 : s'il l'a
  /// sélectionné, c'est qu'il l'a déjà rencontré et compris (doc 02 §5.2).
  factory VocabCard.saved({
    required String lemmaId,
    required DateTime now,
    String? city,
    String? lessonId,
  }) =>
      VocabCard(
        lemmaId: lemmaId,
        rung: Rung.r2,
        dueAt: now.add(const Duration(days: 1)),
        city: city,
        lessonId: lessonId,
        source: 'user',
      );

  /// Un mot réussi au test de placement est crédité, pas à réapprendre.
  factory VocabCard.fromPlacement({
    required String lemmaId,
    required DateTime now,
    required bool known,
  }) =>
      VocabCard(
        lemmaId: lemmaId,
        rung: Rung.r1,
        successesAtRung: known ? 1 : 0,
        intervalDays: known ? 7 : 1,
        dueAt: now.add(Duration(days: known ? 7 : 1)),
        lastSuccessAt: known ? now : null,
        source: 'placement',
      );

  final String lemmaId;
  final Rung rung;
  final double ease;
  final double intervalDays;
  final DateTime dueAt;
  final int successesAtRung;
  final int consecutiveLapses;
  final int lapses;
  final DateTime? lastSuccessAt;
  final int masteredCount;
  final bool retired;
  final String? city;
  final String? lessonId;
  final String source;

  bool isDue(DateTime now) => !now.isBefore(dueAt);

  VocabCard copyWith({
    Rung? rung,
    double? ease,
    double? intervalDays,
    DateTime? dueAt,
    int? successesAtRung,
    int? consecutiveLapses,
    int? lapses,
    DateTime? lastSuccessAt,
    int? masteredCount,
    bool? retired,
  }) =>
      VocabCard(
        lemmaId: lemmaId,
        rung: rung ?? this.rung,
        ease: ease ?? this.ease,
        intervalDays: intervalDays ?? this.intervalDays,
        dueAt: dueAt ?? this.dueAt,
        successesAtRung: successesAtRung ?? this.successesAtRung,
        consecutiveLapses: consecutiveLapses ?? this.consecutiveLapses,
        lapses: lapses ?? this.lapses,
        lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
        masteredCount: masteredCount ?? this.masteredCount,
        retired: retired ?? this.retired,
        city: city,
        lessonId: lessonId,
        source: source,
      );

  @override
  String toString() => 'VocabCard($lemmaId, ${rung.name}, due $dueAt)';
}
