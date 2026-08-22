import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// La voix de Kameo.
///
/// L'accent suit la destination : l'anglais de Londres et celui de New York
/// ne sonnent pas pareil, et c'est précisément ce que le concept promet.
///
/// Toute erreur est avalée : un téléphone sans moteur de synthèse installé
/// doit dégrader le confort, jamais casser l'écran.
class Speech {
  Speech._();

  static final Speech instance = Speech._();
  final FlutterTts _tts = FlutterTts();
  String? _locale;
  bool _broken = false;

  bool get isAvailable => !_broken;

  Future<void> say(String text, {required String locale}) async {
    if (_broken || text.isEmpty) return;
    try {
      if (_locale != locale) {
        await _tts.setLanguage(locale);
        _locale = locale;
      }
      await _tts.setSpeechRate(0.45);
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      _broken = true;
      debugPrint('Synthèse vocale indisponible : $e');
    }
  }

  Future<void> stop() async {
    if (_broken) return;
    try {
      await _tts.stop();
    } catch (_) {
      // Rien à faire : on n'interrompt pas l'utilisateur pour ça.
    }
  }
}
