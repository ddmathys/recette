import 'package:flutter/material.dart';
import 'package:kameo_engine/kameo_engine.dart';

import '../../core/content_repository.dart';
import '../../core/theme/kameo_colors.dart';
import '../../core/widgets/k_button.dart';

/// Écran d'amorçage de l'étape 2 du plan.
///
/// Il ne fait rien de plus que prouver que la chaîne complète tient debout :
/// thème Kameo, chargement du contenu depuis les assets, et moteur
/// d'apprentissage câblé. Il sera remplacé par la carte à l'étape 6.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<Lexicon> _lexicon = ContentRepository().lexicon('es');

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KSpace.lg),
          child: FutureBuilder<Lexicon>(
            future: _lexicon,
            builder: (BuildContext context, AsyncSnapshot<Lexicon> snap) {
              if (snap.hasError) {
                return _Message(
                  title: 'Contenu introuvable',
                  body:
                      'Le pack espagnol n\'a pas pu être chargé. '
                      'Vérifie que content/es est bien déclaré dans pubspec.yaml.',
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final Lexicon lex = snap.data!;
              final Map<Band, int> d = lex.distribution;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('🦎', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: KSpace.sm),
                  Text('Kameo', style: text.displayLarge),
                  Text(
                    'Apprends une langue en traversant le pays qui la parle.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: KSpace.lg),
                  Text('RÉPERTOIRE CHARGÉ', style: text.labelSmall),
                  const SizedBox(height: KSpace.sm),
                  Text(
                    '${lex.length} lemmes espagnols',
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: KSpace.sm),
                  for (final Band b in Band.values)
                    if ((d[b] ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: KSpace.xs),
                        child: Text(
                          '${b.name.toUpperCase()} · ${d[b]} mots',
                          style: text.bodyMedium,
                        ),
                      ),
                  const Spacer(),
                  KButton(label: 'Commencer le voyage', onPressed: () {}),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: text.headlineMedium),
          const SizedBox(height: KSpace.sm),
          Text(body, style: text.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
