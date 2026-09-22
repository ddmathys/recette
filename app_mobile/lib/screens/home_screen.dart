import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import '../services/household_service.dart';
import '../services/recipe_service.dart';
import '../theme.dart';
import '../widgets/recipe_card.dart';
import 'add_recipe_screen.dart';
import 'nutrition_screen.dart';
import 'recipe_detail_screen.dart';
import 'share_screen.dart';

const _timeBuckets = <(String, String, int?, int?)>[
  ('all', 'Tous', null, null),
  ('15', '≤ 15 min', null, 15),
  ('30', '≤ 30 min', null, 30),
  ('45', '≤ 45 min', null, 45),
  ('60', '≤ 60 min', null, 60),
  ('60+', '60 min +', 61, null),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _recipeService = RecipeService();
  final _favService = FavoritesService();
  final _authService = AuthService();
  final _householdService = HouseholdService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  UserProfile? _profile;
  Household? _household;
  StreamSubscription<Household?>? _householdSub;
  StreamSubscription<List<Recipe>>? _recipesSub;

  List<Recipe> _recipes = [];
  Set<String> _favs = {};
  String _search = '';
  String _cat = 'all';
  String _timeBucket = 'all';
  bool _vegOnly = false;
  bool _favOnly = false;

  @override
  void initState() {
    super.initState();
    _favService.load().then((f) => setState(() => _favs = f));
    _householdService.streamProfile(_uid).listen((profile) {
      setState(() => _profile = profile);
      final householdId = profile?.householdId;
      _householdSub?.cancel();
      _recipesSub?.cancel();
      if (householdId == null) return;
      _householdSub = _householdService.streamHousehold(householdId).listen((h) => setState(() => _household = h));
      _recipesSub = _recipeService.streamRecipes(householdId).listen((r) => setState(() => _recipes = r));
    });
  }

  @override
  void dispose() {
    _householdSub?.cancel();
    _recipesSub?.cancel();
    super.dispose();
  }

  void _toggleFav(String id) {
    setState(() {
      if (_favs.contains(id)) {
        _favs.remove(id);
      } else {
        _favs.add(id);
      }
    });
    _favService.save(_favs);
  }

  List<Recipe> get _filtered {
    final q = _search.trim().toLowerCase();
    final bucket = _timeBuckets.firstWhere((b) => b.$1 == _timeBucket);
    return _recipes.where((r) {
      if (q.isNotEmpty) {
        final inName = r.name.toLowerCase().contains(q);
        final inIngr = r.ingr.any((i) => i.name.toLowerCase().contains(q));
        if (!inName && !inIngr) return false;
      }
      if (_cat != 'all' && r.cat != _cat) return false;
      if (_vegOnly && !r.veg) return false;
      if (_favOnly && !_favs.contains(r.id)) return false;
      if (bucket.$4 != null && r.time > bucket.$4!) return false;
      if (bucket.$3 != null && r.time < bucket.$3!) return false;
      return true;
    }).toList();
  }

  void _surprise() {
    final pool = _filtered.isNotEmpty ? _filtered : _recipes;
    if (pool.isEmpty) return;
    final pick = pool[Random().nextInt(pool.length)];
    _openRecipe(pick);
  }

  void _openRecipe(Recipe r) {
    final profile = _profile;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecipeDetailScreen(
        recipe: r,
        isFav: _favs.contains(r.id),
        onToggleFav: () => _toggleFav(r.id),
        allRecipes: _recipes,
        ownerUid: _uid,
        ownerName: profile?.displayName ?? '',
        householdId: profile?.householdId ?? _uid,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final profile = _profile;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.accent,
                        radius: 14,
                        child: Icon(Icons.kitchen, color: Colors.white, size: 15),
                      ),
                      const SizedBox(width: 8),
                      const Text('Recettes du Tiroir',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.ink)),
                      const SizedBox(width: 8),
                      Text('${_recipes.length} recette${_recipes.length > 1 ? "s" : ""}',
                          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (profile != null)
                        IconButton(
                          tooltip: 'Journal',
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => NutritionScreen(
                                householdId: profile.householdId,
                                ownerUid: _uid,
                                ownerName: profile.displayName,
                                recipes: _recipes,
                              ),
                            ));
                          },
                          icon: const Icon(Icons.menu_book_outlined, size: 20, color: AppColors.inkSoft),
                        ),
                      if (profile != null)
                        IconButton(
                          tooltip: 'Partage',
                          onPressed: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ShareScreen(uid: _uid, profile: profile, household: _household),
                            ));
                          },
                          icon: const Icon(Icons.group_outlined, size: 20, color: AppColors.inkSoft),
                        ),
                      IconButton(
                        tooltip: 'Déconnexion',
                        onPressed: () => _authService.signOut(),
                        icon: const Icon(Icons.logout, size: 20, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
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
                        activeCount: (_cat != 'all' ? 1 : 0) +
                            (_timeBucket != 'all' ? 1 : 0) +
                            (_vegOnly ? 1 : 0) +
                            (_favOnly ? 1 : 0),
                        onTap: _openFilters,
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                        onPressed: profile == null
                            ? null
                            : () async {
                                await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => AddRecipeScreen(
                                    ownerUid: _uid,
                                    ownerName: profile.displayName,
                                    householdId: profile.householdId,
                                  ),
                                ));
                              },
                        icon: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _recipes.isEmpty
                              ? "Aucune recette pour l'instant — ajoute la première !"
                              : "Aucune recette ne correspond à ces filtres.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                      ),
                    )
                  : GridView.builder(
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
                          isFav: _favs.contains(r.id),
                          onOpen: () => _openRecipe(r),
                          onToggleFav: () => _toggleFav(r.id),
                        );
                      },
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
