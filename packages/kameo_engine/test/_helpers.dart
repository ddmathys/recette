import 'dart:io';

import 'package:kameo_engine/kameo_engine.dart';

/// Charge le vrai fichier semence du dépôt : les tests doivent porter sur le
/// contenu réel, pas sur des données inventées pour l'occasion.
Lexicon loadSeedLexicon() {
  for (final String path in <String>[
    '../../content/es/lexicon-seed.json',
    'content/es/lexicon-seed.json',
    '../../../content/es/lexicon-seed.json',
  ]) {
    final File f = File(path);
    if (f.existsSync()) return Lexicon.fromJsonString(f.readAsStringSync());
  }
  throw StateError('lexicon-seed.json introuvable depuis ${Directory.current}');
}

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
      es: 'palabra$i',
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
