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
import '../meal_types.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/edit_meal_log_sheet.dart';
import '../widgets/estimate_day_sheet.dart';
import '../widgets/evolution_card.dart';
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
  // Jour affiché au dashboard : tous les ajouts vont sur ce jour-là.
  int _dayOffset = 0;
  final _addedIds = ValueNotifier<Set<String>>({});

  DateTime get _selectedDay => DateTime.now().add(Duration(days: _dayOffset));

  void _refreshAdded() {
    final day = _selectedDay;
    final ids = <String>{};
    for (final l in _mealLogs) {
      final d = DateTime.tryParse(l.eatenAt)?.toLocal();
      if (l.recipeId != null && d != null && isSameDay(d, day)) ids.add(l.recipeId!);
    }
    _addedIds.value = ids;
  }

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
      _mealLogsSub = _mealLogService.streamMealLogs(householdId).listen((l) {
        // Journal personnel : dans un foyer partagé, seulement ses repas.
        setState(() => _mealLogs = l.where((m) => m.ownerId == _uid).toList());
        _refreshAdded();
      });
    });
  }

  @override
  void dispose() {
    _householdSub?.cancel();
    _recipesSub?.cancel();
    _mealLogsSub?.cancel();
    _recipes.dispose();
    _favs.dispose();
    _addedIds.dispose();
    super.dispose();
  }

  num get _goal => (_profile?.dailyKcalGoal != null && _profile!.dailyKcalGoal! > 0) ? _profile!.dailyKcalGoal! : 2000;

  void _openAddMeal({String? preset}) {
    final profile = _profile;
    if (profile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMealScreen(
          recipes: _recipes.value,
          ownerUid: _uid,
          ownerName: profile.displayName,
          householdId: profile.householdId,
          day: _selectedDay,
          preset: preset,
          logs: _mealLogs,
        ),
      ),
    );
  }

  /// Note 1 portion d'une recette comme mangée, en un tap, sur le jour affiché.
  Future<void> _quickLog(Recipe r) async {
    final profile = _profile;
    if (profile == null) return;
    final n = r.nutrition;
    if (n == null) {
      // Pas d'estimation : l'écran résultat permet de la compléter.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddMealScreen(
            recipes: _recipes.value,
            initialRecipe: r,
            ownerUid: _uid,
            ownerName: profile.displayName,
            householdId: profile.householdId,
            day: _selectedDay,
          ),
        ),
      );
      return;
    }
    final mealType = guessMealType();
    await _mealLogService.addMealLog(
      MealLogDraft(
        recipeId: r.id,
        label: r.name,
        mealType: mealType,
        eatenAt: eatenAtFor(_selectedDay, mealType),
        portionGrams: n.gramsPerServing.round(),
        kcal: n.kcal.round(),
        proteinG: n.proteinG.round(),
        carbsG: n.carbsG.round(),
        fatG: n.fatG.round(),
      ),
      source: 'recipe',
      ownerUid: _uid,
      ownerName: profile.displayName,
      householdId: profile.householdId,
    );
  }

  void _openRecipes() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipesScreen(
          recipes: _recipes,
          favs: _favs,
          onToggleFav: _toggleFav,
          onOpenRecipe: _openRecipe,
          addedIds: _addedIds,
          onQuickAdd: _quickLog,
          dayNote: _dayOffset == 0 ? null : dayLabel(_selectedDay),
        ),
      ),
    );
  }

  void _toggleFav(String id) {
    final next = {..._favs.value};
    if (!next.remove(id)) next.add(id);
    _favs.value = next;
    _favService.save(next);
  }

  void _openRecipe(Recipe r) {
    final profile = _profile;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipe: r,
          isFav: _favs.value.contains(r.id),
          onToggleFav: () => _toggleFav(r.id),
          allRecipes: _recipes.value,
          ownerUid: _uid,
          ownerName: profile?.displayName ?? '',
          householdId: profile?.householdId ?? _uid,
          day: _selectedDay,
        ),
      ),
    );
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
                Image.asset('assets/logo.png', width: 32, height: 32),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Recettes du Tiroir',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.ink),
                  ),
                ),
                if (profile != null)
                  IconButton(
                    tooltip: 'Partage',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ShareScreen(uid: _uid, profile: profile, household: _household),
                      ),
                    ),
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
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              DashboardCard(
                logs: _mealLogs,
                dailyKcalGoal: profile.dailyKcalGoal,
                onSetGoal: (v) => _householdService.setDailyKcalGoal(_uid, v),
                readOnly: false,
                dayOffset: _dayOffset,
                onDayOffset: (o) {
                  setState(() => _dayOffset = o);
                  _refreshAdded();
                },
                onEditLog: (l) => showEditMealLogSheet(context, l),
                onEstimateDay: () => showEstimateDaySheet(
                  context,
                  day: _selectedDay,
                  logs: _mealLogs,
                  goal: _goal,
                  ownerUid: _uid,
                  ownerName: profile.displayName,
                  householdId: profile.householdId,
                ),
                actions: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ActionTile(
                      emoji: '🍽️',
                      title: _dayOffset == 0 ? 'Ajouter un repas' : 'Ajouter un repas · ${dayLabel(_selectedDay).toLowerCase()}',
                      subtitle: 'Photo, description ou recette',
                      primary: true,
                      onTap: _openAddMeal,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            emoji: '☕',
                            title: 'Ajouter un petit-déj',
                            subtitle: 'Tes habituels en 1 tap',
                            color: AppColors.accent2.withValues(alpha: 0.12),
                            onTap: () => _openAddMeal(preset: 'breakfast'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            emoji: '🍎',
                            title: 'Ajouter un en-cas',
                            subtitle: 'Goûter, grignotage',
                            color: AppColors.gold.withValues(alpha: 0.15),
                            onTap: () => _openAddMeal(preset: 'snack'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder(
                      valueListenable: _recipes,
                      builder: (_, recipes, _) => _ActionTile(
                        emoji: '📖',
                        title: 'Mes recettes',
                        subtitle: '${recipes.length} recette${recipes.length > 1 ? "s" : ""}',
                        onTap: _openRecipes,
                      ),
                    ),
                  ],
                ),
              ),
            if (profile != null && _mealLogs.isNotEmpty) EvolutionCard(logs: _mealLogs, goal: _goal),
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
  final Color? color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? (primary ? AppColors.accent : AppColors.surface2),
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
              Text(
                title,
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: primary ? Colors.white : AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: primary ? Colors.white70 : AppColors.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}
