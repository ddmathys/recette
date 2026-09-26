import 'package:flutter/material.dart';

import '../meal_types.dart';
import '../models.dart';
import '../services/meal_log_service.dart';
import '../theme.dart';

/// Ouvre la feuille "Modifier le repas" pour un repas du journal.
Future<void> showEditMealLogSheet(BuildContext context, MealLog log) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _EditMealLogSheet(log: log),
  );
}

/// Modifier (ou supprimer) un repas déjà noté, depuis le dashboard. Changer
/// la quantité recalcule proportionnellement calories et macros. Mirrors
/// EditMealLogDialog.tsx on the web.
class _EditMealLogSheet extends StatefulWidget {
  final MealLog log;
  const _EditMealLogSheet({required this.log});

  @override
  State<_EditMealLogSheet> createState() => _EditMealLogSheetState();
}

class _EditMealLogSheetState extends State<_EditMealLogSheet> {
  final _service = MealLogService();
  late final _label = TextEditingController(text: widget.log.label);
  late final _grams = TextEditingController(text: '${widget.log.portionGrams.round()}');
  late final _kcal = TextEditingController(text: '${widget.log.kcal.round()}');
  late final _protein = TextEditingController(text: '${widget.log.proteinG.round()}');
  late final _carbs = TextEditingController(text: '${widget.log.carbsG.round()}');
  late final _fat = TextEditingController(text: '${widget.log.fatG.round()}');
  late String _mealType = widget.log.mealType;
  late DateTime _eatenAt = DateTime.tryParse(widget.log.eatenAt)?.toLocal() ?? DateTime.now();
  String? _busy;
  String? _error;

  @override
  void dispose() {
    for (final c in [_label, _grams, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  void _scaleTo(num grams) {
    // Proportionnel aux valeurs d'origine, pour ne pas cumuler d'arrondis.
    final l = widget.log;
    final ratio = l.portionGrams > 0 ? grams / l.portionGrams : 1;
    _kcal.text = '${(l.kcal * ratio).round()}';
    _protein.text = '${(l.proteinG * ratio).round()}';
    _carbs.text = '${(l.carbsG * ratio).round()}';
    _fat.text = '${(l.fatG * ratio).round()}';
  }

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _eatenAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_eatenAt));
    setState(() => _eatenAt = DateTime(d.year, d.month, d.day, t?.hour ?? _eatenAt.hour, t?.minute ?? _eatenAt.minute));
  }

  num _n(TextEditingController c) => num.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    if (_label.text.trim().isEmpty) {
      setState(() => _error = 'Donne un nom à ce repas.');
      return;
    }
    setState(() {
      _busy = 'save';
      _error = null;
    });
    try {
      await _service.updateMealLog(
        widget.log.id,
        MealLogDraft(
          recipeId: widget.log.recipeId,
          label: _label.text.trim(),
          mealType: _mealType,
          eatenAt: _eatenAt,
          portionGrams: _n(_grams),
          kcal: _n(_kcal),
          proteinG: _n(_protein),
          carbsG: _n(_carbs),
          fatG: _n(_fat),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = "L'enregistrement a échoué, réessaie.";
          _busy = null;
        });
      }
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = 'delete');
    try {
      await _service.deleteMealLog(widget.log.id, widget.log.photoUrl);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'La suppression a échoué, réessaie.';
          _busy = null;
        });
      }
    }
  }

  Widget _numField(String label, TextEditingController c, {ValueChanged<String>? onChanged}) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    String pad(int n) => n.toString().padLeft(2, "0");
    final whenLabel = '${dayLabel(_eatenAt)} · ${pad(_eatenAt.hour)}:${pad(_eatenAt.minute)}';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Modifier le repas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            if (widget.log.photoUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(widget.log.photoUrl!, height: 120, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
              const SizedBox(height: 12),
            ],
            TextField(controller: _label, decoration: const InputDecoration(labelText: 'Nom')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in kMealTypes)
                  ChoiceChip(
                    label: Text(m.$2),
                    selected: _mealType == m.$1,
                    selectedColor: AppColors.accent,
                    labelStyle: TextStyle(color: _mealType == m.$1 ? Colors.white : AppColors.ink),
                    onSelected: (_) => setState(() => _mealType = m.$1),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(whenLabel),
              trailing: const Icon(Icons.edit, size: 18),
              onTap: _pickWhen,
            ),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: _numField('Quantité (g)', _grams, onChanged: (v) => _scaleTo(num.tryParse(v) ?? 0)),
                ),
                const SizedBox(width: 8),
                for (final f in [0.5, 1.5, 2.0])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text('× ${f.toString().replaceAll('.0', '').replaceAll('.', ',')}'),
                      onPressed: () {
                        final g = (widget.log.portionGrams * f).round();
                        _grams.text = '$g';
                        setState(() => _scaleTo(g));
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numField('Kcal', _kcal)),
                const SizedBox(width: 8),
                Expanded(child: _numField('Prot. g', _protein)),
                const SizedBox(width: 8),
                Expanded(child: _numField('Gluc. g', _carbs)),
                const SizedBox(width: 8),
                Expanded(child: _numField('Lip. g', _fat)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _busy != null ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(_busy == 'save' ? 'Enregistrement…' : 'Enregistrer', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            TextButton(
              onPressed: _busy != null ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              child: Text(_busy == 'delete' ? 'Suppression…' : 'Supprimer ce repas'),
            ),
          ],
        ),
      ),
    );
  }
}
