// Smoke-tests every main screen against a real (in-memory) database.
//
// To also write PNG screenshots to test/goldens/:
//   flutter test test/screens_test.dart --dart-define=SCREENSHOTS=true --update-goldens
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/app.dart';
import 'package:ledgr/data/db/app_database.dart';
import 'package:ledgr/data/models/models.dart';
import 'package:ledgr/data/repositories/category_repository.dart';
import 'package:ledgr/data/repositories/transaction_repository.dart';
import 'package:ledgr/data/repositories/wallet_repository.dart';
import 'package:ledgr/features/settings/settings_screen.dart';
import 'package:ledgr/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _capture = bool.fromEnvironment('SCREENSHOTS');

Future<void> _loadFonts() async {
  // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<platform>/.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final dir = Directory('${artifacts.path}/material_fonts');
  if (!dir.existsSync()) return;
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('${dir.path}/$name').readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final f in [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    roboto.addFont(read(f));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('materialicons-regular.otf')))
      .load();
}

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.now();
  DateTime day(int d, [int h = 12]) =>
      DateTime(now.year, now.month, math.min(d, now.day), h);

  final wallets = WalletRepository(db);
  for (final w in await wallets.getAll()) {
    await wallets.save(w.copyWith(
        openingBalance: w.id == kCashWalletId ? 35000 : 40000));
  }
  final cats = CategoryRepository(db);
  await cats.setBudget('exp_food', 8000);
  await cats.setBudget('exp_fuel', 6000);
  await cats.setBudget('exp_grocery', 15000);

  var n = 0;
  Txn t(TxnType type, double amount, String cat, String note, DateTime date,
          {String wallet = kCashWalletId}) =>
      Txn(
        id: 'seed_${n++}',
        type: type,
        amount: amount,
        categoryId: cat,
        walletId: wallet,
        note: note,
        date: date,
      );
  const e = TxnType.expense, i = TxnType.income;
  await TransactionRepository(db).addAll([
    t(i, 85000, 'inc_salary', 'Salary', day(1, 10), wallet: 'wallet_bank'),
    t(i, 18000, 'inc_freelance', 'Upwork project', day(9), wallet: 'wallet_bank'),
    t(e, 3500, 'exp_fuel', 'Petrol', day(2)),
    t(e, 2500, 'exp_fuel', 'Petrol', day(10)),
    t(e, 9200, 'exp_grocery', 'Monthly ration', day(3)),
    t(e, 1450, 'exp_grocery', 'Doodh', day(12)),
    t(e, 2200, 'exp_food', 'Biryani', day(5, 20)),
    t(e, 1800, 'exp_food', 'Pizza', day(14, 21)),
    t(e, 4500, 'exp_bills', 'Bijli bill', day(7), wallet: 'wallet_bank'),
    t(e, 2999, 'exp_bills', 'Internet', day(8), wallet: 'wallet_bank'),
    t(e, 6500, 'exp_shopping', 'Shoes', day(11)),
    t(e, 1200, 'exp_health', 'Dawai', day(13)),
    t(e, 850, 'exp_transport', 'Careem', day(15)),
    t(e, 25000, 'exp_rent', 'Ghar ka kiraya', day(1, 11), wallet: 'wallet_bank'),
  ]);
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() async {
    sqfliteFfiInit();
    await _loadFonts();
  });
  Future<void> boot(Map<String, Object> prefValues, {bool seed = true}) async {
    SharedPreferences.setMockInitialValues(prefValues);
    prefs = await SharedPreferences.getInstance();
    db = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    );
    if (seed) await _seed(db);
  }

  tearDown(() async => db.close());

  /// [navBar] is the height of Android's system navigation bar in dp
  /// (48 for the 3-button bar), which the app draws behind edge-to-edge.
  Future<void> pumpApp(WidgetTester tester,
      {double height = 852, double navBar = 0}) async {
    tester.view.physicalSize = Size(390 * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = FakeViewPadding(bottom: navBar * 3);
    tester.view.viewPadding = FakeViewPadding(bottom: navBar * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
      child: const LedgrApp(),
    ));
    await settle(tester);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (!_capture) return;
    // flutter_test paints shadows as hard outlines; use real ones for the
    // picture, then restore the default the framework checks for.
    // reassemble() waits for a frame, so pump instead of awaiting it.
    debugDisableShadows = false;
    unawaited(tester.binding.reassembleApplication());
    await tester.pump();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    debugDisableShadows = true;
    unawaited(tester.binding.reassembleApplication());
    await tester.pump();
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('dashboard ($mode)', (tester) async {
      await tester.runAsync(() => boot(
          {'auth_mode': 'guest', 'theme_mode': mode}));
      await pumpApp(tester, height: 1900);
      expect(find.text('Current balance'), findsOneWidget);
      expect(find.text('By category'), findsOneWidget);
      await shot(tester, '01_dashboard_$mode');
    });

    testWidgets('chat turns a message into entries ($mode)', (tester) async {
      await tester.runAsync(() => boot(
          {'auth_mode': 'guest', 'theme_mode': mode}));
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Quick add by chat'));
      await settle(tester);
      if (!dark) await shot(tester, '02_chat_empty_$mode');

      await tester.enterText(
          find.byType(TextField), '100 ka petrol\n100 ka biscuit\naj ke din ka');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Salary 5000 bonus mila');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'kal 2k ka khana');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await settle(tester);

      expect(find.text('Added 2 entries'), findsOneWidget);
      expect(find.text('Petrol'), findsOneWidget);
      expect(find.text('Biscuit'), findsOneWidget);
      await shot(tester, '03_chat_$mode');

      final rows = await tester.runAsync(() => db.db.query(Tables.transactions,
          where: "source = 'chat'", orderBy: 'created_at'));
      expect(rows!.length, 4);
    });

    testWidgets('transactions, budgets, more ($mode)', (tester) async {
      await tester.runAsync(() => boot(
          {'auth_mode': 'guest', 'theme_mode': mode}));
      await pumpApp(tester);

      await tester.tap(find.text('Entries'));
      await settle(tester);
      expect(find.text('Careem'), findsOneWidget);
      await shot(tester, '04_entries_$mode');

      await tester.tap(find.byTooltip('Add entry'));
      await settle(tester);
      expect(find.text('New entry'), findsOneWidget);
      await shot(tester, '05_add_entry_$mode');
      Navigator.of(tester.element(find.text('New entry'))).pop();
      await settle(tester);

      await tester.tap(find.text('Budgets'));
      await settle(tester);
      expect(find.text('Your budgets'), findsOneWidget);
      await shot(tester, '06_budgets_$mode');

      await tester.tap(find.text('More'));
      await settle(tester);
      expect(find.text('Guest mode'), findsOneWidget);
      await shot(tester, '07_more_$mode');
    });
  }

  testWidgets('login screen', (tester) async {
    await tester.runAsync(() => boot({}, seed: false));
    await pumpApp(tester);
    expect(find.text('Continue as guest'), findsOneWidget);
    await shot(tester, '00_login_light');

    await tester.tap(find.text('Continue as guest'));
    await settle(tester);
    expect(find.text('Current balance'), findsOneWidget);
  });

  testWidgets('removing a budget closes its dialog', (tester) async {
    await tester.runAsync(() => boot({'auth_mode': 'guest'}));
    await pumpApp(tester);
    await tester.tap(find.text('Budgets'));
    await settle(tester);

    Future<Object?> budgetOf(String id) async {
      final rows = await tester.runAsync(() => db.db.query(Tables.categories,
          columns: ['budget'], where: 'id = ?', whereArgs: [id]));
      return rows!.single['budget'];
    }

    // Remove button.
    await tester.tap(find.text('Fuel'));
    await settle(tester);
    expect(find.text('Fuel budget'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await budgetOf('exp_fuel'), isNull);

    // Saving an empty field removes it too.
    await tester.tap(find.text('Food & Dining'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await budgetOf('exp_food'), isNull);
  });

  testWidgets('sheet buttons stay above the 3-button nav bar', (tester) async {
    await tester.runAsync(() => boot({'auth_mode': 'guest'}));
    await pumpApp(tester, navBar: 48);
    const visibleBottom = 852.0 - 48;

    // Scrolls the open sheet to its end, where its main button lives.
    Future<void> expectButtonVisible(String label) async {
      final sheetScroll = find
          .descendant(
              of: find.byType(BottomSheet), matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(sheetScroll).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final button = find.widgetWithText(FilledButton, label);
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(visibleBottom),
          reason: '"$label" is hidden behind the navigation bar');
    }

    await tester.tap(find.text('Entries'));
    await settle(tester);
    await tester.tap(find.byTooltip('Add entry'));
    await settle(tester);
    await expectButtonVisible('Add entry');
    await shot(tester, '08_add_entry_navbar_light');
    Navigator.of(tester.element(find.text('New entry'))).pop();
    await settle(tester);

    await tester.tap(find.text('More'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Wallets'), 200,
        scrollable: find
            .descendant(
                of: find.byType(SettingsScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('Wallets'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Wallet'));
    await settle(tester);
    await expectButtonVisible('Add wallet');
    Navigator.of(tester.element(find.text('New wallet'))).pop();
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('Categories'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Category'));
    await settle(tester);
    await expectButtonVisible('Add category');
  });
}

/// Lets real DB futures complete between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}
