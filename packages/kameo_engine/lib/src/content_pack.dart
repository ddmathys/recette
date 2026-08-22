import 'dart:convert';

import 'models.dart';

/// L'expression locale d'une ville — le collectionnable qui donne envie de
/// revenir au tour suivant.
class LocalExpression {
  const LocalExpression({
    required this.text,
    required this.translation,
    required this.note,
    this.audioRef,
  });

  factory LocalExpression.fromJson(Map<String, dynamic> json) =>
      LocalExpression(
        text: json['text'] as String,
        translation: json['translation'] as String,
        note: json['note'] as String,
        audioRef: json['audioRef'] as String?,
      );

  final String text;
  final String translation;
  final String note;
  final String? audioRef;
}

/// Une leçon telle qu'elle est écrite dans le contenu.
///
/// Ce n'est pas ce que l'utilisateur joue : le [LessonBuilder] pioche dans
/// ces items pour composer une leçon adaptée à *cet* utilisateur.
class PackLesson {
  const PackLesson({
    required this.id,
    required this.title,
    required this.canDo,
    required this.items,
  });

  factory PackLesson.fromJson(Map<String, dynamic> json) => PackLesson(
    id: json['id'] as String,
    title: json['title'] as String,
    canDo: (json['canDo'] as List<dynamic>)
        .map((dynamic e) => e as String)
        .toList(growable: false),
    items: (json['items'] as List<dynamic>)
        .map((dynamic e) => Item.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );

  final String id;
  final String title;
  final List<String> canDo;
  final List<Item> items;
}

/// Le contenu d'une ville pour un tour donné.
///
/// Chargé depuis un asset local au MVP, depuis Firestore ensuite — même
/// format dans les deux cas (doc 04 §6).
class CityPack {
  const CityPack({
    required this.lang,
    required this.countryId,
    required this.cityId,
    required this.cityName,
    required this.emoji,
    required this.theme,
    required this.tour,
    required this.localExpression,
    required this.lessons,
    required this.stampChallenge,
    required this.humanReviewed,
  });

  factory CityPack.fromJson(Map<String, dynamic> json) {
    final int version = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version != 1) {
      throw FormatException('Version de schéma non gérée : $version');
    }
    final Map<String, dynamic> review =
        (json['review'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return CityPack(
      lang: json['lang'] as String,
      countryId: json['countryId'] as String,
      cityId: json['cityId'] as String,
      cityName: json['cityName'] as String,
      emoji: json['emoji'] as String,
      theme: json['theme'] as String,
      tour: (json['tour'] as num).toInt(),
      localExpression: LocalExpression.fromJson(
        json['localExpression'] as Map<String, dynamic>,
      ),
      lessons: (json['lessons'] as List<dynamic>)
          .map((dynamic e) => PackLesson.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      stampChallenge: PackLesson.fromJson(
        <String, dynamic>{
          'id': '${json['cityId']}.tampon',
          'title': (json['stampChallenge'] as Map<String, dynamic>)['title'],
          'canDo': <String>[],
          'items': (json['stampChallenge'] as Map<String, dynamic>)['items'],
        },
      ),
      humanReviewed: review['humanReviewed'] as bool? ?? false,
    );
  }

  factory CityPack.fromJsonString(String source) =>
      CityPack.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final String lang;
  final String countryId;
  final String cityId;
  final String cityName;
  final String emoji;
  final String theme;
  final int tour;
  final LocalExpression localExpression;
  final List<PackLesson> lessons;
  final PackLesson stampChallenge;

  /// Un pack non relu par un humain ne doit jamais atteindre un utilisateur
  /// (doc 03 §6, étape 2). L'app doit refuser de le servir en production.
  final bool humanReviewed;

  List<Item> get allItems => <Item>[
    for (final PackLesson l in lessons) ...l.items,
    ...stampChallenge.items,
  ];

  /// Tous les lemmes sur lesquels ce pack s'appuie.
  Set<String> get lexemes =>
      allItems.expand((Item i) => i.lexemes).toSet();

  /// Les descripteurs CECR que ce pack prétend couvrir.
  Set<String> get canDo => allItems.expand((Item i) => i.canDo).toSet();
}
