import 'dart:convert';

/// Un point de la carte, dans un repère 0–100 indépendant de l'écran.
///
/// Les cartes sont **illustrées, pas géographiques** (spec §10) : pas de
/// licence à payer, un style chaleureux, et une projection assez fidèle pour
/// que les villes tombent au bon endroit.
class MapPoint {
  const MapPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  String toString() => '($x, $y)';
}

/// L'expression signature d'une ville — le collectionnable du voyage.
class CityExpression {
  const CityExpression({
    required this.text,
    required this.translation,
    required this.note,
  });

  factory CityExpression.fromJson(Map<String, dynamic> json) => CityExpression(
    text: json['text'] as String,
    translation: json['translation'] as String,
    note: json['note'] as String,
  );

  final String text;
  final String translation;
  final String note;
}

class City {
  const City({
    required this.id,
    required this.name,
    required this.emoji,
    required this.position,
    required this.order,
    required this.theme,
    required this.expression,
    this.labelOffset = -4.6,
  });

  factory City.fromJson(Map<String, dynamic> json) => City(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
    position: MapPoint(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    ),
    order: (json['order'] as num).toInt(),
    theme: json['theme'] as String,
    expression: CityExpression.fromJson(
      json['expression'] as Map<String, dynamic>,
    ),
    labelOffset: (json['labelOffset'] as num?)?.toDouble() ?? -4.6,
  );

  final String id;
  final String name;
  final String emoji;
  final MapPoint position;
  final int order;
  final String theme;
  final CityExpression expression;

  /// Décalage vertical de l'étiquette, pour éviter qu'elle chevauche
  /// l'itinéraire ou une ville voisine.
  final double labelOffset;
}

/// Une destination : un pays, sa carte, ses villes, son accent.
///
/// C'est la destination qui décide de la voix : l'anglais de Londres et
/// celui de New York ne sonnent pas pareil, et c'est tout l'intérêt.
class Country {
  const Country({
    required this.id,
    required this.lang,
    required this.name,
    required this.shortName,
    required this.flag,
    required this.accent,
    required this.ttsLocale,
    required this.note,
    required this.outline,
    required this.cities,
    this.variant,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    final int version = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version != 1) {
      throw FormatException('Version de schéma de pays non gérée : $version');
    }
    return Country(
      id: json['id'] as String,
      lang: json['lang'] as String,
      name: json['name'] as String,
      shortName: json['shortName'] as String,
      flag: json['flag'] as String,
      variant: json['variant'] as String?,
      accent: json['accent'] as String,
      ttsLocale: json['ttsLocale'] as String,
      note: json['note'] as String,
      outline: (json['outline'] as List<dynamic>)
          .map((dynamic e) {
            final List<dynamic> p = e as List<dynamic>;
            return MapPoint(
              (p[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            );
          })
          .toList(growable: false),
      cities:
          (json['cities'] as List<dynamic>)
              .map((dynamic e) => City.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((City a, City b) => a.order.compareTo(b.order)),
    );
  }

  factory Country.fromJsonString(String source) =>
      Country.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final String id;
  final String lang;
  final String name;
  final String shortName;
  final String flag;

  /// `uk`, `us`, ou `null` quand la langue n'a pas de variante régionale
  /// marquée. C'est ce qui filtre le vocabulaire : on n'apprend pas
  /// « pavement » en préparant un voyage à New York.
  final String? variant;

  final String accent;
  final String ttsLocale;
  final String note;
  final List<MapPoint> outline;
  final List<City> cities;

  /// L'identifiant du voyage : un couple langue × pays.
  String get journeyId => '${lang}_$id';

  City? cityById(String id) {
    for (final City c in cities) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Vrai si la ville tombe bien à l'intérieur du contour dessiné.
  ///
  /// Un point hors carte est une faute de contenu visible à l'œil nu : autant
  /// que le moteur sache la détecter.
  bool contains(MapPoint p) {
    bool inside = false;
    for (int i = 0, j = outline.length - 1; i < outline.length; j = i++) {
      final MapPoint a = outline[i];
      final MapPoint b = outline[j];
      if ((a.y > p.y) != (b.y > p.y) &&
          p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
    return inside;
  }
}
