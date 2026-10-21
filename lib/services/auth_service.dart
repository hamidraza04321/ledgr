import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/config/app_config.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({required this.firebaseReady});

  final bool firebaseReady;
  Future<void>? _gsiInit;

  User? get currentUser =>
      firebaseReady ? FirebaseAuth.instance.currentUser : null;

  Future<void> _ensureGoogleSignIn() => _gsiInit ??= GoogleSignIn.instance
      .initialize(
        serverClientId:
            AppConfig.webClientId.isEmpty ? null : AppConfig.webClientId,
      )
      .catchError((Object e) {
        _gsiInit = null;
        throw e;
      });

  /// Returns null when the user closes the account picker.
  Future<User?> signInWithGoogle() async {
    if (!firebaseReady) {
      throw const AuthException(
        'Google sign-in is not set up yet. Add your Firebase config '
        '(see SETUP.md), or continue as guest for now.',
      );
    }
    try {
      await _ensureGoogleSignIn();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthException(
            'Google did not return an ID token. Check the Web client ID.');
      }
      final result = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return result.user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw AuthException(switch (e.code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is misconfigured. Check the SHA-1 fingerprint and '
              'Web client ID in Firebase (see SETUP.md).',
        GoogleSignInExceptionCode.uiUnavailable =>
          'Google sign-in is not available on this device.',
        _ => e.description ?? 'Google sign-in failed.',
      });
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Sign-in failed (${e.code}).');
    }
  }

  Future<void> signOut() async {
    try {
      await _ensureGoogleSignIn();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    if (firebaseReady) await FirebaseAuth.instance.signOut();
  }
}
