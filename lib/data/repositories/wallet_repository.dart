import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/models.dart';

class WalletRepository {
  WalletRepository(this._db);

  final AppDatabase _db;
  Database get _sql => _db.db;

  Future<List<Wallet>> getAll() async {
    final rows = await _sql.query(
      Tables.wallets,
      where: 'deleted = 0',
      orderBy: 'sort_order, name COLLATE NOCASE',
    );
    return rows.map(Wallet.fromRow).toList();
  }

  Stream<List<Wallet>> watchAll() => _db.watch({Tables.wallets}, getAll);

  /// Opening balance + income − expense − transfers out + transfers in.
  Future<Map<String, double>> balances() async {
    final rows = await _sql.rawQuery('''
      SELECT w.id AS id,
        w.opening_balance
        + COALESCE((SELECT SUM(t.amount) FROM ${Tables.transactions} t
            WHERE t.deleted = 0 AND t.wallet_id = w.id AND t.type = 'income'), 0)
        - COALESCE((SELECT SUM(t.amount) FROM ${Tables.transactions} t
            WHERE t.deleted = 0 AND t.wallet_id = w.id AND t.type IN ('expense', 'transfer')), 0)
        + COALESCE((SELECT SUM(t.amount) FROM ${Tables.transactions} t
            WHERE t.deleted = 0 AND t.to_wallet_id = w.id AND t.type = 'transfer'), 0)
        AS balance
      FROM ${Tables.wallets} w
      WHERE w.deleted = 0
    ''');
    return {
      for (final r in rows)
        r['id'] as String: (r['balance'] as num?)?.toDouble() ?? 0,
    };
  }

  Stream<Map<String, double>> watchBalances() =>
      _db.watch({Tables.wallets, Tables.transactions}, balances);

  Future<void> save(Wallet w) async {
    await _sql.insert(
      Tables.wallets,
      {
        ...w.toRow(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'deleted': 0,
        'dirty': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _db.notify({Tables.wallets});
  }

  Future<bool> hasTransactions(String id) async {
    final n = Sqflite.firstIntValue(await _sql.rawQuery(
      'SELECT COUNT(*) FROM ${Tables.transactions} '
      'WHERE deleted = 0 AND (wallet_id = ? OR to_wallet_id = ?)',
      [id, id],
    ));
    return (n ?? 0) > 0;
  }

  Future<void> delete(String id) async {
    await _sql.update(
      Tables.wallets,
      {
        'deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _db.notify({Tables.wallets});
  }

  Future<int> nextSortOrder() async {
    final r =
        await _sql.rawQuery('SELECT MAX(sort_order) AS m FROM ${Tables.wallets}');
    return ((r.first['m'] as int?) ?? 0) + 1;
  }
}
