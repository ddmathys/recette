import 'package:flutter/material.dart';
import 'package:kameo_engine/kameo_engine.dart';

import '../../core/kameo_scope.dart';
import '../../core/session.dart';
import '../../core/speech.dart';
import '../../core/theme/kameo_colors.dart';
import '../../core/widgets/k_button.dart';

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

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final KameoSession session = KameoScope.of(context);
    final String locale = session.country?.ttsLocale ?? 'es-ES';

    return SafeArea(
      child: Padding(
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(KSpace.md),
              decoration: BoxDecoration(
                color: KColors.creuse,
                borderRadius: BorderRadius.circular(KSpace.radiusCard),
              ),
              child: Row(
                children: <Widget>[
                  const Text('🚧', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: KSpace.sm),
                  Expanded(
                    child: Text(
                      'Les leçons de cette ville arrivent à l\'étape suivante : '
                      'le moteur d\'exercices (écrire, parler, écouter).',
                      style: text.bodyMedium?.copyWith(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpace.md),
            KButton.ghost(
              label: 'Retour à la carte',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
