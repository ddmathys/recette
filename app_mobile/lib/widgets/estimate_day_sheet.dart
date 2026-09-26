import 'package:flutter/material.dart';

import '../habits.dart';
import '../meal_types.dart';
import '../models.dart';
import '../services/meal_log_service.dart';
import '../theme.dart';

/// "Je ne sais plus ce que j'ai mangé" : compléter une journée avec une
/// estimation (ta moyenne, sinon ton objectif). On n'ajoute que ce qui
/// manque. Mirrors EstimateDayDialog.tsx.
Future<void> showEstimateDaySheet(
  BuildContext context, {
  required DateTime day,
  required List<MealLog> logs,
  required num goal,
  required String ownerUid,
  required String ownerName,
  required String householdId,
}) {
  final e = estimateFor(logs, day, goal);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _EstimateSheet(
      day: day,
      already: e.already,
      suggested: e.suggested,
      fromAverage: e.fromAverage,
      split: (e.protein, e.carbs, e.fat),
      ownerUid: ownerUid,
      ownerName: ownerName,
      householdId: householdId,
    ),
  );
}

class _EstimateSheet extends StatefulWidget {
  final DateTime day;
  final num already;
  final num suggested;
  final bool fromAverage;
  final (double, double, double) split;
  final String ownerUid;
  final String ownerName;
  final String householdId;
  const _EstimateSheet({
    required this.day,
    required this.already,
    required this.suggested,
    required this.fromAverage,
    required this.split,
    required this.ownerUid,
    required this.ownerName,
    required this.householdId,
  });

  @override
  State<_EstimateSheet> createState() => _EstimateSheetState();
}

class _EstimateSheetState extends State<_EstimateSheet> {
  late int _total = [((widget.suggested / 50).round() * 50).toInt(), widget.already.round().toInt()].reduce((a, b) => a > b ? a : b);
  late final _ctrl = TextEditingController(text: '$_total');
  bool _busy = false;
  String? _error;

  int get _missing => (_total - widget.already).round().clamp(0, 100000).toInt();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_missing <= 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _busy = true);
    final (p, c, f) = widget.split;
    try {
      await MealLogService().addMealLog(
        MealLogDraft(
          label: widget.already > 0 ? 'Estimation (reste de la journée)' : 'Journée estimée',
          mealType: 'diner',
          eatenAt: eatenAtFor(widget.day, 'diner'),
          portionGrams: 0,
          kcal: _missing,
          proteinG: (_missing * p / 4).round(),
          carbsG: (_missing * c / 4).round(),
          fatG: (_missing * f / 9).round(),
        ),
        source: 'estimate',
        ownerUid: widget.ownerUid,
        ownerName: widget.ownerName,
        householdId: widget.householdId,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "L'enregistrement a échoué, réessaie.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Estimer ${dayLabel(widget.day).toLowerCase()}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            Text(
              "Tu ne sais plus exactement ? Indique à peu près combien tu as mangé en tout ce jour-là. Je propose "
              "${widget.fromAverage ? 'ta moyenne des jours notés' : "ton objectif (pas encore assez d'historique)"}.",
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
              decoration: const InputDecoration(labelText: 'Total de la journée (kcal)'),
              onChanged: (v) => setState(() => _total = int.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in [1500, 1800, 2000, 2200, 2500, 2800])
                  ChoiceChip(
                    label: Text('$v'),
                    selected: _total == v,
                    onSelected: (_) => setState(() {
                      _total = v;
                      _ctrl.text = '$v';
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
              child: Text(
                widget.already > 0
                    ? 'Déjà noté : ${widget.already.round()} kcal → j\'ajoute $_missing kcal estimées.'
                    : "J'ajoute $_missing kcal estimées pour cette journée.",
              ),
            ),
            if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.accent))],
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _busy ? 'Enregistrement…' : (_missing > 0 ? 'Ajouter $_missing kcal' : 'Rien à ajouter'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
