import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/models.dart';

/// Chat history is kept on this device only.
class ChatRepository {
  ChatRepository(this._db);

  final AppDatabase _db;
  Database get _sql => _db.db;

  Stream<List<ChatMessage>> watchAll() => _db.watch({Tables.chat}, () async {
        final rows = await _sql.query(Tables.chat, orderBy: 'created_at');
        return rows.map(ChatMessage.fromRow).toList();
      });

  Future<void> add(ChatMessage m) async {
    await _sql.insert(Tables.chat, m.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    _db.notify({Tables.chat});
  }

  Future<void> updateMeta(String id, Map<String, dynamic> meta) async {
    await _sql.update(
      Tables.chat,
      {'meta': jsonEncode(meta)},
      where: 'id = ?',
      whereArgs: [id],
    );
    _db.notify({Tables.chat});
  }

  Future<void> clear() async {
    await _sql.delete(Tables.chat);
    _db.notify({Tables.chat});
  }
}

/// Words the user taught the parser by re-categorising chat entries.
class KeywordRuleRepository {
  KeywordRuleRepository(this._db);

  final AppDatabase _db;
  Database get _sql => _db.db;

  Future<Map<String, String>> getAll() async {
    final rows = await _sql.query(Tables.keywordRules, where: 'deleted = 0');
    return {
      for (final r in rows) r['id'] as String: r['category_id'] as String,
    };
  }

  Future<void> learn(Iterable<String> words, String categoryId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _sql.batch();
    for (final w in words) {
      batch.insert(
        Tables.keywordRules,
        {
          'id': w,
          'category_id': categoryId,
          'updated_at': now,
          'deleted': 0,
          'dirty': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _db.notify({Tables.keywordRules});
  }
}
