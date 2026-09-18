import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';

/// Firestore + Storage access for the shared recipe library. Mirrors
/// ../../src/lib/useRecipes.ts. Requires a signed-in user — see
/// firestore.rules / storage.rules at the repo root (same project as web).
class RecipeService {
  static const _collection = 'recipes';
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<Recipe>> streamRecipes() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Recipe.fromMap(d.id, d.data())).toList());
  }

  Future<String> addRecipe(RecipeDraft draft, {String? source, String? photoUrl}) async {
    final data = {
      ...draft.toMap(),
      'source': source,
      'photoUrl': photoUrl,
      'notes': '',
      'createdAt': DateTime.now().toIso8601String(),
    };
    final ref = await _db.collection(_collection).add(data);
    return ref.id;
  }

  Future<void> saveNotes(String id, String text) =>
      _db.collection(_collection).doc(id).update({'notes': text});

  Future<void> addEatenDate(String id, String date) =>
      _db.collection(_collection).doc(id).update({
        'eatenDates': FieldValue.arrayUnion([date])
      });

  Future<void> removeEatenDate(String id, String date) =>
      _db.collection(_collection).doc(id).update({
        'eatenDates': FieldValue.arrayRemove([date])
      });

  /// Downscaled at pick time (see add_recipe_screen.dart / image_picker's
  /// maxWidth+imageQuality) — the mobile equivalent of
  /// ../../src/lib/compressImage.ts.
  Future<String> uploadRecipePhoto(String id, XFile file) async {
    final bytes = await file.readAsBytes();
    final ref = _storage.ref('recipes/$id/${DateTime.now().millisecondsSinceEpoch}-${file.name}');
    try {
      await ref.putData(bytes, SettableMetadata(contentType: file.mimeType ?? 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await _db.collection(_collection).doc(id).update({'photoUrl': url});
      return url;
    } on FirebaseException catch (e) {
      throw Exception(_storageErrorMessage(e.code));
    }
  }

  Future<void> deleteRecipe(String id, String? photoUrl) async {
    if (photoUrl != null) {
      try {
        await _storage.refFromURL(photoUrl).delete();
      } catch (_) {
        // Best effort: photo may already be gone, or hosted outside our bucket.
      }
    }
    await _db.collection(_collection).doc(id).delete();
  }

  String _storageErrorMessage(String code) {
    switch (code) {
      case 'unauthorized':
        return "Envoi refusé par les règles de sécurité Storage.";
      case 'canceled':
        return "Envoi annulé.";
      case 'quota-exceeded':
        return "Quota de stockage dépassé.";
      case 'retry-limit-exceeded':
        return "Connexion trop lente ou instable, réessaie.";
      default:
        return "L'envoi de la photo a échoué, réessaie.";
    }
  }
}
