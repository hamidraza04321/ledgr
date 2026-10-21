import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../budgets/budgets_screen.dart';
import '../chat/chat_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';

enum HomeTab { home, transactions, budgets, more }

class HomeTabNotifier extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.home;

  void go(HomeTab tab) => state = tab;
}

final homeTabProvider =
    NotifierProvider<HomeTabNotifier, HomeTab>(HomeTabNotifier.new);

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _pages = [
    DashboardScreen(),
    TransactionsScreen(),
    BudgetsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeTabProvider);

    return PopScope(
      canPop: tab == HomeTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(homeTabProvider.notifier).go(HomeTab.home);
      },
      child: Scaffold(
        body: IndexedStack(index: tab.index, children: _pages),
        floatingActionButton: tab == HomeTab.more
            ? null
            : FloatingActionButton(
                heroTag: 'chat-fab',
                tooltip: 'Quick add by chat',
                onPressed: () => openChat(context),
                child: const Icon(Icons.chat_rounded),
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab.index,
          onDestinationSelected: (i) =>
              ref.read(homeTabProvider.notifier).go(HomeTab.values[i]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Entries',
            ),
            NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings_rounded),
              label: 'Budgets',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

void openChat(BuildContext context) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => const ChatScreen(),
    transitionsBuilder: (_, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  ));
}
