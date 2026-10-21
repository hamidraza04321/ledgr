import 'package:sqflite/sqflite.dart';

import '../../core/utils/period.dart';
import '../db/app_database.dart';
import '../models/models.dart';

class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;
  Database get _sql => _db.db;

  static const _t = Tables.transactions;
  static const _watch = {Tables.transactions};

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> addAll(List<Txn> txns) async {
    if (txns.isEmpty) return;
    final now = _now;
    final batch = _sql.batch();
    for (final t in txns) {
      batch.insert(
        _t,
        {
          ...t.toRow(),
          'created_at': t.createdAt == 0 ? now : t.createdAt,
          'updated_at': now,
          'deleted': 0,
          'dirty': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _db.notify(_watch);
  }

  Future<void> add(Txn t) => addAll([t]);

  Future<void> update(Txn t) async {
    await _sql.update(
      _t,
      {...t.toRow(), 'updated_at': _now, 'deleted': 0, 'dirty': 1},
      where: 'id = ?',
      whereArgs: [t.id],
    );
    _db.notify(_watch);
  }

  Future<void> _setDeleted(List<String> ids, bool deleted) async {
    if (ids.isEmpty) return;
    final batch = _sql.batch();
    for (final id in ids) {
      batch.update(
        _t,
        {'deleted': deleted ? 1 : 0, 'updated_at': _now, 'dirty': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
    _db.notify(_watch);
  }

  Future<void> softDelete(List<String> ids) => _setDeleted(ids, true);
  Future<void> restore(List<String> ids) => _setDeleted(ids, false);

  Future<List<Txn>> inSpan(DateSpan s) async {
    final rows = await _sql.query(
      _t,
      where: 'deleted = 0 AND date >= ? AND date < ?',
      whereArgs: [s.startMs, s.endMs],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(Txn.fromRow).toList();
  }

  Stream<List<Txn>> watchInSpan(DateSpan s) => _db.watch(_watch, () => inSpan(s));

  Stream<List<Txn>> watchRecent(int limit) => _db.watch(_watch, () async {
        final rows = await _sql.query(
          _t,
          where: 'deleted = 0',
          orderBy: 'date DESC, created_at DESC',
          limit: limit,
        );
        return rows.map(Txn.fromRow).toList();
      });

  /// Includes soft-deleted rows so the chat can show "removed" entries.
  Stream<Map<String, Txn>> watchByIds(List<String> ids) =>
      _db.watch(_watch, () async {
        if (ids.isEmpty) return const <String, Txn>{};
        final rows = await _sql.query(
          _t,
          where: 'id IN (${List.filled(ids.length, '?').join(',')})',
          whereArgs: ids,
        );
        return {for (final r in rows) r['id'] as String: Txn.fromRow(r)};
      });

  Future<Totals> totals(DateSpan s) async {
    final rows = await _sql.rawQuery(
      'SELECT type, SUM(amount) AS total FROM $_t '
      "WHERE deleted = 0 AND type IN ('income', 'expense') "
      'AND date >= ? AND date < ? GROUP BY type',
      [s.startMs, s.endMs],
    );
    var income = 0.0, expense = 0.0;
    for (final r in rows) {
      final v = (r['total'] as num?)?.toDouble() ?? 0;
      if (r['type'] == 'income') income = v;
      if (r['type'] == 'expense') expense = v;
    }
    return Totals(income: income, expense: expense);
  }

  Stream<Totals> watchTotals(DateSpan s) => _db.watch(_watch, () => totals(s));

  Future<List<CategoryTotal>> categoryTotals(DateSpan s, TxnType type) async {
    final rows = await _sql.rawQuery(
      'SELECT category_id, SUM(amount) AS total, COUNT(*) AS cnt FROM $_t '
      'WHERE deleted = 0 AND type = ? AND date >= ? AND date < ? '
      'GROUP BY category_id ORDER BY total DESC',
      [type.name, s.startMs, s.endMs],
    );
    return rows
        .map((r) => CategoryTotal(
              r['category_id'] as String?,
              (r['total'] as num?)?.toDouble() ?? 0,
              (r['cnt'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  Stream<List<CategoryTotal>> watchCategoryTotals(DateSpan s, TxnType type) =>
      _db.watch(_watch, () => categoryTotals(s, type));

  Future<List<AmountPoint>> points(DateSpan s) async {
    final rows = await _sql.rawQuery(
      'SELECT date, type, amount FROM $_t '
      "WHERE deleted = 0 AND type IN ('income', 'expense') "
      'AND date >= ? AND date < ? ORDER BY date',
      [s.startMs, s.endMs],
    );
    return rows
        .map((r) => AmountPoint(
              DateTime.fromMillisecondsSinceEpoch((r['date'] as num).toInt()),
              TxnType.parse(r['type']),
              (r['amount'] as num).toDouble(),
            ))
        .toList();
  }

  Stream<List<AmountPoint>> watchPoints(DateSpan s) =>
      _db.watch(_watch, () => points(s));

  /// Expense total per category id within [s].
  Future<Map<String, double>> spentByCategory(DateSpan s) async {
    final totals = await categoryTotals(s, TxnType.expense);
    return {
      for (final t in totals)
        if (t.categoryId != null) t.categoryId!: t.total,
    };
  }

  Stream<Map<String, double>> watchSpentByCategory(DateSpan s) =>
      _db.watch(_watch, () => spentByCategory(s));
}
