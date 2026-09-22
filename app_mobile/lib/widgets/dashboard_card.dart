import 'package:flutter/material.dart';

import '../meal_types.dart';
import '../models.dart';
import '../services/meal_log_service.dart';
import '../theme.dart';

const _defaultGoal = 2000;

String _localDayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

String _formatTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

(String emoji, String caption, Color color) _moodFor(num pct) {
  if (pct < 40) return ('😴', 'Encore un petit creux ?', AppColors.inkSoft);
  if (pct < 90) return ('🙂', 'Sur la bonne voie', AppColors.herb);
  if (pct <= 110) return ('😋', 'Objectif atteint !', AppColors.accent);
  return ('😅', 'Un peu au-dessus aujourd\'hui', AppColors.gold);
}

/// Dashboard du jour : anneau de calories + petit personnage qui réagit à
/// la progression, macros vs objectif, liste des repas du jour, navigation
/// jour précédent/suivant. Mirrors Dashboard.tsx on the web — replaces the
/// old NutritionScreen hidden behind a "Journal" icon.
class DashboardCard extends StatefulWidget {
  final List<MealLog> logs;
  final num? dailyKcalGoal;
  final ValueChanged<num> onSetGoal;
  final VoidCallback onAddMeal;
  final bool readOnly;

  const DashboardCard({
    super.key,
    required this.logs,
    required this.dailyKcalGoal,
    required this.onSetGoal,
    required this.onAddMeal,
    required this.readOnly,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  final _service = MealLogService();
  int _dayOffset = 0;
  bool _editingGoal = false;
  late final TextEditingController _goalCtrl;
  String? _deletingId;

  num get _goal => (widget.dailyKcalGoal != null && widget.dailyKcalGoal! > 0) ? widget.dailyKcalGoal! : _defaultGoal;

  @override
  void initState() {
    super.initState();
    _goalCtrl = TextEditingController(text: '${_goal.round()}');
  }

  @override
  void didUpdateWidget(covariant DashboardCard old) {
    super.didUpdateWidget(old);
    if (!_editingGoal) _goalCtrl.text = '${_goal.round()}';
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete(MealLog l) async {
    setState(() => _deletingId = l.id);
    try {
      await _service.deleteMealLog(l.id, l.photoUrl);
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  void _commitGoal() {
    final v = num.tryParse(_goalCtrl.text);
    if (v != null && v > 0) widget.onSetGoal(v.round());
    setState(() => _editingGoal = false);
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

    final dayLogs = widget.logs.where((l) {
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

    final pct = _goal > 0 ? (totalKcal / _goal) * 100 : 0;
    final mood = _moodFor(pct);
    final ringPct = pct.clamp(0, 100) / 100;
    final proteinTarget = (_goal * 0.25 / 4).round();
    final carbsTarget = (_goal * 0.45 / 4).round();
    final fatTarget = (_goal * 0.3 / 9).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: () => setState(() => _dayOffset -= 1), icon: const Icon(Icons.chevron_left)),
              Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              IconButton(
                onPressed: _dayOffset == 0 ? null : () => setState(() => _dayOffset += 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 9,
                        color: AppColors.surface2,
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: ringPct.toDouble(),
                        strokeWidth: 9,
                        color: mood.$3,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mood.$1, style: const TextStyle(fontSize: 28)),
                        Text('${totalKcal.round()}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('/ ${_goal.round()} kcal', style: const TextStyle(fontSize: 9, color: AppColors.inkSoft)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mood.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    _MacroBar(label: 'Protéines', value: totalProtein, target: proteinTarget, color: const Color(0xFFE5484D)),
                    _MacroBar(label: 'Glucides', value: totalCarbs, target: carbsTarget, color: const Color(0xFFFFC93C)),
                    _MacroBar(label: 'Lipides', value: totalFat, target: fatTarget, color: const Color(0xFF17A2B8)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('Objectif : ', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                        _editingGoal
                            ? SizedBox(
                                width: 60,
                                child: TextField(
                                  controller: _goalCtrl,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 11),
                                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                                  onSubmitted: (_) => _commitGoal(),
                                  onTapOutside: (_) => _commitGoal(),
                                ),
                              )
                            : GestureDetector(
                                onTap: () => setState(() => _editingGoal = true),
                                child: Text(
                                  '${_goal.round()} kcal/jour',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!widget.readOnly) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: widget.onAddMeal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter un repas'),
            ),
          ],
          const SizedBox(height: 10),
          if (dayLogs.isEmpty)
            const Text('Aucun repas enregistré ce jour-là.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5))
          else
            for (final l in dayLogs)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                          Text('${mealTypeLabel(l.mealType)} · ${_formatTime(l.eatenAt)} · ${l.portionGrams} g',
                              style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                    Text('${l.kcal} kcal', style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
                    if (!widget.readOnly)
                      IconButton(
                        onPressed: _deletingId == l.id ? null : () => _delete(l),
                        icon: const Icon(Icons.close, size: 17),
                        color: AppColors.inkSoft,
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final num value;
  final num target;
  final Color color;
  const _MacroBar({required this.label, required this.value, required this.target, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (value / target).clamp(0, 1).toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(width: 58, child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.inkSoft))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: pct, minHeight: 5, color: color, backgroundColor: AppColors.surface2),
            ),
          ),
          const SizedBox(width: 6),
          Text('${value.round()}/${target}g', style: const TextStyle(fontSize: 10, color: AppColors.inkSoft, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
