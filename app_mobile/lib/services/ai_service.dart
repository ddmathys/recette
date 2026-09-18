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

  Future<AiResult> generate({String? name, String? text, String? link}) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/parse-recipe'),
          headers: await _authHeaders(),
          body: jsonEncode({'name': name ?? '', 'text': text ?? '', 'link': link ?? ''}),
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

  /// AI-assisted edit of an existing recipe: `instruction` is a free-text
  /// change request ("remplace le poulet par du tofu"). Mirrors
  /// EditRecipeDialog.tsx on the web.
  Future<RecipeDraft> edit(RecipeDraft current, String instruction) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/edit-recipe'),
          headers: await _authHeaders(),
          body: jsonEncode({'recipe': current.toMap(), 'instruction': instruction}),
        )
        .timeout(const Duration(seconds: 35));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error']?.toString() ?? 'La modification IA a échoué.');
    }
    return _draftFromJson(Map<String, dynamic>.from(body['draft'] as Map), fallback: current);
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
      steps: (d['steps'] is List && (d['steps'] as List).isNotEmpty)
          ? (d['steps'] as List).map((e) => e.toString()).toList()
          : (fallback?.steps ?? ['']),
    );
  }
}

class AiResult {
  final RecipeDraft draft;
  final String? ogImage;
  AiResult({required this.draft, this.ogImage});
}
