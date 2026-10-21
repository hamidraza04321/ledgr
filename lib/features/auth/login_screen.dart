import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/google_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (e) {
      if (mounted) showSnack(context, 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
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
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 48),
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
                                color: palette.heroGradient.first
                                    .withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.chat_rounded,
                              color: Colors.white, size: 42),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        AppConfig.appName,
                        textAlign: TextAlign.center,
                        style: context.text.displaySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppConfig.tagline,
                        textAlign: TextAlign.center,
                        style: context.text.bodyLarge
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 40),
                      const _Feature(
                        icon: Icons.chat_rounded,
                        title: 'Add by chatting',
                        text: '"100 ka petrol" becomes an entry instantly',
                      ),
                      const _Feature(
                        icon: Icons.donut_large_rounded,
                        title: 'See where it goes',
                        text: 'Category charts, budgets and monthly totals',
                      ),
                      const _Feature(
                        icon: Icons.cloud_done_rounded,
                        title: 'Works offline, syncs everywhere',
                        text: 'Sign in with Google to use any device',
                      ),
                      const Spacer(),
                      const SizedBox(height: 32),
                      GoogleButton(loading: _busy, onPressed: _google),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => ref
                                .read(authProvider.notifier)
                                .continueAsGuest(),
                        child: const Text('Continue as guest'),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Guest data stays on this device. You can sign in later '
                        'to back it up.',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          IconBadge(icon: icon, color: context.colors.primary, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
