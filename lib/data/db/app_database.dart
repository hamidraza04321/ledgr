import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'seed.dart';

class Tables {
  Tables._();

  static const categories = 'categories';
  static const wallets = 'wallets';
  static const transactions = 'transactions';
  static const keywordRules = 'keyword_rules';
  static const chat = 'chat_messages';

  /// Tables mirrored to Firestore, in push/pull order.
  static const synced = [categories, wallets, keywordRules, transactions];

  /// Columns accepted from the cloud for each synced table.
  static const columns = <String, List<String>>{
    categories: [
      'id', 'name', 'type', 'icon', 'color', 'keywords', 'budget',
      'sort_order', 'updated_at', 'deleted',
    ],
    wallets: [
      'id', 'name', 'icon', 'color', 'opening_balance', 'sort_order',
      'updated_at', 'deleted',
    ],
    transactions: [
      'id', 'type', 'amount', 'category_id', 'wallet_id', 'to_wallet_id',
      'note', 'date', 'source', 'created_at', 'updated_at', 'deleted',
    ],
    keywordRules: ['id', 'category_id', 'updated_at', 'deleted'],
  };
}

/// SQLite is the source of truth. Every synced row carries
/// `updated_at` (ms), `deleted` (soft delete) and `dirty` (needs upload).
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;
  final _changes = StreamController<Set<String>>.broadcast();

  Stream<Set<String>> get changes => _changes.stream;

  static Future<AppDatabase> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'ledgr.db');
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await _createSchema(db);
          await _seed(db);
        },
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _createSchema(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE ${Tables.categories}(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          icon TEXT NOT NULL,
          color INTEGER NOT NULL,
          keywords TEXT NOT NULL DEFAULT '',
          budget REAL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0,
          deleted INTEGER NOT NULL DEFAULT 0,
          dirty INTEGER NOT NULL DEFAULT 1
        )''')
      ..execute('''
        CREATE TABLE ${Tables.wallets}(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          icon TEXT NOT NULL,
          color INTEGER NOT NULL,
          opening_balance REAL NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0,
          deleted INTEGER NOT NULL DEFAULT 0,
          dirty INTEGER NOT NULL DEFAULT 1
        )''')
      ..execute('''
        CREATE TABLE ${Tables.transactions}(
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          category_id TEXT,
          wallet_id TEXT NOT NULL,
          to_wallet_id TEXT,
          note TEXT NOT NULL DEFAULT '',
          date INTEGER NOT NULL,
          source TEXT NOT NULL DEFAULT 'manual',
          created_at INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0,
          deleted INTEGER NOT NULL DEFAULT 0,
          dirty INTEGER NOT NULL DEFAULT 1
        )''')
      ..execute(
          'CREATE INDEX idx_txn_date ON ${Tables.transactions}(deleted, date)')
      ..execute('''
        CREATE TABLE ${Tables.keywordRules}(
          id TEXT PRIMARY KEY,
          category_id TEXT NOT NULL,
          updated_at INTEGER NOT NULL DEFAULT 0,
          deleted INTEGER NOT NULL DEFAULT 0,
          dirty INTEGER NOT NULL DEFAULT 1
        )''')
      ..execute('''
        CREATE TABLE ${Tables.chat}(
          id TEXT PRIMARY KEY,
          role TEXT NOT NULL,
          text TEXT NOT NULL,
          txn_ids TEXT NOT NULL DEFAULT '',
          meta TEXT,
          created_at INTEGER NOT NULL
        )''');
    await batch.commit(noResult: true);
  }

  static Future<void> _seed(DatabaseExecutor db) async {
    final batch = db.batch();
    for (final c in defaultCategories()) {
      batch.insert(Tables.categories, {...c.toRow(), 'dirty': 1},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final w in defaultWallets()) {
      batch.insert(Tables.wallets, {...w.toRow(), 'dirty': 1},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  void notify(Iterable<String> tables) {
    if (!_changes.isClosed) _changes.add(tables.toSet());
  }

  /// Re-runs [query] whenever one of [tables] changes.
  Stream<T> watch<T>(Set<String> tables, Future<T> Function() query) {
    late final StreamController<T> controller;
    StreamSubscription<Set<String>>? sub;
    var running = false;
    var again = false;

    Future<void> run() async {
      if (running) {
        again = true;
        return;
      }
      running = true;
      do {
        again = false;
        try {
          final result = await query();
          if (!controller.isClosed) controller.add(result);
        } catch (e, st) {
          if (!controller.isClosed) controller.addError(e, st);
        }
      } while (again && !controller.isClosed);
      running = false;
    }

    controller = StreamController<T>(
      onListen: () {
        sub = changes.listen((changed) {
          if (changed.any(tables.contains)) run();
        });
        run();
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  /// Flags every synced row for upload (used when a guest signs in).
  Future<void> markAllDirty() async {
    final batch = db.batch();
    for (final t in Tables.synced) {
      batch.rawUpdate('UPDATE $t SET dirty = 1');
    }
    await batch.commit(noResult: true);
  }

  Future<int> pendingCount() async {
    var total = 0;
    for (final t in Tables.synced) {
      total += Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM $t WHERE dirty = 1')) ??
          0;
    }
    return total;
  }

  /// Wipes all user data and restores the defaults.
  Future<void> reset() async {
    await db.transaction((txn) async {
      for (final t in [...Tables.synced, Tables.chat]) {
        await txn.delete(t);
      }
      await _seed(txn);
    });
    notify([...Tables.synced, Tables.chat]);
  }

  Future<void> close() async {
    await _changes.close();
    await db.close();
  }
}
