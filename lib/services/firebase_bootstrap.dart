import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  /// Returns true when Firebase is configured and initialised.
  /// The app keeps working in guest/offline mode when this is false.
  static Future<bool> init() async {
    if (!AppConfig.isFirebaseConfigured) return false;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Firebase AI Logic requires App Check. Side-loaded APKs can't pass
      // Play Integrity, so they use a debug token registered in the console.
      final token = AppConfig.appCheckDebugToken;
      await FirebaseAppCheck.instance.activate(
        providerAndroid: token.isEmpty
            ? const AndroidPlayIntegrityProvider()
            : AndroidDebugProvider(debugToken: token),
      );
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      return true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
      return false;
    }
  }
}
