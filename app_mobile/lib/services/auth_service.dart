import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around FirebaseAuth — mirrors ../../src/lib/useAuth.ts.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _message(String code) {
    switch (code) {
      case 'email-already-in-use':
        return "Un compte existe déjà avec cet e-mail — connecte-toi plutôt.";
      case 'invalid-email':
        return "Adresse e-mail invalide.";
      case 'weak-password':
        return "Mot de passe trop court (6 caractères minimum).";
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return "E-mail ou mot de passe incorrect.";
      case 'too-many-requests':
        return "Trop de tentatives, réessaie dans un instant.";
      default:
        return "Une erreur est survenue, réessaie.";
    }
  }
}

class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);
  @override
  String toString() => message;
}
