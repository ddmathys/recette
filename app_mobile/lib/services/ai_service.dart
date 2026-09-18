import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models.dart';

/// Calls the *same* DeepSeek-backed endpoint the web app uses
/// (../../src/app/api/parse-recipe/route.ts) — one backend, two clients, so
/// the DeepSeek key only ever lives on the Vercel server. Requires the
/// caller to be signed in (route enforces it — see ../../src/lib/firebaseAdmin.ts).
class AiService {
  static const _baseUrl = 'https://recette-olive.vercel.app';

  Future<AiResult> generate({String? name, String? text, String? link}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Connecte-toi pour utiliser la génération IA.');
    final token = await user.getIdToken();

    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/parse-recipe'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'name': name ?? '', 'text': text ?? '', 'link': link ?? ''}),
        )
        .timeout(const Duration(seconds: 40));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error']?.toString() ?? 'La génération IA a échoué.');
    }

    final d = Map<String, dynamic>.from(body['draft'] as Map);
    final validCat = kCategories.any((c) => c.key == d['cat']) ? d['cat'].toString() : 'viande';
    final validDiff = kDifficulties.contains(d['diff']) ? d['diff'].toString() : 'Facile';
    final draft = RecipeDraft(
      name: (d['name'] ?? name ?? '').toString(),
      cat: validCat,
      time: (d['time'] is num) && (d['time'] as num) > 0 ? (d['time'] as num).toInt() : 30,
      diff: validDiff,
      servings: (d['servings'] is num) && (d['servings'] as num) > 0 ? (d['servings'] as num).toInt() : 4,
      veg: d['veg'] == true,
      ingr: (d['ingr'] is List && (d['ingr'] as List).isNotEmpty)
          ? (d['ingr'] as List).map((e) => Ingredient.fromMap(Map<String, dynamic>.from(e as Map))).toList()
          : [const Ingredient(name: '', qty: '')],
      steps: (d['steps'] is List && (d['steps'] as List).isNotEmpty)
          ? (d['steps'] as List).map((e) => e.toString()).toList()
          : [''],
    );
    return AiResult(draft: draft, ogImage: body['ogImage']?.toString());
  }
}

class AiResult {
  final RecipeDraft draft;
  final String? ogImage;
  AiResult({required this.draft, this.ogImage});
}
