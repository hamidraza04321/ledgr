import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/dates.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/common.dart';
import '../../widgets/google_button.dart';
import '../categories/categories_screen.dart';
import '../chat/chat_controller.dart';
import '../dashboard/dashboard_screen.dart' show UserAvatar;
import '../export/export_sheet.dart';
import '../home/home_shell.dart';
import '../wallets/wallets_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final firebaseReady = ref.watch(firebaseReadyProvider);
    final auth = ref.watch(authProvider);
    final wallets = ref.watch(walletMapProvider);
    final defaultWallet = wallets[ref.watch(defaultWalletIdProvider)];

    void push(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const _AccountCard(),
          const SizedBox(height: 22),
          const _Group('Appearance'),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_rounded),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => notifier.setThemeMode(s.first),
            ),
          ),
          const SizedBox(height: 22),
          const _Group('Preferences'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _Tile(
                  icon: Icons.currency_exchange_rounded,
                  title: 'Currency',
                  value: '${settings.currency.code} (${settings.currency.symbol})',
                  onTap: () => _pickCurrency(context, ref),
                ),
                _Tile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Default wallet',
                  value: defaultWallet?.name ?? '—',
                  onTap: () => _pickDefaultWallet(context, ref),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.auto_awesome_rounded),
                  title: const Text('Gemini assist in chat'),
                  subtitle: Text(
                    firebaseReady
                        ? 'When online, AI helps with messages the offline parser is unsure about'
                        : 'Available after Firebase is set up (see SETUP.md)',
                  ),
                  value: firebaseReady && settings.aiEnabled,
                  onChanged: firebaseReady ? notifier.setAiEnabled : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _Group('Manage'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _Tile(
                  icon: Icons.category_rounded,
                  title: 'Categories',
                  onTap: () => push(const CategoriesScreen()),
                ),
                _Tile(
                  icon: Icons.account_balance_rounded,
                  title: 'Wallets',
                  onTap: () => push(const WalletsScreen()),
                ),
                _Tile(
                  icon: Icons.savings_rounded,
                  title: 'Budgets',
                  onTap: () =>
                      ref.read(homeTabProvider.notifier).go(HomeTab.budgets),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _Group('Data'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _Tile(
                  icon: Icons.ios_share_rounded,
                  title: 'Export report',
                  value: 'PDF / CSV',
                  onTap: () => showExportSheet(context),
                ),
                _Tile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Clear chat history',
                  onTap: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'Clear chat history?',
                      message: 'Your entries stay saved.',
                      confirm: 'Clear',
                    );
                    if (ok) await ref.read(chatControllerProvider).clear();
                    if (ok && context.mounted) showSnack(context, 'Chat cleared');
                  },
                ),
                if (auth.isGuest)
                  _Tile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Erase all data',
                    destructive: true,
                    onTap: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'Erase everything?',
                        message:
                            'All entries, categories and wallets on this device '
                            'will be deleted. This cannot be undone.',
                        confirm: 'Erase',
                      );
                      if (ok) {
                        await ref.read(authProvider.notifier).eraseGuestData();
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              '${AppConfig.appName} 1.0.0 · ${AppConfig.tagline}',
              style: context.text.labelSmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final current = ref.read(currencyProvider);
    final picked = await showModalBottomSheet<Currency>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text('Currency', style: ctx.text.titleLarge),
            ),
            for (final c in Currency.all)
              ListTile(
                leading: SizedBox(
                  width: 40,
                  child: Center(
                    child: Text(c.symbol, style: ctx.text.titleMedium),
                  ),
                ),
                title: Text(c.name),
                subtitle: Text(c.code),
                trailing: c.code == current.code
                    ? Icon(Icons.check_circle_rounded, color: ctx.colors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) ref.read(settingsProvider.notifier).setCurrency(picked);
  }

  Future<void> _pickDefaultWallet(BuildContext context, WidgetRef ref) async {
    final wallets = ref.read(walletsProvider).value ?? const [];
    final current = ref.read(defaultWalletIdProvider);
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Default wallet', style: ctx.text.titleLarge),
            ),
            for (final w in wallets)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(w.name),
                trailing: w.id == current
                    ? Icon(Icons.check_circle_rounded, color: ctx.colors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, w.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref.read(settingsProvider.notifier).setDefaultWallet(picked);
    }
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.palette.expense : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(value!,
                style: context.text.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              color: context.colors.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _AccountCard extends ConsumerStatefulWidget {
  const _AccountCard();

  @override
  ConsumerState<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<_AccountCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return auth.isGoogle ? _signedIn(auth) : _guest();
  }

  Widget _guest() {
    final firebaseReady = ref.watch(firebaseReadyProvider);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.cloud_off_rounded,
                color: context.palette.warning,
                size: 46,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Guest mode', style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Saved only on this device',
                      style: context.text.bodySmall
                          ?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Sign in with Google to back up your entries and use them on any '
            'device. Everything you added as a guest moves to your account.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: 16),
          GoogleButton(
            label: 'Sign in with Google',
            loading: _busy,
            onPressed: _signIn,
          ),
          if (!firebaseReady) ...[
            const SizedBox(height: 10),
            Text(
              'Cloud sync is not configured in this build yet (see SETUP.md).',
              textAlign: TextAlign.center,
              style: context.text.labelSmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _signedIn(AuthState auth) {
    final status = ref.watch(syncStatusProvider).value ?? const SyncStatus();
    final (icon, color, text) = switch (status.phase) {
      SyncPhase.syncing => (Icons.cloud_sync_rounded, context.colors.primary, 'Syncing…'),
      SyncPhase.offline => (
          Icons.cloud_off_rounded,
          context.colors.onSurfaceVariant,
          status.pending > 0
              ? 'Offline · ${status.pending} change${status.pending == 1 ? '' : 's'} waiting'
              : 'Offline · all changes saved on device'
        ),
      SyncPhase.error => (Icons.sync_problem_rounded, context.palette.warning, 'Sync problem · tap Sync now'),
      _ => (
          Icons.cloud_done_rounded,
          context.palette.income,
          status.lastSyncedAt == null
              ? 'Ready to sync'
              : 'Synced ${DateLabels.ago(status.lastSyncedAt!)}'
        ),
    };

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(name: auth.name, photoUrl: auth.photoUrl, radius: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.name ?? 'Google account',
                        style: context.text.titleMedium),
                    if (auth.email != null)
                      Text(
                        auth.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: context.text.bodyMedium)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: status.phase == SyncPhase.syncing
                      ? null
                      : () => ref.read(syncServiceProvider).syncNow(),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Sync now'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _signOut,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: context.palette.expense),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      final ok = await ref.read(authProvider.notifier).signInWithGoogle();
      if (ok && mounted) showSnack(context, 'Signed in. Syncing your data…');
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (e) {
      if (mounted) showSnack(context, 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    final db = ref.read(databaseProvider);
    final sync = ref.read(syncServiceProvider);
    if (await ref.read(connectivityProvider).isOnline()) {
      await sync.syncNow();
    }
    final pending = await db.pendingCount();
    if (!mounted) return;
    setState(() => _busy = false);

    final ok = await confirmDialog(
      context,
      title: 'Sign out?',
      message: pending > 0
          ? '$pending change${pending == 1 ? '' : 's'} have not synced yet and '
              'will be lost. Connect to the internet first to keep them.'
          : 'Your data is safe in your Google account. It will be removed from '
              'this device until you sign in again.',
      confirm: 'Sign out',
    );
    if (!ok) return;
    await ref.read(authProvider.notifier).signOut();
  }
}
