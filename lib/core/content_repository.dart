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
