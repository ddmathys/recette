import 'package:flutter/material.dart';
import 'package:kameo_engine/kameo_engine.dart';

import '../../core/kameo_scope.dart';
import '../../core/session.dart';
import '../../core/theme/kameo_colors.dart';
import '../../core/widgets/k_button.dart';
import '../map/map_page.dart';

/// Le résultat du placement.
///
/// Trois principes tenus ici : le niveau est un **vecteur** et non un chiffre,
/// le carnet est **déjà rempli**, et le résultat est une **proposition** —
/// « je préfère commencer au début » est un vrai bouton, pas un lien gris.
class ResultPage extends StatelessWidget {
  const ResultPage({required this.result, required this.engine, super.key});

  final PlacementResult result;
  final PlacementEngine engine;

  static const List<String> _bandLabels = <String>[
    'P1',
    'P2',
    'P3',
    'P4',
    'P5',
    'P6',
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final KameoSession session = KameoScope.of(context);
    final int credited = engine.creditedLemmas().length;
    final int total = engine.lexicon.length;
    final int toWork = result.toWorkLemmaIds.length;

    void go({required bool fromScratch}) {
      if (fromScratch) session.startFromScratch();
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => const MapPage()));
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Center(child: Text('🧭', style: TextStyle(fontSize: 54))),
              const SizedBox(height: KSpace.sm),
              Center(
                child: Text('Voilà où tu en es', style: text.displayLarge),
              ),
              const SizedBox(height: KSpace.lg),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(result.level, style: text.titleMedium),
                        _Pill(label: result.cefr, highlight: true),
                      ],
                    ),
                    const SizedBox(height: KSpace.sm),
                    Text(
                      result.isBankLimited
                          ? 'Tu dépasses ce que ce répertoire sait mesurer. On te '
                                'propose le tour ${result.startTour}, mais '
                                'l\'estimation est incertaine — le contenu avancé arrive.'
                          : 'Tu démarres au tour ${result.startTour}. Estimé en '
                                '${result.itemsAsked} questions, à '
                                '±${result.standardError.round()} points près — '
                                'et tu peux le refaire dans un mois.',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpace.md),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('TON PROFIL PAR COMPÉTENCE', style: text.labelSmall),
                    const SizedBox(height: KSpace.sm),
                    for (final MapEntry<Skill, double> e
                        in result.skills.entries)
                      _SkillBar(
                        label: switch (e.key) {
                          Skill.ecrire => 'Écrire',
                          Skill.parler => 'Parler',
                          Skill.ecouter => 'Écouter',
                        },
                        value: e.value,
                        color: switch (e.key) {
                          Skill.ecrire => KColors.lagon,
                          Skill.parler => KColors.soleil,
                          Skill.ecouter => KColors.ciel,
                        },
                        band: _bandLabels[Band.of(e.value).index],
                      ),
                    const SizedBox(height: KSpace.sm),
                    Text(
                      'Un niveau n\'est pas un chiffre : c\'est un vecteur. On '
                      'saura donc quoi te faire travailler en priorité.',
                      style: text.bodyMedium?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpace.md),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('TON CARNET EST DÉJÀ REMPLI', style: text.labelSmall),
                    const SizedBox(height: KSpace.sm),
                    Text(
                      '$credited mots sur les $total du répertoire sont crédités '
                      'comme connus, et $toWork ${toWork > 1 ? 'sont mis' : 'est mis'} '
                      'de côté à travailler — ce que tu as raté, pièges compris.',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpace.lg),
              KButton.go(
                label: 'Commencer le voyage',
                onPressed: () => go(fromScratch: false),
              ),
              const SizedBox(height: KSpace.sm),
              KButton.ghost(
                label: 'Je préfère commencer au début',
                onPressed: () => go(fromScratch: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(KSpace.md),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(KSpace.radiusCard),
      border: Border.all(color: KColors.trait),
    ),
    child: child,
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: highlight
          ? KColors.lagon.withValues(alpha: 0.22)
          : KColors.creuse,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: KColors.encre),
    ),
  );
}

class _SkillBar extends StatelessWidget {
  const _SkillBar({
    required this.label,
    required this.value,
    required this.color,
    required this.band,
  });

  final String label;
  final double value;
  final Color color;
  final String band;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: KSpace.sm),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              minHeight: 9,
              backgroundColor: KColors.creuse,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: KSpace.sm),
        SizedBox(
          width: 24,
          child: Text(
            band,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 0.4),
          ),
        ),
      ],
    ),
  );
}
