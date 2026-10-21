import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../services/sync_service.dart';
import '../../widgets/common.dart';
import '../../widgets/period_selector.dart';
import '../../widgets/txn_tile.dart';
import '../home/home_shell.dart';
import '../wallets/wallets_screen.dart';
import 'category_breakdown.dart';
import 'trend_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
          children: const [
            _Header(),
            SizedBox(height: 18),
            Row(children: [PeriodSelector()]),
            SizedBox(height: 14),
            _BalanceCard(),
            SizedBox(height: 14),
            _WalletStrip(),
            SizedBox(height: 20),
            TrendCard(),
            SizedBox(height: 16),
            CategoryBreakdownCard(),
            SizedBox(height: 20),
            _RecentSection(),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: context.text.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                auth.firstName ?? (auth.isGuest ? 'Guest' : 'there'),
                style: context.text.headlineSmall,
              ),
            ],
          ),
        ),
        const SyncBadge(),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => ref.read(homeTabProvider.notifier).go(HomeTab.more),
          child: UserAvatar(name: auth.name, photoUrl: auth.photoUrl),
        ),
      ],
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.name, this.photoUrl, this.radius = 22});

  final String? name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.colors.primary.withValues(alpha: 0.14),
      foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
      onForegroundImageError: photoUrl == null ? null : (_, _) {},
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, color: context.colors.primary)
          : Text(
              initials,
              style: context.text.titleSmall
                  ?.copyWith(color: context.colors.primary),
            ),
    );
  }
}

class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isGoogle) {
      return ActionChip(
        avatar: Icon(Icons.cloud_off_rounded,
            size: 16, color: context.colors.onSurfaceVariant),
        label: const Text('Local'),
        visualDensity: VisualDensity.compact,
        onPressed: () => ref.read(homeTabProvider.notifier).go(HomeTab.more),
      );
    }
    final status = ref.watch(syncStatusProvider).value ?? const SyncStatus();
    final (icon, color, tip) = switch (status.phase) {
      SyncPhase.syncing => (Icons.cloud_sync_rounded, context.colors.primary, 'Syncing…'),
      SyncPhase.offline => (Icons.cloud_off_rounded, context.colors.onSurfaceVariant, 'Offline – changes will sync later'),
      SyncPhase.error => (Icons.sync_problem_rounded, context.palette.warning, 'Sync problem – tap to retry'),
      _ => (Icons.cloud_done_rounded, context.palette.income, 'Synced'),
    };
    return IconButton(
      tooltip: tip,
      onPressed: () => ref.read(syncServiceProvider).syncNow(),
      icon: Icon(icon, color: color),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final balance = ref.watch(totalBalanceProvider);
    final totals = ref.watch(periodTotalsProvider).value;
    final period = ref.watch(periodProvider);
    final palette = context.palette;
    const white = Colors.white;
    final soft = white.withValues(alpha: 0.75);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: palette.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.heroGradient.first.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Current balance',
                  style: context.text.bodyMedium?.copyWith(color: soft)),
              const Spacer(),
              Icon(Icons.account_balance_wallet_rounded, color: soft, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              balance == null ? '—' : currency.format(balance),
              style: context.text.displaySmall?.copyWith(
                color: white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (totals != null) ...[
            const SizedBox(height: 4),
            Text(
              'Net ${period.phrase}: ${currency.signed(totals.net)}',
              style: context.text.bodySmall?.copyWith(color: soft),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _FlowTile(
                  icon: Icons.south_west_rounded,
                  label: 'Income',
                  value: currency.format(totals?.income ?? 0, compact: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FlowTile(
                  icon: Icons.north_east_rounded,
                  label: 'Expense',
                  value: currency.format(totals?.expense ?? 0, compact: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowTile extends StatelessWidget {
  const _FlowTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: context.text.labelSmall
                        ?.copyWith(color: Colors.white.withValues(alpha: 0.75))),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: context.text.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletStrip extends ConsumerWidget {
  const _WalletStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider).value ?? const [];
    final balances = ref.watch(walletBalancesProvider).value ?? const {};
    final currency = ref.watch(currencyProvider);

    void openWallets() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const WalletsScreen()));

    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final w in wallets)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Material(
                color: context.palette.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: context.colors.outlineVariant),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: openWallets,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                    child: Row(
                      children: [
                        IconBadge(
                          icon: walletIcon(w.icon),
                          color: Color(w.color),
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(w.name,
                                style: context.text.labelMedium?.copyWith(
                                    color: context.colors.onSurfaceVariant)),
                            Text(
                              currency.format(balances[w.id] ?? 0),
                              style: context.text.titleSmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Material(
            color: context.colors.primary.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: openWallets,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded,
                        size: 20, color: context.colors.primary),
                    const SizedBox(width: 8),
                    Text('Wallets',
                        style: context.text.labelLarge
                            ?.copyWith(color: context.colors.primary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTxnsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Recent',
          action: recent.isEmpty ? null : 'See all',
          onAction: () =>
              ref.read(homeTabProvider.notifier).go(HomeTab.transactions),
        ),
        AppCard(
          padding: const EdgeInsets.all(6),
          child: recent.isEmpty
              ? const EmptyState(
                  compact: true,
                  icon: Icons.chat_rounded,
                  title: 'No entries yet',
                  message: 'Tap the chat button and type\n"100 ka petrol".',
                )
              : Column(
                  children: [
                    for (final t in recent) TxnTile(t, showDate: true, dense: true),
                  ],
                ),
        ),
      ],
    );
  }
}
