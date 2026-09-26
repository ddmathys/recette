import 'package:flutter/material.dart';
import 'theme.dart';

/// Mirrors ../../src/lib/types.ts.
class Ingredient {
  final String name;
  final String qty;
  const Ingredient({required this.name, required this.qty});

  factory Ingredient.fromMap(Map<String, dynamic> m) => Ingredient(name: (m['name'] ?? '').toString(), qty: (m['qty'] ?? '').toString());

  Map<String, dynamic> toMap() => {'name': name, 'qty': qty};
}

/// Per-serving nutrition estimate. Mirrors NutritionEstimate in
/// ../../src/lib/types.ts — computed by DeepSeek at parse/edit time,
/// always editable by hand (`estimatedBy` is purely informational).
class NutritionEstimate {
  final num kcal;
  final num proteinG;
  final num carbsG;
  final num fatG;
  final num gramsPerServing;
  final String estimatedBy; // "ai" | "manual"

  const NutritionEstimate({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.gramsPerServing,
    this.estimatedBy = 'manual',
  });

  Map<String, dynamic> toMap() => {
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'gramsPerServing': gramsPerServing,
    'estimatedBy': estimatedBy,
  };

  /// Validates/coerces a loosely-typed map (AI response or Firestore data)
  /// into a NutritionEstimate, or null if the shape is unusable — mirrors
  /// sanitizeNutrition() in ../../src/lib/nutrition.ts.
  static NutritionEstimate? fromLoose(dynamic m, {String estimatedBy = 'ai'}) {
    if (m == null || m is! Map) return null;
    num? asNum(dynamic v) => v is num ? v : num.tryParse('$v');
    final kcal = asNum(m['kcal']);
    final proteinG = asNum(m['proteinG']);
    final carbsG = asNum(m['carbsG']);
    final fatG = asNum(m['fatG']);
    final gramsPerServing = asNum(m['gramsPerServing']);
    if ([kcal, proteinG, carbsG, fatG, gramsPerServing].any((v) => v == null || v < 0)) return null;
    return NutritionEstimate(
      kcal: kcal!,
      proteinG: proteinG!,
      carbsG: carbsG!,
      fatG: fatG!,
      gramsPerServing: gramsPerServing!,
      estimatedBy: (m['estimatedBy'] ?? estimatedBy).toString(),
    );
  }

  /// Scales this per-serving estimate to an arbitrary portion size in
  /// grams — used when logging a meal with a different portion than the
  /// recipe's own gramsPerServing.
  Map<String, num> scaledTo(num portionGrams) {
    final ratio = gramsPerServing > 0 ? portionGrams / gramsPerServing : 1;
    return {
      'kcal': (kcal * ratio).round(),
      'proteinG': (proteinG * ratio).round(),
      'carbsG': (carbsG * ratio).round(),
      'fatG': (fatG * ratio).round(),
    };
  }
}

class Recipe {
  final String id;
  final String name;
  final String cat;
  final int time;
  final String diff;
  final int servings;
  final bool veg;
  final List<Ingredient> ingr;
  final List<String> steps;
  final String? note;
  final String? source;
  final String? photoUrl;
  final String notes;
  final String? createdAt;
  final List<String> eatenDates;
  final NutritionEstimate? nutrition;

  /// Shared-library scope — see services/household_service.dart. Recipes
  /// are only visible to members of this household.
  final String? householdId;
  final String? ownerId;

  /// Denormalized at write time so the "created by" badge doesn't need a
  /// lookup per recipe.
  final String? ownerName;

  const Recipe({
    required this.id,
    required this.name,
    required this.cat,
    required this.time,
    required this.diff,
    required this.servings,
    required this.veg,
    required this.ingr,
    required this.steps,
    this.note,
    this.source,
    this.photoUrl,
    this.notes = '',
    this.createdAt,
    this.eatenDates = const [],
    this.householdId,
    this.ownerId,
    this.ownerName,
    this.nutrition,
  });

  /// Merges an edited draft's content fields back onto this recipe,
  /// keeping ownership/household/notes/photo/eatenDates/createdAt as-is —
  /// used to refresh the detail screen immediately after a manual/AI edit
  /// without waiting for the next Firestore snapshot.
  Recipe copyWithDraft(RecipeDraft draft) => Recipe(
    id: id,
    name: draft.name,
    cat: draft.cat,
    time: draft.time,
    diff: draft.diff,
    servings: draft.servings,
    veg: draft.veg,
    ingr: draft.ingr,
    steps: draft.steps,
    note: note,
    source: source,
    photoUrl: photoUrl,
    notes: notes,
    createdAt: createdAt,
    eatenDates: eatenDates,
    householdId: householdId,
    ownerId: ownerId,
    ownerName: ownerName,
    nutrition: draft.nutrition,
  );

  Recipe copyWith({String? photoUrl, List<String>? eatenDates}) => Recipe(
    id: id,
    name: name,
    cat: cat,
    time: time,
    diff: diff,
    servings: servings,
    veg: veg,
    ingr: ingr,
    steps: steps,
    note: note,
    source: source,
    photoUrl: photoUrl ?? this.photoUrl,
    notes: notes,
    createdAt: createdAt,
    eatenDates: eatenDates ?? this.eatenDates,
    householdId: householdId,
    ownerId: ownerId,
    ownerName: ownerName,
    nutrition: nutrition,
  );

  factory Recipe.fromMap(String id, Map<String, dynamic> m) => Recipe(
    id: id,
    name: (m['name'] ?? '').toString(),
    cat: (m['cat'] ?? '').toString(),
    time: (m['time'] is num) ? (m['time'] as num).toInt() : 0,
    diff: (m['diff'] ?? 'Facile').toString(),
    servings: (m['servings'] is num) ? (m['servings'] as num).toInt() : 1,
    veg: m['veg'] == true,
    ingr: ((m['ingr'] as List?) ?? []).map((e) => Ingredient.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
    steps: ((m['steps'] as List?) ?? []).map((e) => e.toString()).toList(),
    note: m['note']?.toString(),
    source: m['source']?.toString(),
    photoUrl: m['photoUrl']?.toString(),
    notes: (m['notes'] ?? '').toString(),
    createdAt: m['createdAt']?.toString(),
    eatenDates: ((m['eatenDates'] as List?) ?? []).map((e) => e.toString()).toList(),
    householdId: m['householdId']?.toString(),
    ownerId: m['ownerId']?.toString(),
    ownerName: m['ownerName']?.toString(),
    nutrition: NutritionEstimate.fromLoose(m['nutrition']),
  );
}

/// users/{uid} — one per account. householdId points at the shared pool
/// this account currently sees (its own uid by default, or another
/// member's uid once "sharing" is activated).
class UserProfile {
  final String email;
  final String displayName;
  final String householdId;
  final num? dailyKcalGoal;
  const UserProfile({required this.email, required this.displayName, required this.householdId, this.dailyKcalGoal});

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    email: (m['email'] ?? '').toString(),
    displayName: (m['displayName'] ?? '').toString(),
    householdId: (m['householdId'] ?? '').toString(),
    dailyKcalGoal: m['dailyKcalGoal'] as num?,
  );
}

/// households/{ownerId} — one per household, keyed by its creator's uid.
class Household {
  final String ownerId;
  final String ownerEmail;
  final List<String> members;
  const Household({required this.ownerId, required this.ownerEmail, required this.members});

  factory Household.fromMap(Map<String, dynamic> m) => Household(
    ownerId: (m['ownerId'] ?? '').toString(),
    ownerEmail: (m['ownerEmail'] ?? '').toString(),
    members: ((m['members'] as List?) ?? []).map((e) => e.toString()).toList(),
  );
}

/// A recipe not yet saved (draft form / AI generation result). Mirrors
/// RecipeDraft in ../../src/lib/types.ts.
class RecipeDraft {
  String name;
  String cat;
  int time;
  String diff;
  int servings;
  bool veg;
  List<Ingredient> ingr;
  List<String> steps;
  NutritionEstimate? nutrition;

  RecipeDraft({
    this.name = '',
    this.cat = 'viande',
    this.time = 30,
    this.diff = 'Facile',
    this.servings = 4,
    this.veg = false,
    List<Ingredient>? ingr,
    List<String>? steps,
    this.nutrition,
  }) : ingr = ingr ?? [const Ingredient(name: '', qty: '')],
       steps = steps ?? [''];

  Map<String, dynamic> toMap() => {
    'name': name,
    'cat': cat,
    'time': time,
    'diff': diff,
    'servings': servings,
    'veg': veg,
    'ingr': ingr.map((e) => e.toMap()).toList(),
    'steps': steps,
    if (nutrition != null) 'nutrition': nutrition!.toMap(),
  };
}

/// mealLogs/{id} — a logged meal, independent of Recipe.eatenDates (which
/// is just a per-recipe checked-date list with no quantity/macros). Mirrors
/// MealLog in ../../src/lib/types.ts.
class MealLog {
  final String id;
  final String householdId;
  final String ownerId;
  final String ownerName;
  final String? recipeId;
  final String label;
  final String mealType; // "petit-dej" | "dejeuner" | "diner" | "collation"
  final String eatenAt; // ISO datetime
  final num portionGrams;
  final num kcal;
  final num proteinG;
  final num carbsG;
  final num fatG;
  final String? photoUrl;
  final String source; // "photo" | "recipe" | "manual" | "estimate"
  final String createdAt;

  /// Nombre d'unités (ex. 3 biscuits), valeurs déjà multipliées. null = 1.
  final num? count;

  const MealLog({
    required this.id,
    required this.householdId,
    required this.ownerId,
    required this.ownerName,
    this.recipeId,
    required this.label,
    required this.mealType,
    required this.eatenAt,
    required this.portionGrams,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.photoUrl,
    required this.source,
    required this.createdAt,
    this.count,
  });

  factory MealLog.fromMap(String id, Map<String, dynamic> m) => MealLog(
    id: id,
    householdId: (m['householdId'] ?? '').toString(),
    ownerId: (m['ownerId'] ?? '').toString(),
    ownerName: (m['ownerName'] ?? '').toString(),
    recipeId: m['recipeId']?.toString(),
    label: (m['label'] ?? '').toString(),
    mealType: (m['mealType'] ?? 'dejeuner').toString(),
    eatenAt: (m['eatenAt'] ?? '').toString(),
    portionGrams: (m['portionGrams'] as num?) ?? 0,
    kcal: (m['kcal'] as num?) ?? 0,
    proteinG: (m['proteinG'] as num?) ?? 0,
    carbsG: (m['carbsG'] as num?) ?? 0,
    fatG: (m['fatG'] as num?) ?? 0,
    photoUrl: m['photoUrl']?.toString(),
    source: (m['source'] ?? 'manual').toString(),
    createdAt: (m['createdAt'] ?? '').toString(),
    count: m['count'] as num?,
  );
}

class MealLogDraft {
  String? recipeId;
  String label;
  String mealType;
  DateTime eatenAt;
  num portionGrams;
  num kcal;
  num proteinG;
  num carbsG;
  num fatG;
  num? count;

  MealLogDraft({
    this.count,
    this.recipeId,
    this.label = '',
    required this.mealType,
    required this.eatenAt,
    this.portionGrams = 250,
    this.kcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
  });

  Map<String, dynamic> toMap() => {
    'recipeId': recipeId,
    'label': label,
    'mealType': mealType,
    'eatenAt': eatenAt.toUtc().toIso8601String(),
    'portionGrams': portionGrams,
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'count': ?count,
  };
}

class CategoryMeta {
  final String key;
  final String label;
  final Color color;
  final IconData icon;
  const CategoryMeta({required this.key, required this.label, required this.color, required this.icon});
}

/// Mirrors ../../src/lib/categories.ts. Icons are Material equivalents
/// (Flutter doesn't share the web app's hand-drawn SVG icon set).
const List<CategoryMeta> kCategories = [
  CategoryMeta(key: 'petit-dejeuner', label: 'Petit-déjeuner', color: Color(0xFFFFB020), icon: Icons.free_breakfast),
  CategoryMeta(key: 'apero', label: 'Apéro & snack', color: Color(0xFFFF6F59), icon: Icons.local_bar),
  CategoryMeta(key: 'salade', label: 'Salade', color: Color(0xFF7CB342), icon: Icons.eco),
  CategoryMeta(key: 'soupe', label: 'Soupe', color: Color(0xFFFF8A3D), icon: Icons.ramen_dining),
  CategoryMeta(key: 'pates-riz', label: 'Pâtes & riz', color: Color(0xFFFFC93C), icon: Icons.rice_bowl),
  CategoryMeta(key: 'viande', label: 'Viande', color: Color(0xFFE5484D), icon: Icons.kebab_dining),
  CategoryMeta(key: 'poisson', label: 'Poisson', color: Color(0xFF2EC4B6), icon: Icons.set_meal),
  CategoryMeta(key: 'vegetarien', label: 'Végétarien', color: Color(0xFF00A878), icon: Icons.grass),
  CategoryMeta(key: 'dessert', label: 'Dessert', color: Color(0xFFFF6FA5), icon: Icons.icecream),
  CategoryMeta(key: 'sandwich', label: 'Sandwich & wrap', color: Color(0xFFF5A623), icon: Icons.lunch_dining),
];

const CategoryMeta kDefaultCategory = CategoryMeta(key: 'viande', label: 'Autre', color: AppColors.inkSoft, icon: Icons.restaurant);

CategoryMeta categoryFor(String key) => kCategories.firstWhere((c) => c.key == key, orElse: () => kDefaultCategory);

const List<String> kDifficulties = ['Facile', 'Moyen', 'Avancé'];
