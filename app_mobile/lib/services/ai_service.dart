import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models.dart';

/// Calls the *same* DeepSeek-backed endpoints the web app uses
/// (../../src/app/api/parse-recipe/route.ts, .../api/edit-recipe/route.ts)
/// — one backend, two clients, so the DeepSeek key only ever lives on the
/// Vercel server. Requires the caller to be signed in (routes enforce it —
/// see ../../src/lib/firebaseAdmin.ts).
class AiService {
  static const _baseUrl = 'https://recette-olive.vercel.app';

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Connecte-toi pour utiliser la génération IA.');
    final token = await user.getIdToken();
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  /// `servings` = nombre de personnes choisi avant la recherche : le
  /// serveur calcule toutes les quantités pour ce nombre.
  Future<AiResult> generate({String? name, String? text, String? link, int? servings}) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/parse-recipe'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'name': name ?? '',
            'text': text ?? '',
            'link': link ?? '',
            'servings': ?servings,
          }),
        )
        .timeout(const Duration(seconds: 40));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error']?.toString() ?? 'La génération IA a échoué.');
    }
    return AiResult(
      draft: _draftFromJson(Map<String, dynamic>.from(body['draft'] as Map), fallbackName: name),
      ogImage: body['ogImage']?.toString(),
    );
  }

  /// Estime ce qu'on a mangé à partir d'une description libre ("crêpes et
  /// poulet sauce soja", "une pomme") : 1 personne, pas d'étapes.
  Future<RecipeDraft> describeMeal(String text) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/parse-recipe'),
          headers: await _authHeaders(),
          body: jsonEncode({'text': text, 'kind': 'meal'}),
        )
        .timeout(const Duration(seconds: 40));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error']?.toString() ?? "L'estimation a échoué.");
    }
    final d = _draftFromJson(Map<String, dynamic>.from(body['draft'] as Map), fallbackName: text);
    return d
      ..servings = 1
      ..steps = []
      ..ingr = d.ingr.where((i) => i.name.trim().isNotEmpty).toList();
  }

  /// AI-assisted edit of an existing recipe: `instruction` is a free-text
  /// change request ("remplace le poulet par du tofu"). Mirrors
  /// EditRecipeDialog.tsx on the web.
  /// `meal: true` = assiette photographiée (pas d'étapes, 1 personne).
  Future<RecipeDraft> edit(RecipeDraft current, String instruction, {bool meal = false}) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/edit-recipe'),
          headers: await _authHeaders(),
          body: jsonEncode({'recipe': current.toMap(), 'instruction': instruction, 'kind': meal ? 'meal' : 'recipe'}),
        )
        .timeout(const Duration(seconds: 35));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error']?.toString() ?? 'La modification IA a échoué.');
    }
    return _draftFromJson(Map<String, dynamic>.from(body['draft'] as Map), fallback: current);
  }

  /// Sends an already-uploaded meal photo (Storage download URL) to Gemini
  /// for identification + nutrition estimate. Mirrors LogMealDialog.tsx's
  /// analyzePhoto() on the web. `recipes` is the household's recipe list,
  /// passed as a matching hint.
  Future<MealPhotoAnalysis> analyzeMealPhoto(String photoUrl, List<Recipe> recipes) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/analyze-meal-photo'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'photoUrl': photoUrl,
            'recipes': recipes.map((r) => {'id': r.id, 'name': r.name}).toList(),
          }),
        )
        .timeout(const Duration(seconds: 30));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error']?.toString() ?? 'La reconnaissance photo a échoué.');
    }
    final d = Map<String, dynamic>.from(body['draft'] as Map);
    num? asNum(dynamic v) => v is num ? v : num.tryParse('$v');
    return MealPhotoAnalysis(
      label: d['label']?.toString(),
      portionGrams: asNum(d['portionGrams']),
      kcal: asNum(d['kcal']),
      proteinG: asNum(d['proteinG']),
      carbsG: asNum(d['carbsG']),
      fatG: asNum(d['fatG']),
      mealType: d['mealType']?.toString(),
      matchedRecipeId: d['matchedRecipeId']?.toString(),
      ingr: d['ingr'] is List
          ? (d['ingr'] as List)
              .whereType<Map>()
              .map((e) => Ingredient.fromMap(Map<String, dynamic>.from(e)))
              .where((i) => i.name.trim().isNotEmpty)
              .toList()
          : const [],
      cat: kCategories.any((c) => c.key == d['cat']) ? d['cat'].toString() : null,
      veg: d['veg'] is bool ? d['veg'] as bool : false,
    );
  }

  RecipeDraft _draftFromJson(Map<String, dynamic> d, {String? fallbackName, RecipeDraft? fallback}) {
    final validCat = kCategories.any((c) => c.key == d['cat']) ? d['cat'].toString() : (fallback?.cat ?? 'viande');
    final validDiff = kDifficulties.contains(d['diff']) ? d['diff'].toString() : (fallback?.diff ?? 'Facile');
    return RecipeDraft(
      name: (d['name'] ?? fallbackName ?? fallback?.name ?? '').toString(),
      cat: validCat,
      time: (d['time'] is num) && (d['time'] as num) > 0 ? (d['time'] as num).toInt() : (fallback?.time ?? 30),
      diff: validDiff,
      servings: (d['servings'] is num) && (d['servings'] as num) > 0
          ? (d['servings'] as num).toInt()
          : (fallback?.servings ?? 4),
      veg: d['veg'] is bool ? d['veg'] as bool : (fallback?.veg ?? false),
      ingr: (d['ingr'] is List && (d['ingr'] as List).isNotEmpty)
          ? (d['ingr'] as List).map((e) => Ingredient.fromMap(Map<String, dynamic>.from(e as Map))).toList()
          : (fallback?.ingr ?? [const Ingredient(name: '', qty: '')]),
      steps: d['steps'] is List
          ? (d['steps'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : (fallback?.steps ?? ['']),
      nutrition: NutritionEstimate.fromLoose(d['nutrition']) ?? fallback?.nutrition,
    );
  }
}

class AiResult {
  final RecipeDraft draft;
  final String? ogImage;
  AiResult({required this.draft, this.ogImage});
}

/// Result of a photo analysis — a draft, not yet saved. Any field can be
/// null if Gemini omitted it or returned something unusable; the caller
/// falls back to whatever the form already had.
class MealPhotoAnalysis {
  final String? label;
  final num? portionGrams;
  final num? kcal;
  final num? proteinG;
  final num? carbsG;
  final num? fatG;
  final String? mealType;
  final String? matchedRecipeId;
  final List<Ingredient> ingr;
  final String? cat;
  final bool veg;

  MealPhotoAnalysis({
    this.ingr = const [],
    this.cat,
    this.veg = false,
    this.label,
    this.portionGrams,
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.mealType,
    this.matchedRecipeId,
  });
}
