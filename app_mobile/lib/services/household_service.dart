import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

/// Mirrors ../../src/lib/useHousehold.ts — see that file for the data
/// model (users/{uid}, households/{ownerId}) and the sharing flow.
class HouseholdService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _nameFromEmail(String email) {
    final local = email.split('@')[0];
    if (local.isEmpty) return 'Moi';
    return local[0].toUpperCase() + local.substring(1);
  }

  /// Creates users/{uid} and households/{uid} the first time an account is
  /// seen, if they don't already exist. Safe to call on every sign-in.
  Future<void> ensureUserProfile(User user, {String? displayName}) async {
    final userRef = _db.collection('users').doc(user.uid);
    final snap = await userRef.get();
    if (!snap.exists) {
      final name = (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : _nameFromEmail(user.email ?? '');
      await userRef.set({
        'email': (user.email ?? '').toLowerCase(),
        'displayName': name,
        'householdId': user.uid,
      });
    }
    final householdRef = _db.collection('households').doc(user.uid);
    final householdSnap = await householdRef.get();
    if (!householdSnap.exists) {
      await householdRef.set({
        'ownerId': user.uid,
        'ownerEmail': (user.email ?? '').toLowerCase(),
        'members': [user.uid],
      });
    }
  }

  Stream<UserProfile?> streamProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
          (snap) => snap.exists ? UserProfile.fromMap(snap.data()!) : null,
        );
  }

  Stream<Household?> streamHousehold(String householdId) {
    return _db.collection('households').doc(householdId).snapshots().map(
          (snap) => snap.exists ? Household.fromMap(snap.data()!) : null,
        );
  }

  Future<void> joinHousehold(String myUid, String targetEmail) async {
    final q = await _db
        .collection('users')
        .where('email', isEqualTo: targetEmail.trim().toLowerCase())
        .limit(1)
        .get();
    if (q.docs.isEmpty) throw Exception('Aucun compte trouvé avec cet e-mail.');
    final targetUid = q.docs.first.id;
    if (targetUid == myUid) throw Exception("C'est déjà ta bibliothèque.");

    await _db.collection('households').doc(targetUid).update({
      'members': FieldValue.arrayUnion([myUid]),
    });
    await _db.collection('users').doc(myUid).update({'householdId': targetUid});
  }

  Future<void> leaveHousehold(String myUid, String currentHouseholdId) async {
    if (currentHouseholdId != myUid) {
      try {
        await _db.collection('households').doc(currentHouseholdId).update({
          'members': FieldValue.arrayRemove([myUid]),
        });
      } catch (_) {
        // Best effort: if we've lost access to update it (e.g. the owner
        // already removed us), still restore our own householdId below.
      }
    }
    await _db.collection('users').doc(myUid).update({'householdId': myUid});
  }
}
