import '../../firebase_options.dart';
import 'app_check_token.dart';
import 'google_web_client.dart';

class AppConfig {
  AppConfig._();

  static const appName = 'Ledgr';
  static const tagline = 'Track every rupee, just by chatting.';

  /// Gemini model used by Firebase AI Logic for chat parsing.
  /// Flash-Lite is fast, cheap and works on the free Spark plan.
  static const aiModel = 'gemini-3.5-flash-lite';

  static String get webClientId => googleWebClientId;

  /// Empty → Play Integrity (Play Store builds); set → debug provider.
  static String get appCheckDebugToken => appCheckToken;

  /// True once `lib/firebase_options.dart` holds a real project config.
  static bool get isFirebaseConfigured {
    try {
      final key = DefaultFirebaseOptions.currentPlatform.apiKey;
      return key.isNotEmpty && !key.startsWith('REPLACE');
    } catch (_) {
      return false;
    }
  }
}
