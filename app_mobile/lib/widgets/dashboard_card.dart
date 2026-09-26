import 'package:flutter/material.dart';

import '../meal_types.dart';
import '../models.dart';
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
/// jour précédent/suivant. Mirrors Dashboard.tsx on the web.
class DashboardCard extends StatefulWidget {
  final List<MealLog> logs;
  final num? dailyKcalGoal;
  final ValueChanged<num> onSetGoal;
  final bool readOnly;

  /// Jour affiché (0 = aujourd'hui, -1 = hier…), piloté par l'accueil pour
  /// que les ajouts aillent sur ce jour-là.
  final int dayOffset;
  final ValueChanged<int> onDayOffset;
  final ValueChanged<MealLog> onEditLog;

  /// "Je ne sais plus" → estimer la journée affichée.
  final VoidCallback onEstimateDay;

  /// Actions affichées entre l'anneau et la liste des repas (accueil).
  final Widget? actions;

  const DashboardCard({
    super.key,
    required this.logs,
    required this.dailyKcalGoal,
    required this.onSetGoal,
    required this.readOnly,
    required this.dayOffset,
    required this.onDayOffset,
    required this.onEditLog,
    required this.onEstimateDay,
    this.actions,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  bool _editingGoal = false;
  late final TextEditingController _goalCtrl;

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

  void _commitGoal() {
    final v = num.tryParse(_goalCtrl.text);
    if (v != null && v > 0) widget.onSetGoal(v.round());
    setState(() => _editingGoal = false);
  }

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().add(Duration(days: widget.dayOffset));
    final dayKey = _localDayKey(day);

    final dayLogs = widget.logs.where((l) {
      final d = DateTime.tryParse(l.eatenAt)?.toLocal();
      return d != null && _localDayKey(d) == dayKey;
    }).toList()..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));

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
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: () => widget.onDayOffset(widget.dayOffset - 1), icon: const Icon(Icons.chevron_left)),
              Text(dayLabel(day), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              IconButton(
                onPressed: widget.dayOffset == 0 ? null : () => widget.onDayOffset(widget.dayOffset + 1),
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
                      child: CircularProgressIndicator(value: 1, strokeWidth: 9, color: AppColors.surface2),
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
                        Text(
                          '${totalKcal.round()}',
                          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 15),
                        ),
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
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  ),
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
          if (widget.actions != null) ...[const SizedBox(height: 14), widget.actions!],
          const SizedBox(height: 10),
          if (dayLogs.isEmpty)
            const Text('Aucun repas enregistré ce jour-là.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5))
          else
            for (final l in dayLogs)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.readOnly ? null : () => widget.onEditLog(l),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (l.count != null && l.count! > 1) ? '${l.label} ×${l.count}' : l.label,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  l.source == 'estimate'
                                      ? 'Estimation · valeurs approximatives'
                                      : '${mealTypeLabel(l.mealType)} · ${_formatTime(l.eatenAt)} · ${l.portionGrams} g',
                                  style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          Text('${l.kcal} kcal', style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
                          if (!widget.readOnly) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.edit_outlined, size: 16, color: AppColors.inkSoft),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          if (!widget.readOnly)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onEstimateDay,
                style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft, padding: EdgeInsets.zero),
                child: const Text(
                  "Je ne sais plus ce que j'ai mangé → estimer la journée",
                  style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                ),
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
          SizedBox(
            width: 58,
            child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.inkSoft)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: pct, minHeight: 5, color: color, backgroundColor: AppColors.surface2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${value.round()}/${target}g',
            style: const TextStyle(fontSize: 10, color: AppColors.inkSoft, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
