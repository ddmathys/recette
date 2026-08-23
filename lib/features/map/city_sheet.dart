import 'package:flutter/material.dart';
import 'package:kameo_engine/kameo_engine.dart';

import '../../core/kameo_scope.dart';
import '../../core/session.dart';
import '../../core/speech.dart';
import '../../core/theme/kameo_colors.dart';
import '../../core/widgets/k_button.dart';
import '../drill/drill_page.dart';

/// La fiche ville : sa spécificité, son expression locale, ses leçons.
///
/// L'expression locale est le collectionnable qui donne envie de refaire le
/// tour au niveau suivant.
class CitySheet extends StatelessWidget {
  const CitySheet({required this.city, super.key});

  final City city;

  static Future<void> show(BuildContext context, City city) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: KColors.creme,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => CitySheet(city: city),
      );

  static Future<void> _learn(BuildContext context, City city) async {
    Navigator.of(context).pop();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DrillPage(city: city)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final KameoSession session = KameoScope.of(context);
    final String locale = session.country?.ttsLocale ?? 'es-ES';
    final CityObjective? objective = session.objectiveFor(city.id);
    final int acquired = objective?.acquiredIn(session.drills) ?? 0;

    return SafeArea(
      child: ConstrainedBox(
        // La fiche s'est allongée avec l'objectif de vocabulaire : elle défile
        // plutôt que de déborder, et laisse voir la carte derrière.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: KColors.traitFort,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: KSpace.md),
              Row(
                children: <Widget>[
                  Expanded(child: Text(city.name, style: text.displayLarge)),
                  Text(city.emoji, style: const TextStyle(fontSize: 40)),
                ],
              ),
              const SizedBox(height: KSpace.xs),
              Text(
                city.theme,
                style: text.bodyMedium?.copyWith(color: KColors.encreDouce),
              ),
              const SizedBox(height: KSpace.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(KSpace.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(KSpace.radiusCard),
                  border: Border.all(color: KColors.trait),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('EXPRESSION LOCALE', style: text.labelSmall),
                    const SizedBox(height: KSpace.xs),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                city.expression.text,
                                style: text.headlineMedium?.copyWith(
                                  fontSize: 21,
                                ),
                              ),
                              Text(
                                city.expression.translation,
                                style: text.bodyMedium?.copyWith(
                                  color: KColors.encreDouce,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => Speech.instance.say(
                            city.expression.text,
                            locale: locale,
                          ),
                          icon: const Icon(Icons.volume_up_rounded),
                          tooltip: 'Écouter',
                        ),
                      ],
                    ),
                    const SizedBox(height: KSpace.sm),
                    Text(
                      city.expression.note,
                      style: text.bodyMedium?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpace.md),
              if (objective != null) ...<Widget>[
                _Objective(objective: objective, acquired: acquired),
                const SizedBox(height: KSpace.md),
                if (session.isDone(city))
                  KButton.ghost(
                    label: '✓  Ville tamponnée · réviser',
                    onPressed: () => _learn(context, city),
                  )
                else
                  KButton(
                    label: acquired == 0
                        ? 'Apprendre le vocabulaire'
                        : acquired >= objective.required
                            ? 'Réviser'
                            : 'Continuer · ${objective.required - acquired} à assimiler',
                    onPressed: () => _learn(context, city),
                  ),
              ],
              const SizedBox(height: KSpace.sm),
              KButton.ghost(
                label: 'Retour à la carte',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le vocabulaire que la ville enseigne, et où en est l'utilisateur.
///
/// C'est le critère du tampon : on ne valide pas une ville en enchaînant des
/// leçons, on la valide en assimilant son vocabulaire.
class _Objective extends StatelessWidget {
  const _Objective({required this.objective, required this.acquired});

  final CityObjective objective;
  final int acquired;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final KameoSession session = KameoScope.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KSpace.radiusCard),
        border: Border.all(color: KColors.trait),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'VOCABULAIRE DE LA VILLE',
                  style: text.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: KSpace.sm),
              Text('$acquired/${objective.total}', style: text.labelSmall),
            ],
          ),
          const SizedBox(height: KSpace.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: objective.total == 0 ? 0 : acquired / objective.total,
              minHeight: 11,
              backgroundColor: KColors.creuse,
              color: acquired >= objective.required
                  ? KColors.soleil
                  : KColors.lagon,
            ),
          ),
          const SizedBox(height: KSpace.sm),
          Text(
            '${objective.required} mots assimilés suffisent pour le tampon. '
            'Un mot compte quand tu le réussis sur deux types d\'exercice : '
            'le reconnaître, et le retrouver.',
            style: text.bodyMedium?.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: KSpace.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final Lemma l in objective.words)
                _Word(
                  lemma: l,
                  record: session.drills[l.id] ?? const DrillRecord(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.lemma, required this.record});

  final Lemma lemma;
  final DrillRecord record;

  @override
  Widget build(BuildContext context) {
    final bool done = record.isAssimilated;
    final bool started = record.passedKinds.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: done
            ? KColors.lagon.withValues(alpha: 0.16)
            : started
                ? KColors.soleil.withValues(alpha: 0.18)
                : KColors.creuse,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: done ? KColors.lagon : KColors.trait,
          width: done ? 1.4 : 1,
        ),
      ),
      child: Text(
        done ? '${lemma.term} ✓' : lemma.term,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: done ? KColors.encre : KColors.encreDouce,
            ),
      ),
    );
  }
}
