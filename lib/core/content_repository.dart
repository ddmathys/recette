import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:kameo_engine/kameo_engine.dart';

/// Accès au contenu.
///
/// Au MVP le pack est un asset local ; en production il viendra de Firestore
/// via un pointeur Remote Config. **Le format est le même dans les deux
/// cas** : seule la source change, jamais le parsing (doc 04 §3).
class ContentRepository {
  ContentRepository({this.assetPrefix = 'content'});

  final String assetPrefix;
  final Map<String, Lexicon> _cache = <String, Lexicon>{};
  final Map<String, CityPack> _packs = <String, CityPack>{};

  /// La version de contenu active. En production, ce pointeur vient de
  /// Remote Config : corriger une faute d'espagnol devient un changement de
  /// pointeur, pas une soumission à l'App Store (doc 04 §3).
  static const String activeVersion = '2026-08-22_v1';

  /// Charge le pack d'une ville pour un tour donné.
  ///
  /// Un pack non relu par un humain n'est jamais servi : mieux vaut une
  /// ville verrouillée qu'une faute d'espagnol devant un utilisateur.
  Future<CityPack?> pack({
    required String lang,
    required String cityId,
    required int tour,
    bool allowUnreviewed = false,
  }) async {
    final String key = '$lang/$cityId/t$tour';
    final CityPack? cached = _packs[key];
    if (cached != null) return cached;
    final String raw = await rootBundle.loadString(
      '$assetPrefix/$lang/packs/$activeVersion/$cityId.t$tour.json',
    );
    final CityPack loaded = CityPack.fromJsonString(raw);
    if (!loaded.humanReviewed && !allowUnreviewed) return null;
    _packs[key] = loaded;
    return loaded;
  }

  Future<Lexicon> lexicon(String lang) async {
    final Lexicon? cached = _cache[lang];
    if (cached != null) return cached;
    final String raw = await rootBundle.loadString(
      '$assetPrefix/$lang/lexicon-seed.json',
    );
    final Lexicon lex = Lexicon.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _cache[lang] = lex;
    return lex;
  }
}
