import 'package:flutter/material.dart';

import '../meal_types.dart';
import '../models.dart';
import '../services/meal_log_service.dart';
import '../theme.dart';
import 'log_meal_screen.dart';

String _localDayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

String _formatTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// "Aujourd'hui" — journal des repas mangés, navigation jour précédent/
/// suivant, total kcal/macros du jour. Mirrors NutritionPanel.tsx.
class NutritionScreen extends StatefulWidget {
  final String householdId;
  final String ownerUid;
  final String ownerName;
  final List<Recipe> recipes;

  const NutritionScreen({
    super.key,
    required this.householdId,
    required this.ownerUid,
    required this.ownerName,
    required this.recipes,
  });

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final _service = MealLogService();
  int _dayOffset = 0;
  String? _deletingId;

  Future<void> _delete(MealLog l) async {
    setState(() => _deletingId = l.id);
    try {
      await _service.deleteMealLog(l.id, l.photoUrl);
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().add(Duration(days: _dayOffset));
    final dayKey = _localDayKey(day);
    final dayLabel = _dayOffset == 0
        ? "Aujourd'hui"
        : _dayOffset == -1
            ? 'Hier'
            : '${day.day}/${day.month}/${day.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Journal alimentaire')),
      body: SafeArea(
        child: StreamBuilder<List<MealLog>>(
          stream: _service.streamMealLogs(widget.householdId),
          builder: (context, snapshot) {
            final logs = snapshot.data ?? [];
            final dayLogs = logs.where((l) {
              final d = DateTime.tryParse(l.eatenAt)?.toLocal();
              return d != null && _localDayKey(d) == dayKey;
            }).toList()
              ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));

            num totalKcal = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
            for (final l in dayLogs) {
              totalKcal += l.kcal;
              totalProtein += l.proteinG;
              totalCarbs += l.carbsG;
              totalFat += l.fatG;
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _dayOffset -= 1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    IconButton(
                      onPressed: _dayOffset == 0 ? null : () => setState(() => _dayOffset += 1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Total(value: totalKcal, label: 'Kcal'),
                      _Total(value: totalProtein, label: 'Protéines (g)'),
                      _Total(value: totalCarbs, label: 'Glucides (g)'),
                      _Total(value: totalFat, label: 'Lipides (g)'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LogMealScreen(
                        recipes: widget.recipes,
                        ownerUid: widget.ownerUid,
                        ownerName: widget.ownerName,
                        householdId: widget.householdId,
                      ),
                    ));
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Repas mangé'),
                ),
                const SizedBox(height: 16),
                if (dayLogs.isEmpty)
                  const Text('Aucun repas enregistré ce jour-là.', style: TextStyle(color: AppColors.inkSoft, fontSize: 13))
                else
                  for (final l in dayLogs)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5), overflow: TextOverflow.ellipsis),
                                Text(
                                  '${mealTypeLabel(l.mealType)} · ${_formatTime(l.eatenAt)} · ${l.portionGrams} g',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          Text('${l.kcal} kcal', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                          IconButton(
                            onPressed: _deletingId == l.id ? null : () => _delete(l),
                            icon: const Icon(Icons.close, size: 18),
                            color: AppColors.inkSoft,
                          ),
                        ],
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final num value;
  final String label;
  const _Total({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${value.round()}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.inkSoft, letterSpacing: .3)),
      ],
    );
  }
}
