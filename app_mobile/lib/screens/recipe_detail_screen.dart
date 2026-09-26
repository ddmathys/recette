import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/recipe_service.dart';
import '../theme.dart';
import 'add_meal_screen.dart';
import 'edit_recipe_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final bool isFav;
  final VoidCallback onToggleFav;
  final List<Recipe> allRecipes;
  final String ownerUid;
  final String ownerName;
  final String householdId;
  /// Jour affiché au dashboard : "Manger ce repas" le note ce jour-là.
  final DateTime day;

  const RecipeDetailScreen({
    required this.day,
    super.key,
    required this.recipe,
    required this.isFav,
    required this.onToggleFav,
    required this.allRecipes,
    required this.ownerUid,
    required this.ownerName,
    required this.householdId,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _service = RecipeService();
  late Recipe _recipe;
  late bool _isFav;
  late final TextEditingController _notesCtrl;
  Timer? _notesDebounce;
  bool _photoBusy = false;
  String? _photoError;
  bool _confirmDelete = false;
  bool _deleting = false;
  DateTime _newDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _isFav = widget.isFav;
    _notesCtrl = TextEditingController(text: _recipe.notes);
  }

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onNotesChanged(String v) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 900), () {
      _service.saveNotes(_recipe.id, v);
    });
  }

  Future<void> _addDate() async {
    final iso = _newDate.toIso8601String().substring(0, 10);
    await _service.addEatenDate(_recipe.id, iso);
    setState(() => _recipe = _recipe.copyWith(eatenDates: [..._recipe.eatenDates, iso]));
  }

  Future<void> _removeDate(String date) async {
    await _service.removeEatenDate(_recipe.id, date);
    setState(() => _recipe = _recipe.copyWith(eatenDates: _recipe.eatenDates.where((d) => d != date).toList()));
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2400, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    try {
      final url = await _service.uploadRecipePhoto(_recipe.id, file);
      setState(() => _recipe = _recipe.copyWith(photoUrl: url));
    } catch (e) {
      setState(() => _photoError = e.toString());
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _delete() async {
    if (!_confirmDelete) {
      setState(() => _confirmDelete = true);
      return;
    }
    setState(() => _deleting = true);
    try {
      await _service.deleteRecipe(_recipe.id, _recipe.photoUrl);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _deleting = false;
        _confirmDelete = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = categoryFor(_recipe.cat);
    final sortedDates = [..._recipe.eatenDates]..sort((a, b) => b.compareTo(a));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            backgroundColor: cat.color,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                onPressed: () {
                  widget.onToggleFav();
                  setState(() => _isFav = !_isFav);
                },
                icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(_recipe.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                  if (_recipe.ownerName != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(999)),
                      child: Text(_recipe.ownerName!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
              background: _recipe.photoUrl != null
                  ? Image.network(_recipe.photoUrl!, fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(color: cat.color))
                  : Container(color: cat.color, child: Center(child: Icon(cat.icon, size: 48, color: Colors.white70))),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _photoBusy ? null : _pickPhoto,
                      icon: _photoBusy
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.photo_camera, size: 16),
                      label: Text(_recipe.photoUrl != null ? 'Changer la photo' : 'Ajouter une photo'),
                    ),
                  ],
                ),
                if (_photoError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_photoError!, style: const TextStyle(color: AppColors.accent, fontSize: 12.5)),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _Badge(value: '${_recipe.time} min', label: 'Préparation'),
                          const SizedBox(width: 22),
                          _Badge(value: '${_recipe.servings}', label: 'Personnes'),
                          const SizedBox(width: 22),
                          _Badge(value: _recipe.diff, label: 'Difficulté'),
                          if (_recipe.nutrition != null) ...[
                            const SizedBox(width: 22),
                            _Badge(value: '${_recipe.nutrition!.kcal} kcal', label: 'Par portion'),
                          ],
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final updated = await Navigator.of(context).push<Recipe>(
                          MaterialPageRoute(builder: (_) => EditRecipeScreen(recipe: _recipe)),
                        );
                        if (updated != null) setState(() => _recipe = updated);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Modifier'),
                    ),
                  ],
                ),
                if (_recipe.nutrition != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Badge(value: '${_recipe.nutrition!.gramsPerServing} g', label: 'Poids'),
                        _Badge(value: '${_recipe.nutrition!.proteinG} g', label: 'Protéines'),
                        _Badge(value: '${_recipe.nutrition!.carbsG} g', label: 'Glucides'),
                        _Badge(value: '${_recipe.nutrition!.fatG} g', label: 'Lipides'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AddMealScreen(
                        recipes: widget.allRecipes,
                        initialRecipe: _recipe,
                        ownerUid: widget.ownerUid,
                        ownerName: widget.ownerName,
                        householdId: widget.householdId,
                        day: widget.day,
                      ),
                    ));
                  },
                  icon: const Icon(Icons.restaurant, size: 16),
                  label: const Text('Manger ce repas'),
                ),
                if (_recipe.note != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(_recipe.note!, style: const TextStyle(color: AppColors.gold, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 22),
                const _SectionLabel('Mangé le…'),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _newDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) setState(() => _newDate = picked);
                      },
                      child: Text('${_newDate.day}/${_newDate.month}/${_newDate.year}'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _addDate,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (sortedDates.isEmpty)
                  const Text('Pas encore de date enregistrée.', style: TextStyle(color: AppColors.inkSoft, fontSize: 13))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in sortedDates)
                        Chip(
                          label: Text(d),
                          onDeleted: () => _removeDate(d),
                          backgroundColor: AppColors.surface2,
                        ),
                    ],
                  ),
                const SizedBox(height: 22),
                const _SectionLabel('Ingrédients'),
                for (final i in _recipe.ingr)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(i.name)),
                        Text(i.qty, style: const TextStyle(fontFamily: 'monospace', color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
                const _SectionLabel('Préparation'),
                for (var idx = 0; idx < _recipe.steps.length; idx++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 11, backgroundColor: AppColors.surface2, child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: AppColors.inkSoft))),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_recipe.steps[idx], style: const TextStyle(height: 1.4))),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
                const _SectionLabel('Mes notes'),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  onChanged: _onNotesChanged,
                  decoration: const InputDecoration(hintText: 'ex : mettre moins de sel…'),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: _deleting ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _confirmDelete ? Colors.white : AppColors.inkSoft,
                    backgroundColor: _confirmDelete ? AppColors.accent : null,
                    side: BorderSide(color: _confirmDelete ? AppColors.accent : AppColors.line),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(_deleting ? 'Suppression…' : (_confirmDelete ? 'Confirmer la suppression ?' : 'Supprimer la recette')),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String value;
  final String label;
  const _Badge({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.inkSoft, letterSpacing: .4)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft, letterSpacing: .5)),
    );
  }
}
