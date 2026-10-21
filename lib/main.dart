import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'providers/providers.dart';
import 'services/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final (prefs, db, firebaseReady) = await (
      SharedPreferences.getInstance(),
      AppDatabase.open(),
      // Cloud features are optional; never let them block startup.
      FirebaseBootstrap.init()
          .timeout(const Duration(seconds: 10), onTimeout: () => false),
    ).wait;

    runApp(ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
      child: const LedgrApp(),
    ));
  } catch (e, st) {
    // Show the problem instead of a blank white screen.
    debugPrint('Ledgr failed to start: $e\n$st');
    final error = e is ParallelWaitError ? e.errors : e;
    runApp(_StartupError(message: '$error'));
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: Color(0xFFE5484D)),
                const SizedBox(height: 16),
                const Text(
                  'Ledgr could not start',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please send a screenshot of this screen to the developer.',
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      message,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
