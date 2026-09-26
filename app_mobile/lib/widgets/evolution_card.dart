import 'package:flutter/material.dart';

import '../habits.dart';
import '../models.dart';
import '../theme.dart';

/// Évolution des calories jour par jour vs objectif + moyennes (jours
/// renseignés uniquement). Mirrors Evolution.tsx.
class EvolutionCard extends StatefulWidget {
  final List<MealLog> logs;
  final num goal;
  const EvolutionCard({super.key, required this.logs, required this.goal});

  @override
  State<EvolutionCard> createState() => _EvolutionCardState();
}

class _EvolutionCardState extends State<EvolutionCard> {
  int _range = 14;

  Color _colorFor(num kcal) {
    if (kcal > widget.goal * 1.1) return AppColors.gold;
    if (kcal >= widget.goal * 0.9) return AppColors.herb;
    return AppColors.accent2;
  }

  @override
  Widget build(BuildContext context) {
    final totals = dailyTotals(widget.logs);
    final now = DateTime.now();
    final days = [for (var i = _range - 1; i >= 0; i--) now.subtract(Duration(days: i))];
    final values = [for (final d in days) totals[dayKey(d)]];
    final filled = values.whereType<DayTotal>().toList();
    final n = filled.isEmpty ? 1 : filled.length;
    num avg(num Function(DayTotal) f) => (filled.fold<num>(0, (a, t) => a + f(t)) / n).round();
    final onTarget = filled.where((t) => t.kcal >= widget.goal * 0.9 && t.kcal <= widget.goal * 1.1).length;
    final maxV = [widget.goal * 1.3, ...filled.map((t) => t.kcal)].reduce((a, b) => a > b ? a : b);
    const chartH = 120.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('📈 Mon évolution', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 j')),
                  ButtonSegment(value: 14, label: Text('14 j')),
                  ButtonSegment(value: 30, label: Text('30 j')),
                ],
                selected: {_range},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('Moyenne / jour', '${avg((t) => t.kcal)}', 'kcal'),
              const SizedBox(width: 8),
              _stat('Jours notés', '${filled.length}', '/ $_range'),
              const SizedBox(width: 8),
              _stat("Dans l'objectif", '$onTarget', 'jours'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: chartH,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final t in values)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: _range > 14 ? 1 : 3),
                          child: t == null || t.kcal <= 0
                              ? Container(height: 2, color: AppColors.line)
                              : Container(
                                  height: (t.kcal / maxV * chartH).clamp(3, chartH).toDouble(),
                                  decoration: BoxDecoration(
                                    color: _colorFor(t.kcal).withValues(alpha: t.estimated > 0 ? 0.55 : 1),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: (widget.goal / maxV * chartH).toDouble(),
                  child: Container(height: 1, color: AppColors.inkSoft.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '— objectif ${widget.goal.round()} kcal · barres pâles = journée estimée',
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft),
          ),
          if (filled.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'En moyenne : ${avg((t) => t.proteinG)} g de protéines, ${avg((t) => t.carbsG)} g de glucides, ${avg((t) => t.fatG)} g de lipides par jour.',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String unit) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
