import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/models.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;
  Database get _sql => _db.db;

  Future<List<Category>> getAll() async {
    final rows = await _sql.query(
      Tables.categories,
      where: 'deleted = 0',
      orderBy: 'type, sort_order, name COLLATE NOCASE',
    );
    return rows.map(Category.fromRow).toList();
  }

  Stream<List<Category>> watchAll() => _db.watch({Tables.categories}, getAll);

  Future<void> save(Category c) async {
    await _sql.insert(
      Tables.categories,
      {
        ...c.toRow(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'deleted': 0,
        'dirty': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _db.notify({Tables.categories});
  }

  Future<void> setBudget(String id, double? budget) async {
    await _sql.update(
      Tables.categories,
      {
        'budget': budget,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _db.notify({Tables.categories});
  }

  /// Soft delete. Its entries fall back to "Other" in the UI.
  Future<void> delete(String id) async {
    await _sql.update(
      Tables.categories,
      {
        'deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _db.notify({Tables.categories});
  }

  Future<int> nextSortOrder() async {
    final r = await _sql
        .rawQuery('SELECT MAX(sort_order) AS m FROM ${Tables.categories}');
    return ((r.first['m'] as int?) ?? 0) + 1;
  }
}
