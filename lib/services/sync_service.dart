import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db/app_database.dart';
import 'connectivity_service.dart';

enum SyncPhase { off, idle, syncing, offline, error }

class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.off,
    this.lastSyncedAt,
    this.pending = 0,
    this.error,
  });

  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final int pending;
  final String? error;

  SyncStatus copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    int? pending,
    String? error,
  }) =>
      SyncStatus(
        phase: phase ?? this.phase,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        pending: pending ?? this.pending,
        error: error,
      );
}

/// Mirrors the local SQLite tables to `users/{uid}/{table}/{id}`.
///
/// * Conflicts: last write wins on `updated_at`.
/// * Incremental pulls use the server-set `synced_at`, so device clock
///   differences never hide changes.
/// * Pull runs before push so stale local rows never overwrite newer
///   cloud rows.
class SyncService {
  SyncService({
    required this.db,
    required this.prefs,
    required this.connectivity,
  });

  final AppDatabase db;
  final SharedPreferences prefs;
  final ConnectivityService connectivity;

  static const _requiredColumns = <String, List<String>>{
    Tables.categories: ['name', 'type', 'icon', 'color'],
    Tables.wallets: ['name', 'icon', 'color'],
    Tables.transactions: ['type', 'amount', 'wallet_id', 'date'],
    Tables.keywordRules: ['category_id'],
  };

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = const SyncStatus();

  String? _uid;
  final _remoteSubs = <StreamSubscription<dynamic>>[];
  StreamSubscription<Set<String>>? _dbSub;
  StreamSubscription<bool>? _netSub;
  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  SyncStatus get status => _status;
  Stream<SyncStatus> get statusStream => _statusController.stream;

  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid, String table) =>
      _fs.collection('users').doc(uid).collection(table);

  String _pointerKey(String uid, String table) => 'sync_ptr_${uid}_$table';
  String _lastKey(String uid) => 'sync_last_$uid';

  void _emit(SyncStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  void start(String uid) {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    final last = prefs.getInt(_lastKey(uid));
    _emit(SyncStatus(
      phase: SyncPhase.idle,
      lastSyncedAt:
          last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
    ));

    _dbSub = db.changes.listen((tables) {
      if (tables.any(Tables.synced.contains)) _schedule();
    });
    _netSub = connectivity.onlineChanges.listen((online) {
      if (online) {
        syncNow();
      } else if (_uid != null) {
        _emit(_status.copyWith(phase: SyncPhase.offline));
      }
    });
    syncNow().whenComplete(() {
      if (_uid == uid) _listenRemote(uid);
    });
  }

  void stop() {
    _debounce?.cancel();
    _dbSub?.cancel();
    _netSub?.cancel();
    for (final s in _remoteSubs) {
      s.cancel();
    }
    _remoteSubs.clear();
    _uid = null;
    _emit(const SyncStatus());
  }

  /// Forgets this account's sync pointers (used on sign-out).
  Future<void> forget(String uid) async {
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('sync_ptr_${uid}_') || key == _lastKey(uid)) {
        await prefs.remove(key);
      }
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncNow);
  }

  Future<void> syncNow() async {
    final uid = _uid;
    if (uid == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        if (!await connectivity.isOnline()) {
          _emit(_status.copyWith(
            phase: SyncPhase.offline,
            pending: await db.pendingCount(),
          ));
          break;
        }
        _emit(_status.copyWith(phase: SyncPhase.syncing));
        await _pull(uid);
        await _push(uid);
        if (_uid != uid) return;
        final now = DateTime.now();
        await prefs.setInt(_lastKey(uid), now.millisecondsSinceEpoch);
        _emit(SyncStatus(
          phase: SyncPhase.idle,
          lastSyncedAt: now,
          pending: await db.pendingCount(),
        ));
      } while (_again && _uid == uid);
    } catch (e) {
      debugPrint('Sync failed: $e');
      if (_uid == uid) {
        _emit(_status.copyWith(
          phase: SyncPhase.error,
          error: e.toString(),
          pending: await db.pendingCount(),
        ));
      }
    } finally {
      _running = false;
    }
  }

  Timestamp? _pointer(String uid, String table) {
    final ms = prefs.getInt(_pointerKey(uid, table));
    return ms == null ? null : Timestamp.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _advancePointer(
    String uid,
    String table,
    Iterable<Map<String, dynamic>> docs,
  ) async {
    var max = prefs.getInt(_pointerKey(uid, table)) ?? -1;
    for (final d in docs) {
      final ts = d['synced_at'];
      if (ts is Timestamp) max = math.max(max, ts.millisecondsSinceEpoch);
    }
    if (max >= 0) await prefs.setInt(_pointerKey(uid, table), max);
  }

  Future<void> _pull(String uid) async {
    for (final table in Tables.synced) {
      Query<Map<String, dynamic>> q = _col(uid, table);
      final since = _pointer(uid, table);
      if (since != null) q = q.where('synced_at', isGreaterThan: since);
      final snap = await q
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 30));
      if (snap.docs.isEmpty) continue;
      final docs = [for (final d in snap.docs) {...d.data(), 'id': d.id}];
      await _apply(table, docs);
      await _advancePointer(uid, table, docs);
    }
  }

  Future<void> _push(String uid) async {
    for (final table in Tables.synced) {
      for (var round = 0; round < 50; round++) {
        final rows = await db.db.query(table, where: 'dirty = 1', limit: 400);
        if (rows.isEmpty) break;
        final batch = _fs.batch();
        for (final r in rows) {
          batch.set(_col(uid, table).doc(r['id'] as String), {
            for (final c in Tables.columns[table]!) c: r[c],
            'synced_at': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit().timeout(const Duration(seconds: 30));
        final clean = db.db.batch();
        for (final r in rows) {
          clean.update(
            table,
            {'dirty': 0},
            where: 'id = ? AND updated_at = ?',
            whereArgs: [r['id'], r['updated_at']],
          );
        }
        await clean.commit(noResult: true);
        if (rows.length < 400) break;
      }
    }
  }

  void _listenRemote(String uid) {
    for (final table in Tables.synced) {
      Query<Map<String, dynamic>> q = _col(uid, table);
      final since = _pointer(uid, table);
      if (since != null) q = q.where('synced_at', isGreaterThan: since);
      final sub = q.snapshots().listen(
        (snap) async {
          if (_uid != uid) return;
          final docs = [
            for (final c in snap.docChanges)
              if (c.type != DocumentChangeType.removed &&
                  !c.doc.metadata.hasPendingWrites &&
                  c.doc.data() != null)
                {...c.doc.data()!, 'id': c.doc.id},
          ];
          if (docs.isEmpty) return;
          await _apply(table, docs);
          if (!snap.metadata.isFromCache) {
            await _advancePointer(uid, table, docs);
          }
        },
        onError: (Object e) => debugPrint('Listener $table failed: $e'),
      );
      _remoteSubs.add(sub);
    }
  }

  /// Writes cloud rows locally when they are newer than the local copy.
  Future<void> _apply(String table, List<Map<String, dynamic>> docs) async {
    final columns = Tables.columns[table]!;
    final required = _requiredColumns[table]!;
    var changed = false;

    await db.db.transaction((txn) async {
      for (final d in docs) {
        final id = d['id'];
        if (id is! String) continue;
        final remoteTs = (d['updated_at'] as num?)?.toInt() ?? 0;

        final local = await txn.query(
          table,
          columns: ['updated_at', 'dirty'],
          where: 'id = ?',
          whereArgs: [id],
        );
        if (local.isNotEmpty) {
          final localTs = (local.first['updated_at'] as num?)?.toInt() ?? 0;
          if (localTs > remoteTs) continue;
          if (localTs == remoteTs) {
            if (local.first['dirty'] == 1) {
              await txn.update(table, {'dirty': 0},
                  where: 'id = ?', whereArgs: [id]);
            }
            continue;
          }
        }

        final row = <String, Object?>{'id': id, 'dirty': 0};
        for (final c in columns) {
          final v = _toSql(d[c]);
          if (v != null) row[c] = v;
        }
        if (required.any((c) => row[c] == null)) continue;
        await txn.insert(table, row,
            conflictAlgorithm: ConflictAlgorithm.replace);
        changed = true;
      }
    });
    if (changed) db.notify({table});
  }

  static Object? _toSql(Object? v) {
    if (v is bool) return v ? 1 : 0;
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    return v;
  }

  void dispose() {
    stop();
    _statusController.close();
  }
}
