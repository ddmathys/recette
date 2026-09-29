import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'household_service.dart';

/// Thin wrapper around FirebaseAuth — mirrors ../../src/lib/useAuth.ts.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HouseholdService _household = HouseholdService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      // Defensive: covers accounts created before profiles/households
      // existed. ensureUserProfile no-ops if both already exist.
      await _household.ensureUserProfile(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  Future<void> signUp(String email, String password, String displayName) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await _household.ensureUserProfile(cred.user!, displayName: displayName);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  /// Client OAuth "web" du projet Firebase : Google l'exige comme audience
  /// de l'ID token pour que Firebase Auth l'accepte.
  static const _googleServerClientId =
      '744435253449-on7l2im0c3va6sf9ivf537ej4pg98uce.apps.googleusercontent.com';
  static Future<void>? _googleInit;

  /// Connexion Google. Même adresse qu'un compte e-mail existant → même uid
  /// (Firebase fusionne sur l'e-mail), donc on garde ses recettes.
  /// Retourne false si l'utilisateur a annulé.
  Future<bool> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    try {
      await (_googleInit ??= google.initialize(serverClientId: _googleServerClientId));
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw AuthFailure("Google n'a pas renvoyé d'identifiant, réessaie.");
      final cred = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      final firstName = cred.user?.displayName?.split(' ').first;
      await _household.ensureUserProfile(cred.user!, displayName: firstName);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw AuthFailure("Connexion Google impossible (${e.code.name}).");
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.setLanguageCode('fr');
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    // Sans ça, le prochain "Continuer avec Google" reprend le même compte
    // sans proposer d'en choisir un autre.
    try {
      await (_googleInit ??= GoogleSignIn.instance.initialize(serverClientId: _googleServerClientId));
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

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
      case 'network-request-failed':
        return "Pas de connexion internet, réessaie.";
      default:
        return "Une erreur est survenue, réessaie. ($code)";
    }
  }
}

class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);
  @override
  String toString() => message;
}
