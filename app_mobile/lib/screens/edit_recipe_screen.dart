import 'package:flutter/material.dart';

import '../models.dart';
import '../services/ai_service.dart';
import '../services/recipe_service.dart';
import '../theme.dart';
import '../widgets/recipe_form_fields.dart';

RecipeDraft _draftFromRecipe(Recipe r) => RecipeDraft(
      name: r.name,
      cat: r.cat,
      time: r.time,
      diff: r.diff,
      servings: r.servings,
      veg: r.veg,
      ingr: r.ingr.isNotEmpty ? [...r.ingr] : null,
      steps: r.steps.isNotEmpty ? [...r.steps] : null,
    );

/// Edit an existing recipe: manually, or via a free-text AI instruction
/// ("remplace le poulet par du tofu"). Mirrors EditRecipeDialog.tsx on the
/// web. Pops with the updated Recipe on save, so the caller (detail
/// screen) can refresh in place without waiting for the next snapshot.
class EditRecipeScreen extends StatefulWidget {
  final Recipe recipe;
  const EditRecipeScreen({super.key, required this.recipe});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  final _recipeService = RecipeService();
  final _aiService = AiService();
  late RecipeDraft _draft;
  final _instructionCtrl = TextEditingController();
  bool _aiBusy = false;
  String? _aiError;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _draft = _draftFromRecipe(widget.recipe);
  }

  @override
  void dispose() {
    _instructionCtrl.dispose();
    super.dispose();
  }

  Future<void> _askAi() async {
    if (_instructionCtrl.text.trim().isEmpty) {
      setState(() => _aiError = "Décris la modification à apporter (ex : « remplace le poulet par du tofu »).");
      return;
    }
    setState(() {
      _aiBusy = true;
      _aiError = null;
    });
    try {
      final updated = await _aiService.edit(_draft, _instructionCtrl.text.trim());
      setState(() => _draft = updated);
      _instructionCtrl.clear();
    } catch (e) {
      setState(() => _aiError = e.toString());
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _save() async {
    final name = _draft.name.trim();
    final ingr = _draft.ingr.where((i) => i.name.trim().isNotEmpty).toList();
    final steps = _draft.steps.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (name.isEmpty || ingr.isEmpty || steps.isEmpty) {
      setState(() => _saveError = "Nom, au moins un ingrédient et une étape sont nécessaires.");
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final finalDraft = RecipeDraft(
      name: name,
      cat: _draft.cat,
      time: _draft.time,
      diff: _draft.diff,
      servings: _draft.servings,
      veg: _draft.veg,
      ingr: ingr,
      steps: steps,
    );
    try {
      await _recipeService.updateRecipeContent(widget.recipe.id, finalDraft);
      if (mounted) {
        Navigator.of(context).pop(widget.recipe.copyWithDraft(finalDraft));
      }
    } catch (_) {
      setState(() {
        _saveError = "L'enregistrement a échoué, réessaie.";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Modifier « ${widget.recipe.name} »')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel("Modifier avec l'IA (optionnel)"),
                    TextField(
                      controller: _instructionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'ex : remplace le poulet par du tofu, double les proportions…',
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _aiBusy ? null : _askAi,
                      icon: _aiBusy
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(_aiBusy ? 'DeepSeek réfléchit…' : "Demander à l'IA"),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "L'IA propose une nouvelle version ci-dessous — rien n'est enregistré tant que tu n'as pas cliqué sur « Enregistrer ».",
                      style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                    if (_aiError != null) ...[
                      const SizedBox(height: 8),
                      Text(_aiError!, style: const TextStyle(color: AppColors.accent, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              RecipeCoreFields(draft: _draft, onChanged: () => setState(() {})),
              if (_saveError != null) ...[
                const SizedBox(height: 10),
                Text(_saveError!, style: const TextStyle(color: AppColors.accent)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Enregistrement…' : 'Enregistrer les modifications'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
