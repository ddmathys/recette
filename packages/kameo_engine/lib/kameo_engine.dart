/// Moteur d'apprentissage de Kameo.
///
/// Règle d'or (doc 04 §5) : ce package est du Dart pur. Aucun import de
/// Flutter, de Firebase ou du réseau ne doit apparaître ici — c'est ce qui
/// le rend testable, et c'est ce qui permettra d'ajouter une langue sans
/// toucher au code.
library;

export 'src/events.dart';
export 'src/lesson_builder.dart';
export 'src/lexicon.dart';
export 'src/models.dart';
export 'src/placement.dart';
export 'src/srs.dart';
