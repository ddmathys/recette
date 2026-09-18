import 'package:shared_preferences/shared_preferences.dart';

/// Per-device favorites, not shared between family members — mirrors
/// ../../src/lib/useFavorites.ts (localStorage there, SharedPreferences here).
class FavoritesService {
  static const _key = 'tiroir-favs';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).toSet();
  }

  Future<void> save(Set<String> favs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, favs.toList());
  }
}
