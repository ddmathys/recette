import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../meal_types.dart';
import '../models.dart';
import '../services/ai_service.dart';
import '../services/meal_log_service.dart';
import '../services/recipe_service.dart';
import '../theme.dart';
import '../widgets/recipe_form_fields.dart';

enum _Stage { source, review }
enum _SourceMode { photo, text, manual }

Recipe? _recipeById(List<Recipe> recipes, String? id) {
  if (id == null) return null;
  for (final r in recipes) {
    if (r.id == id) return r;
  }
  return null;
}

RecipeDraft _blankDraft() => RecipeDraft();

/// Point d'entrée unique pour "j'ai un repas" — remplace AddRecipeScreen et
/// LogMealScreen. Deux issues combinables : logguer le repas du jour
/// (mealLogs) et/ou l'ajouter à la bibliothèque (recipes). Mirrors
/// CaptureDialog.tsx on the web.
class CaptureScreen extends StatefulWidget {
  final List<Recipe> recipes;
  final Recipe? initialRecipe;
  final String ownerUid;
  final String ownerName;
  final String householdId;
  final bool defaultLogMeal;
  final bool defaultAddToLibrary;

  const CaptureScreen({
    super.key,
    required this.recipes,
    this.initialRecipe,
    required this.ownerUid,
    required this.ownerName,
    required this.householdId,
    required this.defaultLogMeal,
    required this.defaultAddToLibrary,
  });

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _recipeService = RecipeService();
  final _mealLogService = MealLogService();
  final _aiService = AiService();

  late _Stage _stage = widget.initialRecipe != null ? _Stage.review : _Stage.source;
  _SourceMode _sourceMode = _SourceMode.photo;

  final _textCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  bool _aiBusy = false;
  String? _aiError;
  String? _suggestedPhoto;

  XFile? _photoFile;
  String? _uploadedPhotoUrl;
  bool _analyzing = false;
  String? _photoError;

  late RecipeDraft _draft;
  String? _matchedRecipeId;
  late bool _logMeal;
  late bool _addToLibrary;
  String _mealType = guessMealType();
  DateTime _eatenAt = DateTime.now();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _portionCtrl;
  late final TextEditingController _kcalCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;

  bool _saving = false;
  String? _saveError;

  Recipe? get _matchedRecipe => _recipeById(widget.recipes, _matchedRecipeId);

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecipe;
    _matchedRecipeId = r?.id;
    _logMeal = widget.defaultLogMeal;
    _addToLibrary = r != null ? false : widget.defaultAddToLibrary;
    _draft = r != null
        ? RecipeDraft(
            name: r.name,
            cat: r.cat,
            time: r.time,
            diff: r.diff,
            servings: r.servings,
            veg: r.veg,
            ingr: [...r.ingr],
            steps: [...r.steps],
            nutrition: r.nutrition,
          )
        : _blankDraft();
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
    _textCtrl.dispose();
    _nameCtrl.dispose();
    _linkCtrl.dispose();
    _labelCtrl.dispose();
    _portionCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  void _applyPortion(String v, [NutritionEstimate? nutrition]) {
    final grams = num.tryParse(v) ?? 0;
    final n = nutrition ?? _draft.nutrition;
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
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Prendre une photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choisir depuis la galerie'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
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
      final label = (result.label ?? '').trim().isNotEmpty ? result.label!.trim() : 'Repas';

      NutritionEstimate? analyzed;
      if (result.kcal != null || result.portionGrams != null) {
        analyzed = NutritionEstimate(
          kcal: result.kcal ?? 0,
          proteinG: result.proteinG ?? 0,
          carbsG: result.carbsG ?? 0,
          fatG: result.fatG ?? 0,
          gramsPerServing: (result.portionGrams ?? 0) > 0 ? result.portionGrams! : 250,
          estimatedBy: 'ai',
        );
      }

      setState(() {
        if (matched != null) {
          _matchedRecipeId = matched.id;
          _addToLibrary = false;
          _draft = RecipeDraft(name: matched.name, nutrition: matched.nutrition ?? analyzed);
          _labelCtrl.text = matched.name;
        } else {
          _matchedRecipeId = null;
          _draft.name = label;
          if (analyzed != null) _draft.nutrition = analyzed;
          _labelCtrl.text = label;
        }
        if (kMealTypes.any((m) => m.$1 == result.mealType)) _mealType = result.mealType!;
        _stage = _Stage.review;
      });
      final nutrition = matched?.nutrition ?? analyzed;
      if (nutrition != null) _applyPortion('${nutrition.gramsPerServing}', nutrition);
    } catch (e) {
      setState(() => _photoError = e.toString());
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _generateWithAi() async {
    if (_textCtrl.text.trim().isEmpty && _nameCtrl.text.trim().isEmpty && _linkCtrl.text.trim().isEmpty) {
      setState(() => _aiError = 'Écris un nom de plat, colle un texte, ou donne un lien avant de générer.');
      return;
    }
    setState(() {
      _aiBusy = true;
      _aiError = null;
    });
    try {
      final result = await _aiService.generate(name: _nameCtrl.text.trim(), text: _textCtrl.text.trim(), link: _linkCtrl.text.trim());
      setState(() {
        _draft = result.draft;
        _labelCtrl.text = result.draft.name;
        _suggestedPhoto = result.ogImage;
        _matchedRecipeId = null;
        _stage = _Stage.review;
      });
      if (result.draft.nutrition != null) _applyPortion('${result.draft.nutrition!.gramsPerServing}', result.draft.nutrition);
    } catch (e) {
      setState(() => _aiError = e.toString());
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  void _startManual() {
    setState(() {
      _draft = RecipeDraft(name: _nameCtrl.text.trim());
      _labelCtrl.text = _draft.name;
      _matchedRecipeId = null;
      _stage = _Stage.review;
    });
  }

  Future<void> _save() async {
    final name = _labelCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _saveError = 'Donne un nom à ce repas.');
      return;
    }
    if (!_logMeal && !_addToLibrary) {
      setState(() => _saveError = 'Choisis au moins une option : repas mangé, ou ajouter à la bibliothèque.');
      return;
    }
    final portion = num.tryParse(_portionCtrl.text) ?? 0;
    if (_logMeal && portion <= 0) {
      setState(() => _saveError = 'Indique une quantité en grammes pour le repas.');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      String? recipeIdForLog = _matchedRecipeId;

      if (_addToLibrary && _matchedRecipeId == null) {
        final ingr = _draft.ingr.where((i) => i.name.trim().isNotEmpty).toList();
        final steps = _draft.steps.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        _draft
          ..name = name
          ..ingr = ingr
          ..steps = steps;
        recipeIdForLog = await _recipeService.addRecipe(
          _draft,
          source: _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text.trim(),
          photoUrl: _photoFile == null ? _suggestedPhoto : null,
          ownerUid: widget.ownerUid,
          ownerName: widget.ownerName,
          householdId: widget.householdId,
        );
        if (_photoFile != null && _uploadedPhotoUrl == null) {
          try {
            await _recipeService.uploadRecipePhoto(recipeIdForLog, _photoFile!);
          } catch (_) {
            // Best effort — la recette existe déjà.
          }
        }
      }

      if (_logMeal) {
        await _mealLogService.addMealLog(
          MealLogDraft(
            recipeId: recipeIdForLog,
            label: name,
            mealType: _mealType,
            eatenAt: _eatenAt,
            portionGrams: portion,
            kcal: num.tryParse(_kcalCtrl.text) ?? 0,
            proteinG: num.tryParse(_proteinCtrl.text) ?? 0,
            carbsG: num.tryParse(_carbsCtrl.text) ?? 0,
            fatG: num.tryParse(_fatCtrl.text) ?? 0,
          ),
          photoUrl: _uploadedPhotoUrl,
          source: _uploadedPhotoUrl != null ? 'photo' : (recipeIdForLog != null ? 'recipe' : 'manual'),
          ownerUid: widget.ownerUid,
          ownerName: widget.ownerName,
          householdId: widget.householdId,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _saveError = "L'enregistrement a échoué, réessaie.";
        _saving = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context, initialDate: _eatenAt, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_eatenAt));
    if (!mounted) return;
    setState(() => _eatenAt = DateTime(date.year, date.month, date.day, time?.hour ?? _eatenAt.hour, time?.minute ?? _eatenAt.minute));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_stage == _Stage.source ? 'Nouveau repas' : 'Vérifier et enregistrer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _stage == _Stage.source ? _buildSource() : _buildReview(),
        ),
      ),
    );
  }

  Widget _buildSource() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: _sourceTab('Photo', _SourceMode.photo)),
          const SizedBox(width: 8),
          Expanded(child: _sourceTab('Texte ou lien', _SourceMode.text)),
          const SizedBox(width: 8),
          Expanded(child: _sourceTab('Manuel', _SourceMode.manual)),
        ]),
        const SizedBox(height: 16),
        if (_sourceMode == _SourceMode.photo) _buildPhotoSource(),
        if (_sourceMode == _SourceMode.text) _buildTextSource(),
        if (_sourceMode == _SourceMode.manual)
          ElevatedButton(onPressed: _startManual, child: const Text('Remplir manuellement')),
      ],
    );
  }

  Widget _sourceTab(String label, _SourceMode mode) {
    final active = _sourceMode == mode;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? AppColors.accent.withValues(alpha: 0.1) : null,
        side: BorderSide(color: active ? AppColors.accent : AppColors.line),
      ),
      onPressed: () => setState(() => _sourceMode = mode),
      child: Text(label, style: TextStyle(color: active ? AppColors.accent : AppColors.inkSoft, fontSize: 12.5)),
    );
  }

  Widget _buildPhotoSource() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          if (_photoFile != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(_photoFile!.path), width: 56, height: 56, fit: BoxFit.cover)),
            ),
          Expanded(
            child: OutlinedButton(onPressed: _pickPhoto, child: Text(_photoFile != null ? 'Changer la photo' : 'Prendre / choisir une photo')),
          ),
        ]),
        if (_photoFile != null) ...[
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _analyzing ? null : _analyzePhoto,
            icon: _analyzing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(_analyzing ? 'Analyse…' : 'Analyser (Gemini)'),
          ),
        ],
        if (_photoError != null) ...[
          const SizedBox(height: 8),
          Text(_photoError!, style: const TextStyle(color: AppColors.accent, fontSize: 12.5)),
        ],
        const SizedBox(height: 8),
        const Text(
          "L'IA propose un titre, une portion et des calories à partir de la photo — tu vérifies et corriges à l'étape suivante.",
          style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _startManual, child: const Text('Passer, remplir à la main')),
        ),
      ],
    );
  }

  Widget _buildTextSource() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Ta recette, en texte libre'),
        TextField(
          controller: _textCtrl,
          maxLines: 5,
          decoration: const InputDecoration(hintText: "Colle ou tape ce que tu as — l'IA range tout. Même juste un nom de plat suffit."),
        ),
        const SizedBox(height: 12),
        const FieldLabel('Nom du plat (si tu veux le préciser)'),
        TextField(controller: _nameCtrl),
        const SizedBox(height: 12),
        const FieldLabel('Lien source (optionnel)'),
        TextField(controller: _linkCtrl, keyboardType: TextInputType.url),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _aiBusy ? null : _generateWithAi,
          icon: _aiBusy
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_awesome, size: 16),
          label: Text(_aiBusy ? 'DeepSeek réfléchit…' : "Générer avec l'IA (DeepSeek)"),
        ),
        if (_aiError != null) ...[
          const SizedBox(height: 8),
          Text(_aiError!, style: const TextStyle(color: AppColors.accent, fontSize: 12.5)),
        ],
      ],
    );
  }

  Widget _buildReview() {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_matchedRecipe != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Reconnu comme '),
                    TextSpan(text: _matchedRecipe!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const TextSpan(text: ', déjà dans ta bibliothèque.'),
                  ])),
                  TextButton(onPressed: () => setState(() => _matchedRecipeId = null), child: const Text("Ce n'est pas la bonne recette")),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _logMeal,
                  onChanged: (v) => setState(() => _logMeal = v ?? false),
                  title: const Text('Repas mangé (compte dans le journal du jour)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ),
                if (widget.initialRecipe == null && _matchedRecipeId == null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _addToLibrary,
                    onChanged: (v) => setState(() => _addToLibrary = v ?? false),
                    title: const Text('Ajouter à ma bibliothèque de recettes', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          if (_addToLibrary && _matchedRecipeId == null)
            RecipeCoreFields(draft: _draft, onChanged: () => setState(() {}))
          else ...[
            const FieldLabel('Nom du repas'),
            TextField(controller: _labelCtrl, onChanged: (v) => _draft.name = v),
            if (_matchedRecipeId == null) ...[
              const SizedBox(height: 14),
              NutritionFields(draft: _draft, onChanged: () => setState(() {})),
            ],
          ],
          if (_logMeal) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CE QUE TU AS VRAIMENT MANGÉ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                  const SizedBox(height: 10),
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
                          child: Text('${_eatenAt.day}/${_eatenAt.month} ${_eatenAt.hour.toString().padLeft(2, '0')}:${_eatenAt.minute.toString().padLeft(2, '0')}'),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _numField('Portion (g)', _portionCtrl, onChanged: _applyPortion),
                    _numField('Kcal', _kcalCtrl),
                    _numField('Protéines (g)', _proteinCtrl),
                    _numField('Glucides (g)', _carbsCtrl),
                    _numField('Lipides (g)', _fatCtrl),
                  ]),
                ],
              ),
            ),
          ],
          if (_saveError != null) ...[
            const SizedBox(height: 12),
            Text(_saveError!, style: const TextStyle(color: AppColors.accent)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Enregistrement…' : 'Enregistrer')),
        ],
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl, {void Function(String)? onChanged}) {
    return SizedBox(
      width: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          TextField(controller: ctrl, keyboardType: TextInputType.number, onChanged: onChanged),
        ],
      ),
    );
  }
}
