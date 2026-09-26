import 'package:flutter/material.dart';

import '../habits.dart';
import '../meal_types.dart';
import '../theme.dart';

/// "Tes habituels" : ce que tu as déjà noté, à renoter en un tap avec la
/// quantité (×1 à ×4), mêmes calories. Mirrors HabitsList.tsx.
class HabitsList extends StatefulWidget {
  final List<Habit> habits;
  final Future<void> Function(Habit h, int count) onLog;
  final bool showType;
  const HabitsList({super.key, required this.habits, required this.onLog, this.showType = false});

  @override
  State<HabitsList> createState() => _HabitsListState();
}

class _HabitsListState extends State<HabitsList> {
  final _done = <String, int>{};
  String? _busy;

  Future<void> _log(Habit h, int n) async {
    final key = h.label.toLowerCase();
    setState(() => _busy = key);
    try {
      await widget.onLog(h, n);
      if (mounted) setState(() => _done[key] = n);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.habits.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'TES HABITUELS',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          const Text(
            'Touche la quantité pour le noter tout de suite, avec les mêmes calories.',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < widget.habits.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            _row(widget.habits[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(Habit h) {
    final key = h.label.toLowerCase();
    final done = _done[key];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            h.label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "${h.kcal} kcal l'unité${widget.showType ? ' · ${mealTypeLabel(h.mealType)}' : ''} · noté ${h.times}×",
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          done != null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.herb.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      '✓ Ajouté${done > 1 ? ' ×$done' : ''}',
                      style: const TextStyle(color: AppColors.herb, fontWeight: FontWeight.w800),
                    ),
                  ),
                )
              : Row(
                  children: [
                    for (final n in [1, 2, 3, 4])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 52,
                          height: 38,
                          child: OutlinedButton(
                            onPressed: _busy != null ? null : () => _log(h, n),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: AppColors.ink,
                              side: const BorderSide(color: AppColors.line, width: 2),
                              shape: const StadiumBorder(),
                            ),
                            child: Text('×$n', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                  ],
                ),
        ],
      ),
    );
  }
}
