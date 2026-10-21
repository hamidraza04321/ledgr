import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';
import 'features/lock/lock_screen.dart';
import 'providers/providers.dart';

class LedgrApp extends ConsumerWidget {
  const LedgrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncBootstrapProvider);
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final signedOut = ref.watch(authProvider.select((a) => a.mode)) == AuthMode.none;
    final locked = ref.watch(settingsProvider.select((s) => s.appLock)) &&
        !ref.watch(appUnlockedProvider);

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: context.palette.card,
            systemNavigationBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
          ),
          child: child!,
        );
      },
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: signedOut
            ? const LoginScreen(key: ValueKey('login'))
            : locked
                ? const LockScreen(key: ValueKey('lock'))
                : const HomeShell(key: ValueKey('home')),
      ),
    );
  }
}
