import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';

/// Firestore + Storage access for the food journal. Mirrors
/// ../../src/lib/useMealLogs.ts.
class MealLogService {
  static const _collection = 'mealLogs';
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<MealLog>> streamMealLogs(String householdId) {
    return _db
        .collection(_collection)
        .where('householdId', isEqualTo: householdId)
        .orderBy('eatenAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MealLog.fromMap(d.id, d.data())).toList());
  }

  Future<String> addMealLog(
    MealLogDraft draft, {
    String? photoUrl,
    required String source,
    required String ownerUid,
    required String ownerName,
    required String householdId,
  }) async {
    final data = {
      ...draft.toMap(),
      'photoUrl': photoUrl,
      'source': source,
      'createdAt': DateTime.now().toIso8601String(),
      'householdId': householdId,
      'ownerId': ownerUid,
      'ownerName': ownerName,
    };
    final ref = await _db.collection(_collection).add(data);
    return ref.id;
  }

  Future<void> deleteMealLog(String id, String? photoUrl) async {
    if (photoUrl != null) {
      try {
        await _storage.refFromURL(photoUrl).delete();
      } catch (_) {
        // Best effort: photo may already be gone.
      }
    }
    await _db.collection(_collection).doc(id).delete();
  }

  Future<String> uploadMealPhoto(String uid, XFile file) async {
    final bytes = await file.readAsBytes();
    final ref = _storage.ref('mealPhotos/$uid/${DateTime.now().millisecondsSinceEpoch}-${file.name}');
    await ref.putData(bytes, SettableMetadata(contentType: file.mimeType ?? 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
