import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Fingerprint check for the app lock. The phone's PIN/pattern/password is
/// allowed as a fallback, so a bad sensor never locks the user out.
class AppLockService {
  AppLockService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// False when the phone has no screen lock at all (nothing to check with).
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('App lock unavailable: $e');
      return false;
    }
  }

  /// `ok` is true once the user is verified. `message` explains a failure;
  /// it is null when the user simply closed the prompt.
  Future<({bool ok, String? message})> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // If a call comes in mid-prompt, ask again once the app is back.
        persistAcrossBackgrounding: true,
      );
      return (ok: ok, message: null);
    } on LocalAuthException catch (e) {
      final message = switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.authInProgress ||
        LocalAuthExceptionCode.timeout =>
          null,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          'Too many attempts. Wait a moment, or use your phone PIN.',
        LocalAuthExceptionCode.noCredentialsSet =>
          'Set up a fingerprint or screen lock in your phone settings first.',
        _ => 'Could not verify: ${e.description ?? e.code.name}',
      };
      return (ok: false, message: message);
    } catch (e) {
      return (ok: false, message: 'Could not verify: $e');
    }
  }
}
