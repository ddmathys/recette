import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/ai_service.dart';
import '../services/recipe_service.dart';
import '../theme.dart';
import '../widgets/recipe_form_fields.dart';

enum _Stage { intro, form, done }

class AddRecipeScreen extends StatefulWidget {
  final String ownerUid;
  final String ownerName;
  final String householdId;

  const AddRecipeScreen({
    super.key,
    required this.ownerUid,
    required this.ownerName,
    required this.householdId,
  });

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _recipeService = RecipeService();
  final _aiService = AiService();
  _Stage _stage = _Stage.intro;

  final _textCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  bool _aiBusy = false;
  String? _aiError;
  String? _suggestedPhoto;

  RecipeDraft _draft = RecipeDraft();
  XFile? _photoFile;
  bool _saving = false;
  String? _saveError;
  String? _savedName;
  String? _photoWarning;

  @override
  void dispose() {
    _textCtrl.dispose();
    _nameCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateWithAi() async {
    if (_textCtrl.text.trim().isEmpty && _nameCtrl.text.trim().isEmpty && _linkCtrl.text.trim().isEmpty) {
      setState(() => _aiError = "Écris un nom de plat, colle un texte, ou donne un lien avant de générer.");
      return;
    }
    setState(() {
      _aiBusy = true;
      _aiError = null;
    });
    try {
      final result = await _aiService.generate(
        name: _nameCtrl.text.trim(),
        text: _textCtrl.text.trim(),
        link: _linkCtrl.text.trim(),
      );
      setState(() {
        _draft = result.draft;
        _suggestedPhoto = result.ogImage;
        _stage = _Stage.form;
      });
    } catch (e) {
      setState(() => _aiError = e.toString());
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2400, imageQuality: 85);
    if (file != null) setState(() => _photoFile = file);
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

    _draft
      ..name = name
      ..ingr = ingr
      ..steps = steps;

    String id;
    try {
      id = await _recipeService.addRecipe(
        _draft,
        source: _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text.trim(),
        photoUrl: _photoFile == null ? _suggestedPhoto : null,
        ownerUid: widget.ownerUid,
        ownerName: widget.ownerName,
        householdId: widget.householdId,
      );
    } catch (_) {
      setState(() {
        _saveError = "L'enregistrement a échoué, réessaie.";
        _saving = false;
      });
      return;
    }

    // The recipe now exists — a photo failure from here on is a warning,
    // never a reason to retry (that would create a duplicate). Mirrors
    // ../../src/components/AddRecipeDialog.tsx.
    if (_photoFile != null) {
      try {
        await _recipeService.uploadRecipePhoto(id, _photoFile!);
      } catch (_) {
        setState(() {
          _savedName = name;
          _photoWarning = "La recette a bien été enregistrée, mais l'envoi de la photo a échoué. Tu peux la rajouter depuis la fiche de la recette.";
          _stage = _Stage.done;
          _saving = false;
        });
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter une recette')),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.intro => _buildIntro(),
          _Stage.form => _buildForm(),
          _Stage.done => _buildDone(),
        },
      ),
    );
  }

  Widget _buildDone() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(TextSpan(children: [
            const TextSpan(text: ''),
            TextSpan(text: _savedName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: ' a été ajoutée à la bibliothèque.'),
          ])),
          const SizedBox(height: 8),
          Text(_photoWarning ?? '', style: const TextStyle(color: AppColors.gold)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Ta recette, en texte libre'),
          TextField(
            controller: _textCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: "Colle ou tape ce que tu as : nom, ingrédients, étapes — l'IA range tout. Même juste un nom de plat suffit.",
            ),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Nom du plat (si tu veux le préciser)'),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'ex : Tarte aux poireaux')),
          const SizedBox(height: 14),
          const FieldLabel('Lien source (optionnel)'),
          TextField(controller: _linkCtrl, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://...')),
          const SizedBox(height: 8),
          const Text(
            "Si tu donnes un lien, le serveur va essayer de lire la page pour en extraire la recette et une photo.",
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _aiBusy ? null : _generateWithAi,
                icon: _aiBusy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_aiBusy ? 'DeepSeek réfléchit…' : "Générer avec l'IA (DeepSeek)"),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _draft = RecipeDraft(name: _nameCtrl.text.trim());
                  _stage = _Stage.form;
                }),
                child: const Text('Remplir manuellement'),
              ),
            ],
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 10),
            Text(_aiError!, style: const TextStyle(color: AppColors.accent)),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecipeCoreFields(draft: _draft, onChanged: () => setState(() {})),
          const SizedBox(height: 18),
          const FieldLabel('Photo (optionnel)'),
          Row(
            children: [
              if (_photoFile != null || _suggestedPhoto != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _photoFile != null
                        ? Image.file(File(_photoFile!.path), width: 56, height: 56, fit: BoxFit.cover)
                        : Image.network(_suggestedPhoto!, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                ),
              OutlinedButton(onPressed: _pickPhoto, child: const Text('Choisir une photo')),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Sans photo, une icône de catégorie sera utilisée par défaut.', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          if (_saveError != null) ...[
            const SizedBox(height: 10),
            Text(_saveError!, style: const TextStyle(color: AppColors.accent)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Ajout en cours…' : 'Ajouter à la bibliothèque'),
          ),
        ],
      ),
    );
  }
}
