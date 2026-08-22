import 'dart:io';

import 'package:kameo_engine/kameo_engine.dart';

/// Charge le vrai fichier semence du dépôt : les tests doivent porter sur le
/// contenu réel, pas sur des données inventées pour l'occasion.
Lexicon loadSeedLexicon() =>
    Lexicon.fromJsonString(loadContentFile('es/lexicon-seed.json'));

Item item({
  required String id,
  Skill skill = Skill.ecrire,
  List<String> lexemes = const <String>[],
  String? city,
  ItemKind kind = ItemKind.translate,
}) =>
    Item(
      id: id,
      kind: kind,
      skill: skill,
      rung: Rung.r2,
      cefr: 'A1',
      prompt: 'prompt $id',
      answer: 'answer $id',
      lexemes: lexemes,
      city: city,
    );

/// Un répertoire synthétique de difficultés régulièrement étalées.
///
/// Il sert à séparer deux questions : « le moteur estime-t-il bien ? » et
/// « le répertoire couvre-t-il assez de niveaux ? ». La semence espagnole
/// répond oui à la première, pas encore à la seconde.
Lexicon syntheticLexicon({int count = 600, double maxDifficulty = 90}) {
  final List<Lemma> lemmas = <Lemma>[];
  for (int i = 0; i < count; i++) {
    final double target = maxDifficulty * i / (count - 1);
    final String cefr = target <= 60 ? 'A1' : 'B1';
    final double offset = target <= 60 ? 0 : 12;
    final double v = ((target - offset) / 0.70).clamp(0, 100);
    final bool trap = i % 12 == 0;
    lemmas.add(Lemma(
      id: 'syn.$i',
      term: 'palabra$i',
      fr: 'mot$i',
      cefr: cefr,
      f: v,
      o: v,
      m: v,
      t: trap ? 70 : 0,
      city: <String>['valencia', 'madrid', 'bilbao'][i % 3],
    ));
  }
  return Lexicon('syn', lemmas);
}

/// Lit un fichier de `/content` depuis les tests, quel que soit le dossier
/// depuis lequel `dart test` a été lancé.
String loadContentFile(String relative) {
  for (final String prefix in <String>['../../content', 'content', '../../../content']) {
    final File f = File('$prefix/$relative');
    if (f.existsSync()) return f.readAsStringSync();
  }
  throw StateError('$relative introuvable depuis ${Directory.current}');
}
