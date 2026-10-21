import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/currency.dart';
import '../core/utils/period.dart';
import '../data/db/app_database.dart';
import '../data/models/models.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/parser/ai_parser.dart';
import '../services/parser/entry_parser.dart';
import '../services/sync_service.dart';

// ---------------------------------------------------------------------------
// Bootstrapped in main() via overrides.

final prefsProvider =
    Provider<SharedPreferences>((_) => throw UnimplementedError('prefs'));
final databaseProvider =
    Provider<AppDatabase>((_) => throw UnimplementedError('database'));
final firebaseReadyProvider = Provider<bool>((_) => false);

// ---------------------------------------------------------------------------
// Repositories & services

final categoryRepoProvider =
    Provider((ref) => CategoryRepository(ref.watch(databaseProvider)));
final walletRepoProvider =
    Provider((ref) => WalletRepository(ref.watch(databaseProvider)));
final txnRepoProvider =
    Provider((ref) => TransactionRepository(ref.watch(databaseProvider)));
final chatRepoProvider =
    Provider((ref) => ChatRepository(ref.watch(databaseProvider)));
final keywordRepoProvider =
    Provider((ref) => KeywordRuleRepository(ref.watch(databaseProvider)));

final connectivityProvider = Provider((_) => ConnectivityService());

final entryParserProvider = Provider((ref) => EntryParser(
      ai: ref.watch(firebaseReadyProvider) ? AiParser() : null,
    ));

final appLockServiceProvider = Provider((_) => AppLockService());

/// Whether the phone can do the fingerprint lock (it needs some screen lock).
final appLockAvailableProvider = FutureProvider<bool>(
    (ref) => ref.watch(appLockServiceProvider).isAvailable());

final authServiceProvider = Provider(
    (ref) => AuthService(firebaseReady: ref.watch(firebaseReadyProvider)));

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    db: ref.watch(databaseProvider),
    prefs: ref.watch(prefsProvider),
    connectivity: ref.watch(connectivityProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final sync = ref.watch(syncServiceProvider);
  yield sync.status;
  yield* sync.statusStream;
});

// ---------------------------------------------------------------------------
// Settings

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.currency,
    required this.aiEnabled,
    required this.defaultWalletId,
    required this.appLock,
    required this.hideBalance,
  });

  final ThemeMode themeMode;
  final Currency currency;
  final bool aiEnabled;
  final String defaultWalletId;
  final bool appLock;
  final bool hideBalance;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Currency? currency,
    bool? aiEnabled,
    String? defaultWalletId,
    bool? appLock,
    bool? hideBalance,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        currency: currency ?? this.currency,
        aiEnabled: aiEnabled ?? this.aiEnabled,
        defaultWalletId: defaultWalletId ?? this.defaultWalletId,
        appLock: appLock ?? this.appLock,
        hideBalance: hideBalance ?? this.hideBalance,
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  AppSettings build() {
    final p = ref.watch(prefsProvider);
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == p.getString('theme_mode'),
        orElse: () => ThemeMode.system,
      ),
      currency: Currency.byCode(p.getString('currency')),
      aiEnabled: p.getBool('ai_enabled') ?? true,
      defaultWalletId: p.getString('default_wallet') ?? kCashWalletId,
      appLock: p.getBool('app_lock') ?? false,
      hideBalance: p.getBool('hide_balance') ?? false,
    );
  }

  void setThemeMode(ThemeMode mode) {
    _prefs.setString('theme_mode', mode.name);
    state = state.copyWith(themeMode: mode);
  }

  void setCurrency(Currency c) {
    _prefs.setString('currency', c.code);
    state = state.copyWith(currency: c);
  }

  void setAiEnabled(bool v) {
    _prefs.setBool('ai_enabled', v);
    state = state.copyWith(aiEnabled: v);
  }

  void setDefaultWallet(String id) {
    _prefs.setString('default_wallet', id);
    state = state.copyWith(defaultWalletId: id);
  }

  void setAppLock(bool v) {
    _prefs.setBool('app_lock', v);
    state = state.copyWith(appLock: v);
  }

  void setHideBalance(bool v) {
    _prefs.setBool('hide_balance', v);
    state = state.copyWith(hideBalance: v);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

final currencyProvider = Provider((ref) => ref.watch(settingsProvider).currency);

/// False until the fingerprint check passes; resets only when the app
/// process restarts, so the lock is asked for once per app open.
class AppUnlockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;
}

final appUnlockedProvider =
    NotifierProvider<AppUnlockedNotifier, bool>(AppUnlockedNotifier.new);

// ---------------------------------------------------------------------------
// Auth

enum AuthMode { none, guest, google }

class AuthState {
  const AuthState({
    this.mode = AuthMode.none,
    this.uid,
    this.name,
    this.email,
    this.photoUrl,
  });

  factory AuthState.fromUser(User u) => AuthState(
        mode: AuthMode.google,
        uid: u.uid,
        name: u.displayName,
        email: u.email,
        photoUrl: u.photoURL,
      );

  final AuthMode mode;
  final String? uid;
  final String? name;
  final String? email;
  final String? photoUrl;

  bool get isGoogle => mode == AuthMode.google;
  bool get isGuest => mode == AuthMode.guest;

  String? get firstName {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    return n.split(RegExp(r'\s+')).first;
  }
}

class AuthController extends Notifier<AuthState> {
  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  AuthState build() {
    final mode = ref.read(prefsProvider).getString('auth_mode');
    if (mode == 'google') {
      final user = ref.read(authServiceProvider).currentUser;
      return user == null ? const AuthState() : AuthState.fromUser(user);
    }
    if (mode == 'guest') return const AuthState(mode: AuthMode.guest);
    return const AuthState();
  }

  Future<void> continueAsGuest() async {
    await _prefs.setString('auth_mode', 'guest');
    state = const AuthState(mode: AuthMode.guest);
  }

  /// Returns false if the user cancelled. Data already on this device
  /// (guest entries) is merged into the Google account.
  Future<bool> signInWithGoogle() async {
    final user = await ref.read(authServiceProvider).signInWithGoogle();
    if (user == null) return false;
    await ref.read(databaseProvider).markAllDirty();
    await _prefs.setString('auth_mode', 'google');
    state = AuthState.fromUser(user);
    return true;
  }

  /// Signs out and removes this account's data from the device
  /// (it stays safe in the cloud).
  Future<void> signOut() async {
    final uid = state.uid;
    final sync = ref.read(syncServiceProvider);
    sync.stop();
    await ref.read(authServiceProvider).signOut();
    if (uid != null) await sync.forget(uid);
    await ref.read(databaseProvider).reset();
    await _prefs.remove('auth_mode');
    state = const AuthState();
  }

  /// Guest only: erase everything on this device.
  Future<void> eraseGuestData() async {
    await ref.read(databaseProvider).reset();
    await _prefs.remove('auth_mode');
    state = const AuthState();
  }
}

final authProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Starts/stops cloud sync as the signed-in account changes.
final syncBootstrapProvider = Provider<void>((ref) {
  final auth = ref.watch(authProvider);
  final sync = ref.watch(syncServiceProvider);
  if (auth.isGoogle && auth.uid != null) {
    sync.start(auth.uid!);
  } else {
    sync.stop();
  }
});

// ---------------------------------------------------------------------------
// Reference data

final categoriesProvider = StreamProvider<List<Category>>(
    (ref) => ref.watch(categoryRepoProvider).watchAll());

final categoryMapProvider = Provider<Map<String, Category>>((ref) => {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    });

final walletsProvider =
    StreamProvider<List<Wallet>>((ref) => ref.watch(walletRepoProvider).watchAll());

final walletMapProvider = Provider<Map<String, Wallet>>((ref) => {
      for (final w in ref.watch(walletsProvider).value ?? const <Wallet>[])
        w.id: w,
    });

final walletBalancesProvider = StreamProvider<Map<String, double>>(
    (ref) => ref.watch(walletRepoProvider).watchBalances());

final totalBalanceProvider = Provider<double?>((ref) {
  final balances = ref.watch(walletBalancesProvider).value;
  if (balances == null) return null;
  return balances.values.fold<double>(0, (a, b) => a + b);
});

/// The default wallet, falling back to the first one if it was deleted.
final defaultWalletIdProvider = Provider<String>((ref) {
  final id = ref.watch(settingsProvider).defaultWalletId;
  final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
  if (wallets.isEmpty || wallets.any((w) => w.id == id)) return id;
  return wallets.first.id;
});

/// Resolves a (possibly deleted) category id to something displayable.
Category resolveCategory(
    Map<String, Category> map, String? id, TxnType type) {
  final c = map[id];
  if (c != null) return c;
  final fallbackId = type == TxnType.income ? kOtherIncomeId : kOtherExpenseId;
  return map[fallbackId] ??
      Category(
        id: fallbackId,
        name: type == TxnType.income ? 'Other Income' : 'Other',
        type: type,
        icon: 'more',
        color: 0xFF94A3B8,
      );
}

// ---------------------------------------------------------------------------
// Period-based stats (dashboard & transactions share one period)

class PeriodNotifier extends Notifier<Period> {
  @override
  Period build() => Period.thisMonth();

  void set(Period p) => state = p;
  void shift(int delta) => state = state.shift(delta);
}

final periodProvider = NotifierProvider<PeriodNotifier, Period>(PeriodNotifier.new);

final periodTotalsProvider = StreamProvider<Totals>((ref) => ref
    .watch(txnRepoProvider)
    .watchTotals(ref.watch(periodProvider).span));

final categoryTotalsProvider =
    StreamProvider.family<List<CategoryTotal>, TxnType>((ref, type) => ref
        .watch(txnRepoProvider)
        .watchCategoryTotals(ref.watch(periodProvider).span, type));

final periodPointsProvider = StreamProvider<List<AmountPoint>>((ref) => ref
    .watch(txnRepoProvider)
    .watchPoints(ref.watch(periodProvider).span));

final periodTxnsProvider = StreamProvider<List<Txn>>((ref) => ref
    .watch(txnRepoProvider)
    .watchInSpan(ref.watch(periodProvider).span));

final recentTxnsProvider =
    StreamProvider<List<Txn>>((ref) => ref.watch(txnRepoProvider).watchRecent(5));

/// Expense per category for the month containing [month].
final monthSpendingProvider =
    StreamProvider.family<Map<String, double>, DateTime>((ref, month) => ref
        .watch(txnRepoProvider)
        .watchSpentByCategory(Period.of(PeriodKind.month, anchor: month).span));

// ---------------------------------------------------------------------------
// Chat

final chatMessagesProvider = StreamProvider<List<ChatMessage>>(
    (ref) => ref.watch(chatRepoProvider).watchAll());

/// Entries referenced by one bot message, keyed by id (comma-joined ids).
final chatTxnsProvider =
    StreamProvider.autoDispose.family<Map<String, Txn>, String>((ref, ids) =>
        ref.watch(txnRepoProvider).watchByIds(ids.split(',')));

class BusyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
}

final chatBusyProvider = NotifierProvider<BusyNotifier, bool>(BusyNotifier.new);
