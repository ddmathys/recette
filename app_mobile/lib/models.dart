import 'package:flutter/material.dart';
import 'theme.dart';

/// Mirrors ../../src/lib/types.ts.
class Ingredient {
  final String name;
  final String qty;
  const Ingredient({required this.name, required this.qty});

  factory Ingredient.fromMap(Map<String, dynamic> m) =>
      Ingredient(name: (m['name'] ?? '').toString(), qty: (m['qty'] ?? '').toString());

  Map<String, dynamic> toMap() => {'name': name, 'qty': qty};
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
  });

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
      );

  factory Recipe.fromMap(String id, Map<String, dynamic> m) => Recipe(
        id: id,
        name: (m['name'] ?? '').toString(),
        cat: (m['cat'] ?? '').toString(),
        time: (m['time'] is num) ? (m['time'] as num).toInt() : 0,
        diff: (m['diff'] ?? 'Facile').toString(),
        servings: (m['servings'] is num) ? (m['servings'] as num).toInt() : 1,
        veg: m['veg'] == true,
        ingr: ((m['ingr'] as List?) ?? [])
            .map((e) => Ingredient.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        steps: ((m['steps'] as List?) ?? []).map((e) => e.toString()).toList(),
        note: m['note']?.toString(),
        source: m['source']?.toString(),
        photoUrl: m['photoUrl']?.toString(),
        notes: (m['notes'] ?? '').toString(),
        createdAt: m['createdAt']?.toString(),
        eatenDates: ((m['eatenDates'] as List?) ?? []).map((e) => e.toString()).toList(),
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

  RecipeDraft({
    this.name = '',
    this.cat = 'viande',
    this.time = 30,
    this.diff = 'Facile',
    this.servings = 4,
    this.veg = false,
    List<Ingredient>? ingr,
    List<String>? steps,
  })  : ingr = ingr ?? [const Ingredient(name: '', qty: '')],
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

const CategoryMeta kDefaultCategory =
    CategoryMeta(key: 'viande', label: 'Autre', color: AppColors.inkSoft, icon: Icons.restaurant);

CategoryMeta categoryFor(String key) =>
    kCategories.firstWhere((c) => c.key == key, orElse: () => kDefaultCategory);

const List<String> kDifficulties = ['Facile', 'Moyen', 'Avancé'];
