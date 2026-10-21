import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

/// Shown on app open while the fingerprint lock is on. Asks right away, and
/// the Unlock button asks again after a cancel or a failed attempt.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final lock = ref.read(appLockServiceProvider);
    // The phone's screen lock was removed: there is nothing to check with,
    // so don't shut the user out of their own data.
    final available = await lock.isAvailable();
    if (!mounted) return;
    if (!available) {
      ref.read(appUnlockedProvider.notifier).unlock();
      return;
    }
    final result = await lock.authenticate('Unlock ${AppConfig.appName}');
    if (!mounted) return;
    if (result.ok) {
      ref.read(appUnlockedProvider.notifier).unlock();
    } else {
      setState(() {
        _busy = false;
        _error = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.heroGradient.first.withValues(alpha: 0.16),
              context.colors.surface,
              context.colors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        colors: palette.heroGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.heroGradient.first.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  '${AppConfig.appName} is locked',
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Use your fingerprint to open the app.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const Spacer(flex: 3),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium
                        ?.copyWith(color: palette.expense),
                  ),
                  const SizedBox(height: 14),
                ],
                FilledButton.icon(
                  onPressed: _busy ? null : _unlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Unlock'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
