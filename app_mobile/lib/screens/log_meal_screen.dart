import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../meal_types.dart';
import '../models.dart';
import '../services/ai_service.dart';
import '../services/meal_log_service.dart';
import '../theme.dart';
import '../widgets/recipe_form_fields.dart';

Recipe? _recipeById(List<Recipe> recipes, String? id) {
  if (id == null) return null;
  for (final r in recipes) {
    if (r.id == id) return r;
  }
  return null;
}

/// Log a meal eaten — from a recipe (portion-scaled macros) or freeform,
/// optionally kicked off by a photo that Gemini identifies. Mirrors
/// LogMealDialog.tsx on the web. Always shows an editable review before
/// saving, whether the fields came from a recipe, a photo, or by hand.
class LogMealScreen extends StatefulWidget {
  final List<Recipe> recipes;
  final Recipe? initialRecipe;
  final String ownerUid;
  final String ownerName;
  final String householdId;

  const LogMealScreen({
    super.key,
    required this.recipes,
    this.initialRecipe,
    required this.ownerUid,
    required this.ownerName,
    required this.householdId,
  });

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  final _mealLogService = MealLogService();
  final _aiService = AiService();

  String _mode = 'manual'; // "recipe" | "manual"
  String? _recipeId;
  late final TextEditingController _labelCtrl;
  String _mealType = guessMealType();
  DateTime _eatenAt = DateTime.now();
  late final TextEditingController _portionCtrl;
  late final TextEditingController _kcalCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;

  XFile? _photoFile;
  String? _uploadedPhotoUrl;
  bool _analyzing = false;
  String? _photoError;

  bool _saving = false;
  String? _error;

  Recipe? get _selectedRecipe => _recipeById(widget.recipes, _recipeId);

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecipe;
    _mode = r != null ? 'recipe' : 'manual';
    _recipeId = r?.id;
    _labelCtrl = TextEditingController(text: r?.name ?? '');
    final n = r?.nutrition;
    _portionCtrl = TextEditingController(text: '${n?.gramsPerServing ?? 250}');
    _kcalCtrl = TextEditingController(text: '${n?.kcal ?? 0}');
    _proteinCtrl = TextEditingController(text: '${n?.proteinG ?? 0}');
    _carbsCtrl = TextEditingController(text: '${n?.carbsG ?? 0}');
    _fatCtrl = TextEditingController(text: '${n?.fatG ?? 0}');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _portionCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  void _applyRecipe(Recipe? r) {
    setState(() {
      _recipeId = r?.id;
      if (r == null) return;
      _labelCtrl.text = r.name;
      final n = r.nutrition;
      if (n != null) {
        _portionCtrl.text = '${n.gramsPerServing}';
        final scaled = n.scaledTo(n.gramsPerServing);
        _kcalCtrl.text = '${scaled['kcal']}';
        _proteinCtrl.text = '${scaled['proteinG']}';
        _carbsCtrl.text = '${scaled['carbsG']}';
        _fatCtrl.text = '${scaled['fatG']}';
      }
    });
  }

  void _applyPortion(String v) {
    final grams = num.tryParse(v) ?? 0;
    final n = _selectedRecipe?.nutrition;
    if (n == null) return;
    final scaled = n.scaledTo(grams);
    setState(() {
      _kcalCtrl.text = '${scaled['kcal']}';
      _proteinCtrl.text = '${scaled['proteinG']}';
      _carbsCtrl.text = '${scaled['carbsG']}';
      _fatCtrl.text = '${scaled['fatG']}';
    });
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choisir depuis la galerie'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, maxWidth: 2400, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _photoFile = file;
      _uploadedPhotoUrl = null;
      _photoError = null;
    });
  }

  Future<void> _analyzePhoto() async {
    final file = _photoFile;
    if (file == null) return;
    setState(() {
      _analyzing = true;
      _photoError = null;
    });
    try {
      final url = await _mealLogService.uploadMealPhoto(widget.ownerUid, file);
      setState(() => _uploadedPhotoUrl = url);
      final result = await _aiService.analyzeMealPhoto(url, widget.recipes);

      final matched = _recipeById(widget.recipes, result.matchedRecipeId);
      if (matched != null) {
        _applyRecipe(matched);
      } else {
        setState(() {
          _mode = 'manual';
          _recipeId = null;
        });
      }
      setState(() {
        if (result.label != null && result.label!.trim().isNotEmpty) _labelCtrl.text = result.label!.trim();
        if ((result.portionGrams ?? 0) > 0) _portionCtrl.text = '${result.portionGrams}';
        if (result.kcal != null) _kcalCtrl.text = '${result.kcal}';
        if (result.proteinG != null) _proteinCtrl.text = '${result.proteinG}';
        if (result.carbsG != null) _carbsCtrl.text = '${result.carbsG}';
        if (result.fatG != null) _fatCtrl.text = '${result.fatG}';
        if (result.mealType != null && kMealTypes.any((m) => m.$1 == result.mealType)) {
          _mealType = result.mealType!;
        }
      });
    } catch (e) {
      setState(() => _photoError = e.toString());
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eatenAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_eatenAt));
    if (!mounted) return;
    setState(() {
      _eatenAt = DateTime(date.year, date.month, date.day, time?.hour ?? _eatenAt.hour, time?.minute ?? _eatenAt.minute);
    });
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    final portion = num.tryParse(_portionCtrl.text) ?? 0;
    if (label.isEmpty) {
      setState(() => _error = 'Donne un nom à ce repas.');
      return;
    }
    if (portion <= 0) {
      setState(() => _error = 'Indique une quantité en grammes.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final source = _uploadedPhotoUrl != null ? 'photo' : (_mode == 'recipe' && _recipeId != null ? 'recipe' : 'manual');
    try {
      await _mealLogService.addMealLog(
        MealLogDraft(
          recipeId: _mode == 'recipe' ? _recipeId : null,
          label: label,
          mealType: _mealType,
          eatenAt: _eatenAt,
          portionGrams: portion,
          kcal: num.tryParse(_kcalCtrl.text) ?? 0,
          proteinG: num.tryParse(_proteinCtrl.text) ?? 0,
          carbsG: num.tryParse(_carbsCtrl.text) ?? 0,
          fatG: num.tryParse(_fatCtrl.text) ?? 0,
        ),
        photoUrl: _uploadedPhotoUrl,
        source: source,
        ownerUid: widget.ownerUid,
        ownerName: widget.ownerName,
        householdId: widget.householdId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _error = "L'enregistrement a échoué, réessaie.";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repas mangé')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Photo (optionnel)'),
              Row(
                children: [
                  if (_photoFile != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(_photoFile!.path), width: 56, height: 56, fit: BoxFit.cover),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: _pickPhoto,
                    child: Text(_photoFile != null ? 'Changer la photo' : 'Prendre / choisir une photo'),
                  ),
                  if (_photoFile != null) ...[
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _analyzing ? null : _analyzePhoto,
                      icon: _analyzing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(_analyzing ? 'Analyse…' : 'Analyser (Gemini)'),
                    ),
                  ],
                ],
              ),
              if (_photoError != null) ...[
                const SizedBox(height: 8),
                Text(_photoError!, style: const TextStyle(color: AppColors.accent, fontSize: 12.5)),
              ],
              const SizedBox(height: 4),
              const Text(
                'La photo permet de pré-remplir le repas automatiquement — vérifie et corrige les valeurs avant d\'enregistrer.',
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _mode == 'recipe' ? AppColors.accent.withValues(alpha: 0.1) : null,
                      side: BorderSide(color: _mode == 'recipe' ? AppColors.accent : AppColors.line),
                    ),
                    onPressed: () => setState(() => _mode = 'recipe'),
                    child: Text('Depuis une recette', style: TextStyle(color: _mode == 'recipe' ? AppColors.accent : AppColors.inkSoft)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _mode == 'manual' ? AppColors.accent.withValues(alpha: 0.1) : null,
                      side: BorderSide(color: _mode == 'manual' ? AppColors.accent : AppColors.line),
                    ),
                    onPressed: () => setState(() {
                      _mode = 'manual';
                      _recipeId = null;
                    }),
                    child: Text('Libre', style: TextStyle(color: _mode == 'manual' ? AppColors.accent : AppColors.inkSoft)),
                  ),
                ),
              ]),
              if (_mode == 'recipe') ...[
                const SizedBox(height: 14),
                const FieldLabel('Recette'),
                DropdownButtonFormField<String>(
                  initialValue: _recipeId,
                  hint: const Text('— choisir —'),
                  items: [for (final r in widget.recipes) DropdownMenuItem(value: r.id, child: Text(r.name, overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => _applyRecipe(_recipeById(widget.recipes, v)),
                ),
                if (_recipeId != null && _selectedRecipe?.nutrition == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      "Cette recette n'a pas d'estimation nutritionnelle — renseigne les valeurs à la main ci-dessous.",
                      style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              const FieldLabel('Nom du repas'),
              TextField(controller: _labelCtrl),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const FieldLabel('Type de repas'),
                    DropdownButtonFormField<String>(
                      initialValue: _mealType,
                      items: [for (final m in kMealTypes) DropdownMenuItem(value: m.$1, child: Text(m.$2))],
                      onChanged: (v) => setState(() => _mealType = v ?? _mealType),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const FieldLabel('Mangé le'),
                    OutlinedButton(
                      onPressed: _pickDate,
                      child: Text(
                        '${_eatenAt.day}/${_eatenAt.month}/${_eatenAt.year} ${_eatenAt.hour.toString().padLeft(2, '0')}:${_eatenAt.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 90,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const FieldLabel('Portion (g)'),
                      TextField(controller: _portionCtrl, keyboardType: TextInputType.number, onChanged: _applyPortion),
                    ]),
                  ),
                  SizedBox(
                    width: 90,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const FieldLabel('Kcal'),
                      TextField(controller: _kcalCtrl, keyboardType: TextInputType.number),
                    ]),
                  ),
                  SizedBox(
                    width: 90,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const FieldLabel('Protéines (g)'),
                      TextField(controller: _proteinCtrl, keyboardType: TextInputType.number),
                    ]),
                  ),
                  SizedBox(
                    width: 90,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const FieldLabel('Glucides (g)'),
                      TextField(controller: _carbsCtrl, keyboardType: TextInputType.number),
                    ]),
                  ),
                  SizedBox(
                    width: 90,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const FieldLabel('Lipides (g)'),
                      TextField(controller: _fatCtrl, keyboardType: TextInputType.number),
                    ]),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.accent)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
