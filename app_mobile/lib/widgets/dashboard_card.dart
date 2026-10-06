import 'dart:math' as math;

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

(String emoji, String caption) _moodFor(num pct) {
  if (pct < 40) return ('😴', 'La journée commence');
  if (pct < 90) return ('🙂', 'Sur la bonne voie');
  if (pct <= 110) return ('😋', 'Objectif atteint !');
  return ('😅', 'Un peu au-dessus');
}

const _monthsLong = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];
const _weekdaysLong = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

/// « Ma journée » : anneau de calories segmenté par moment de la journée,
/// macros vs objectif, puis les 4 créneaux (petit-déj / déjeuner / dîner /
/// collations), chacun avec son total et son « + » qui ouvre tout ce qu'on
/// peut y mettre. Mirrors Dashboard.tsx on the web.
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

  /// Ouvre le choix d'ajout pour ce créneau, sur le jour affiché.
  final ValueChanged<String> onAddToSlot;

  /// "Je ne sais plus" → estimer la journée affichée.
  final VoidCallback onEstimateDay;

  /// Tuiles de navigation affichées sous les créneaux (accueil).
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
    required this.onAddToSlot,
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

    // Un total de journée estimé n'appartient à aucun créneau : il est
    // listé à part, sous les créneaux.
    final estimates = dayLogs.where((l) => l.source == 'estimate').toList();
    final bySlot = <String, List<MealLog>>{for (final s in kMealSlots) s.key: []};
    for (final l in dayLogs) {
      if (l.source == 'estimate') continue;
      bySlot[l.mealType]?.add(l);
    }

    final pct = _goal > 0 ? (totalKcal / _goal) * 100 : 0;
    final mood = _moodFor(pct);
    final left = (_goal - totalKcal).round();
    final proteinTarget = (_goal * 0.25 / 4).round();
    final carbsTarget = (_goal * 0.45 / 4).round();
    final fatTarget = (_goal * 0.3 / 9).round();

    final segments = <(Color, double)>[];
    for (final s in kMealSlots) {
      final kcal = (bySlot[s.key] ?? []).fold<num>(0, (a, l) => a + l.kcal);
      if (kcal > 0) segments.add((s.color, (kcal / _goal).toDouble()));
    }
    final estKcal = estimates.fold<num>(0, (a, l) => a + l.kcal);
    if (estKcal > 0) segments.add((AppColors.inkSoft, (estKcal / _goal).toDouble()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Anneau du jour ───────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFDF8), Color(0xFFFDF4E4)],
            ),
            boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundIcon(icon: Icons.chevron_left, onTap: () => widget.onDayOffset(widget.dayOffset - 1)),
                  Column(
                    children: [
                      Text(dayLabel(day), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
                      Text(
                        '${_weekdaysLong[day.weekday - 1]} ${day.day} ${_monthsLong[day.month - 1]}'.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                  _RoundIcon(
                    icon: Icons.chevron_right,
                    onTap: widget.dayOffset == 0 ? null : () => widget.onDayOffset(widget.dayOffset + 1),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 136,
                    height: 136,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(size: const Size(136, 136), painter: _RingPainter(segments)),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${totalKcal.round()}',
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 28, height: 1),
                            ),
                            const Text(
                              'KCAL',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: AppColors.inkSoft),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
                              child: Text(
                                left > 0 ? 'reste $left' : (left == 0 ? 'pile !' : '+${left.abs()}'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.inkSoft),
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          top: 2,
                          right: 0,
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.16), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Text(mood.$1, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mood.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Text('objectif ', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                            _editingGoal
                                ? SizedBox(
                                    width: 62,
                                    child: TextField(
                                      controller: _goalCtrl,
                                      autofocus: true,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 11.5),
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
                                      '${_goal.round()} kcal',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _MacroBar(label: 'Protéines', value: totalProtein, target: proteinTarget, color: const Color(0xFFE5484D)),
                        _MacroBar(label: 'Glucides', value: totalCarbs, target: carbsTarget, color: const Color(0xFFFFC93C)),
                        _MacroBar(label: 'Lipides', value: totalFat, target: fatTarget, color: const Color(0xFF17A2B8)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Les 4 créneaux du jour ───────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(26)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Ce que j'ai mangé", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                      '${totalKcal.round()} kcal',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              for (final slot in kMealSlots) ...[
                _SlotCard(
                  slot: slot,
                  logs: bySlot[slot.key] ?? const [],
                  readOnly: widget.readOnly,
                  onAdd: () => widget.onAddToSlot(slot.key),
                  onEditLog: widget.onEditLog,
                ),
                const SizedBox(height: 8),
              ],
              for (final l in estimates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: widget.readOnly ? null : () => widget.onEditLog(l),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                                const Text(
                                  'Estimation · valeurs approximatives',
                                  style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          Text('${l.kcal}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (!widget.readOnly && dayLogs.isEmpty)
                TextButton(
                  onPressed: widget.onEstimateDay,
                  style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
                  child: const Text(
                    "Je ne sais plus ce que j'ai mangé → estimer la journée",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),

        if (widget.actions != null) ...[const SizedBox(height: 10), widget.actions!],
      ],
    );
  }
}

/// Un créneau : son total, son bouton « + », et les repas qui y sont notés.
class _SlotCard extends StatelessWidget {
  final MealSlot slot;
  final List<MealLog> logs;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<MealLog> onEditLog;

  const _SlotCard({
    required this.slot,
    required this.logs,
    required this.readOnly,
    required this.onAdd,
    required this.onEditLog,
  });

  @override
  Widget build(BuildContext context) {
    final kcal = logs.fold<num>(0, (a, l) => a + l.kcal);
    return Container(
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: slot.color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Text(slot.emoji, style: const TextStyle(fontSize: 17)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      Text(
                        logs.isEmpty
                            ? 'rien de noté'
                            : '${logs.length} ${logs.length > 1 ? "entrées" : "entrée"} · ${kcal.round()} kcal',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                if (!readOnly)
                  InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: slot.color,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: slot.color.withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 22),
                    ),
                  ),
              ],
            ),
          ),
          for (final l in logs)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: readOnly ? null : () => onEditLog(l),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                                '${_formatTime(l.eatenAt)} · ${l.portionGrams} g${l.recipeId != null ? " · depuis une recette" : ""}',
                                style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                        Text('${l.kcal}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 12.5)),
                        if (!readOnly) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.edit_outlined, size: 15, color: AppColors.inkSoft),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Anneau segmenté : un arc par créneau, dans l'ordre de la journée.
class _RingPainter extends CustomPainter {
  final List<(Color, double)> segments;
  const _RingPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFEFE7D6);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    var cursor = 0.0;
    for (final (color, frac) in segments) {
      if (cursor >= 1) break;
      final len = math.min(frac, 1 - cursor);
      if (len <= 0.002) {
        cursor += frac;
        continue;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color;
      canvas.drawArc(rect, -math.pi / 2 + cursor * math.pi * 2, len * math.pi * 2, false, paint);
      cursor += frac;
    }

    if (cursor > 1) {
      final over = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.gold;
      canvas.drawArc(rect.deflate(10), 0, math.pi * 2, false, over);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.segments != segments;
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: onTap == null ? AppColors.line : AppColors.inkSoft),
        ),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: pct, minHeight: 7, color: color, backgroundColor: const Color(0xFFEFE7D6)),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 58,
            child: Text(
              '${value.round()}/$target g',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10, color: AppColors.inkSoft, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
