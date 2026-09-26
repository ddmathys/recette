import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import '../services/household_service.dart';
import '../services/meal_log_service.dart';
import '../services/recipe_service.dart';
import '../theme.dart';
import '../widgets/dashboard_card.dart';
import 'add_meal_screen.dart';
import 'recipe_detail_screen.dart';
import 'recipes_screen.dart';
import 'share_screen.dart';

/// Accueil : état du jour (anneau kcal + macros + repas) et deux grosses
/// actions — "Ajouter un repas" et "Mes recettes". Mirrors la vue "home" de
/// page.tsx. Possède les streams Firestore et les expose aux écrans enfants.
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

  final _mealLogService = MealLogService();
  UserProfile? _profile;
  Household? _household;
  StreamSubscription<Household?>? _householdSub;
  StreamSubscription<List<Recipe>>? _recipesSub;
  StreamSubscription<List<MealLog>>? _mealLogsSub;

  // ValueNotifier pour que RecipesScreen (route séparée) reste à jour.
  final _recipes = ValueNotifier<List<Recipe>>([]);
  final _favs = ValueNotifier<Set<String>>({});
  List<MealLog> _mealLogs = [];

  @override
  void initState() {
    super.initState();
    _favService.load().then((f) => _favs.value = f);
    _householdService.streamProfile(_uid).listen((profile) {
      setState(() => _profile = profile);
      final householdId = profile?.householdId;
      _householdSub?.cancel();
      _recipesSub?.cancel();
      _mealLogsSub?.cancel();
      if (householdId == null) return;
      _householdSub = _householdService.streamHousehold(householdId).listen((h) => setState(() => _household = h));
      _recipesSub = _recipeService.streamRecipes(householdId).listen((r) => _recipes.value = r);
      _mealLogsSub = _mealLogService.streamMealLogs(householdId).listen((l) => setState(() => _mealLogs = l));
    });
  }

  @override
  void dispose() {
    _householdSub?.cancel();
    _recipesSub?.cancel();
    _mealLogsSub?.cancel();
    _recipes.dispose();
    _favs.dispose();
    super.dispose();
  }

  void _openAddMeal() {
    final profile = _profile;
    if (profile == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddMealScreen(
        recipes: _recipes.value,
        ownerUid: _uid,
        ownerName: profile.displayName,
        householdId: profile.householdId,
      ),
    ));
  }

  void _openRecipes() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecipesScreen(
        recipes: _recipes,
        favs: _favs,
        onToggleFav: _toggleFav,
        onOpenRecipe: _openRecipe,
      ),
    ));
  }

  void _toggleFav(String id) {
    final next = {..._favs.value};
    if (!next.remove(id)) next.add(id);
    _favs.value = next;
    _favService.save(next);
  }

  void _openRecipe(Recipe r) {
    final profile = _profile;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecipeDetailScreen(
        recipe: r,
        isFav: _favs.value.contains(r.id),
        onToggleFav: () => _toggleFav(r.id),
        allRecipes: _recipes.value,
        ownerUid: _uid,
        ownerName: profile?.displayName ?? '',
        householdId: profile?.householdId ?? _uid,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.accent,
                  radius: 14,
                  child: Icon(Icons.kitchen, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Recettes du Tiroir', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.ink)),
                ),
                if (profile != null)
                  IconButton(
                    tooltip: 'Partage',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ShareScreen(uid: _uid, profile: profile, household: _household),
                    )),
                    icon: const Icon(Icons.group_outlined, size: 20, color: AppColors.inkSoft),
                  ),
                IconButton(
                  tooltip: 'Déconnexion',
                  onPressed: () => _authService.signOut(),
                  icon: const Icon(Icons.logout, size: 20, color: AppColors.inkSoft),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (profile == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else
              DashboardCard(
                logs: _mealLogs,
                dailyKcalGoal: profile.dailyKcalGoal,
                onSetGoal: (v) => _householdService.setDailyKcalGoal(_uid, v),
                readOnly: false,
                actions: Row(
                  children: [
                    Expanded(
                      child: _ActionTile(
                        emoji: '🍽️',
                        title: 'Ajouter un repas',
                        subtitle: 'Photo ou texte',
                        primary: true,
                        onTap: _openAddMeal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: _recipes,
                        builder: (_, recipes, _) => _ActionTile(
                          emoji: '📖',
                          title: 'Mes recettes',
                          subtitle: '${recipes.length} recette${recipes.length > 1 ? "s" : ""}',
                          onTap: _openRecipes,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;
  const _ActionTile({required this.emoji, required this.title, required this.subtitle, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.accent : AppColors.surface2,
      borderRadius: BorderRadius.circular(18),
      elevation: primary ? 3 : 0,
      shadowColor: AppColors.accent.withValues(alpha: 0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: primary ? Colors.white : AppColors.ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: primary ? Colors.white70 : AppColors.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}
