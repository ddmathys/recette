import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/recipe_card.dart';

const _timeBuckets = <(String, String, int?, int?)>[
  ('all', 'Tous', null, null),
  ('15', '≤ 15 min', null, 15),
  ('30', '≤ 30 min', null, 30),
  ('45', '≤ 45 min', null, 45),
  ('60', '≤ 60 min', null, 60),
  ('60+', '60 min +', 61, null),
];

/// Bibliothèque de recettes (recherche, filtres, grille) — écran séparé de
/// l'accueil, mirrors la vue "Mes recettes" de page.tsx. Les données restent
/// possédées par HomeScreen et arrivent via des ValueListenable pour rester
/// à jour en direct.
class RecipesScreen extends StatefulWidget {
  final ValueListenable<List<Recipe>> recipes;
  final ValueListenable<Set<String>> favs;
  final ValueChanged<String> onToggleFav;
  final ValueChanged<Recipe> onOpenRecipe;

  const RecipesScreen({
    super.key,
    required this.recipes,
    required this.favs,
    required this.onToggleFav,
    required this.onOpenRecipe,
  });

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  String _search = '';
  String _cat = 'all';
  String _timeBucket = 'all';
  bool _vegOnly = false;
  bool _favOnly = false;

  List<Recipe> _filter(List<Recipe> recipes, Set<String> favs) {
    final q = _search.trim().toLowerCase();
    final bucket = _timeBuckets.firstWhere((b) => b.$1 == _timeBucket);
    return recipes.where((r) {
      if (q.isNotEmpty) {
        final inName = r.name.toLowerCase().contains(q);
        final inIngr = r.ingr.any((i) => i.name.toLowerCase().contains(q));
        if (!inName && !inIngr) return false;
      }
      if (_cat != 'all' && r.cat != _cat) return false;
      if (_vegOnly && !r.veg) return false;
      if (_favOnly && !favs.contains(r.id)) return false;
      if (bucket.$4 != null && r.time > bucket.$4!) return false;
      if (bucket.$3 != null && r.time < bucket.$3!) return false;
      return true;
    }).toList();
  }

  void _surprise() {
    final all = widget.recipes.value;
    final filtered = _filter(all, widget.favs.value);
    final pool = filtered.isNotEmpty ? filtered : all;
    if (pool.isEmpty) return;
    widget.onOpenRecipe(pool[Random().nextInt(pool.length)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: widget.recipes,
          builder: (_, recipes, _) => Text('Mes recettes (${recipes.length})'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Chercher une recette, un ingrédient…',
                        prefixIcon: Icon(Icons.search, size: 20, color: AppColors.accent),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterButton(
                    activeCount: (_cat != 'all' ? 1 : 0) + (_timeBucket != 'all' ? 1 : 0) + (_vegOnly ? 1 : 0) + (_favOnly ? 1 : 0),
                    onTap: _openFilters,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: widget.recipes,
                builder: (context, recipes, _) => ValueListenableBuilder(
                  valueListenable: widget.favs,
                  builder: (context, favs, _) {
                    final filtered = _filter(recipes, favs);
                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            recipes.isEmpty
                                ? "Aucune recette pour l'instant — ajoute un repas depuis l'accueil et garde-le !"
                                : 'Aucune recette ne correspond à ces filtres.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final r = filtered[i];
                        return RecipeCard(
                          recipe: r,
                          isFav: favs.contains(r.id),
                          onOpen: () => widget.onOpenRecipe(r),
                          onToggleFav: () => widget.onToggleFav(r.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(builder: (sheetContext, setSheetState) {
          void applyAndRefresh(VoidCallback fn) {
            setState(fn);
            setSheetState(() {});
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filtres', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Végétarien'),
                        selected: _vegOnly,
                        onSelected: (v) => applyAndRefresh(() => _vegOnly = v),
                        selectedColor: AppColors.herb,
                        labelStyle: TextStyle(color: _vegOnly ? Colors.white : AppColors.ink),
                      ),
                      FilterChip(
                        label: const Text('Favoris'),
                        selected: _favOnly,
                        onSelected: (v) => applyAndRefresh(() => _favOnly = v),
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(color: _favOnly ? Colors.white : AppColors.ink),
                      ),
                      ActionChip(
                        label: const Text('🎲 Surprends-moi'),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _surprise();
                        },
                        backgroundColor: AppColors.gold,
                        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('CATÉGORIE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Toutes'),
                        selected: _cat == 'all',
                        onSelected: (_) => applyAndRefresh(() => _cat = 'all'),
                      ),
                      for (final c in kCategories)
                        ChoiceChip(
                          label: Text(c.label),
                          selected: _cat == c.key,
                          selectedColor: c.color,
                          labelStyle: TextStyle(color: _cat == c.key ? Colors.white : AppColors.ink, fontSize: 12.5),
                          onSelected: (_) => applyAndRefresh(() => _cat = c.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('TEMPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in _timeBuckets)
                        ChoiceChip(
                          label: Text(b.$2),
                          selected: _timeBucket == b.$1,
                          onSelected: (_) => applyAndRefresh(() => _timeBucket = b.$1),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;
  const _FilterButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: AppColors.accent2, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            const Icon(Icons.tune, size: 16, color: Colors.white),
            if (activeCount > 0) ...[
              const SizedBox(width: 4),
              CircleAvatar(radius: 8, backgroundColor: Colors.white, child: Text('$activeCount', style: const TextStyle(fontSize: 10, color: AppColors.accent2, fontWeight: FontWeight.bold))),
            ],
          ],
        ),
      ),
    );
  }
}
