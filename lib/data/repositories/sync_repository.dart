import 'package:mess_app/core/database/app_database.dart';
import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/data/models/sync_record_model.dart';
import 'package:mess_app/data/models/sync_status.dart';
import 'package:sqflite/sqflite.dart';

/// Manages the local sync outbox (sync_queue table) and sync metadata
/// (sync_meta table). This is the source of truth for what needs to be
/// uploaded to the server.
class SyncRepository {
  SyncRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  // ── Queue operations ───────────────────────────────────────────────────

  /// Adds a new operation to the outbox. Uses INSERT OR IGNORE to prevent
  /// duplicate queue entries for the same entity+operation combination.
  Future<void> enqueue(SyncRecordModel record) async {
    final db = await _database;
    await db.insert(
      DbConstants.tableSyncQueue,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// All records with [SyncStatus.pending] or [SyncStatus.failed] that
  /// should be retried. Ordered oldest-first so earlier registrations reach
  /// the server first.
  Future<List<SyncRecordModel>> getPendingItems() async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tableSyncQueue,
      where:
          "${DbConstants.colSyncStatus} IN ('${SyncStatus.pending.value}', '${SyncStatus.failed.value}')",
      orderBy: DbConstants.colCreatedAt,
    );
    return rows.map(SyncRecordModel.fromMap).toList();
  }

  /// Count of items waiting to be uploaded (pending + failed).
  Future<int> getPendingCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      """
      SELECT COUNT(*) AS cnt FROM ${DbConstants.tableSyncQueue}
       WHERE ${DbConstants.colSyncStatus}
             IN ('${SyncStatus.pending.value}', '${SyncStatus.failed.value}')
      """,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Count of records that failed after all retries.
  Future<int> getFailedCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      """
      SELECT COUNT(*) AS cnt FROM ${DbConstants.tableSyncQueue}
       WHERE ${DbConstants.colSyncStatus} = '${SyncStatus.failed.value}'
         AND ${DbConstants.colRetryCount} >= 3
      """,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Mark a queue entry as synced and record the timestamp.
  Future<void> markAsSynced(String id) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      DbConstants.tableSyncQueue,
      {
        DbConstants.colSyncStatus: SyncStatus.synced.value,
        DbConstants.colSyncedAt: now,
        DbConstants.colUpdatedAt: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Mark a queue entry as failed and append the error message.
  /// Increments [retryCount] so callers can implement exponential back-off.
  Future<void> markAsFailed(String id, {required String error}) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawUpdate(
      '''
      UPDATE ${DbConstants.tableSyncQueue}
         SET ${DbConstants.colSyncStatus} = '${SyncStatus.failed.value}',
             ${DbConstants.colLastError}  = ?,
             ${DbConstants.colRetryCount} = ${DbConstants.colRetryCount} + 1,
             ${DbConstants.colUpdatedAt}  = ?
       WHERE ${DbConstants.colId} = ?
      ''',
      [error, now, id],
    );
  }

  /// Set a queue entry to 'syncing' before the upload attempt begins.
  Future<void> markAsSyncing(String id) async {
    final db = await _database;
    await db.update(
      DbConstants.tableSyncQueue,
      {
        DbConstants.colSyncStatus: SyncStatus.syncing.value,
        DbConstants.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Reset a 'syncing' entry back to 'pending' — used when the app is killed
  /// mid-upload so the record will be retried on next launch.
  Future<void> resetSyncingToPending() async {
    final db = await _database;
    await db.update(
      DbConstants.tableSyncQueue,
      {
        DbConstants.colSyncStatus: SyncStatus.pending.value,
        DbConstants.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: "${DbConstants.colSyncStatus} = '${SyncStatus.syncing.value}'",
    );
  }

  // ── Sync metadata ──────────────────────────────────────────────────────

  Future<DateTime?> getLastSyncTime() async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tableSyncMeta,
      where: '${DbConstants.colKey} = ?',
      whereArgs: [DbConstants.metaKeyLastSyncTime],
      limit: 1,
    );
    if (rows.isEmpty || rows.first[DbConstants.colValue] == null) return null;
    final millis = int.tryParse(rows.first[DbConstants.colValue] as String);
    return millis != null
        ? DateTime.fromMillisecondsSinceEpoch(millis)
        : null;
  }

  Future<void> setLastSyncTime(DateTime time) async {
    final db = await _database;
    await db.insert(
      DbConstants.tableSyncMeta,
      {
        DbConstants.colKey: DbConstants.metaKeyLastSyncTime,
        DbConstants.colValue: time.millisecondsSinceEpoch.toString(),
        DbConstants.colUpdatedAt: time.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Generic meta key access ────────────────────────────────────────────

  Future<String?> getMetaValue(String key) async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tableSyncMeta,
      where: '${DbConstants.colKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first[DbConstants.colValue] as String?;
  }

  Future<void> setMetaValue(String key, String value) async {
    final db = await _database;
    await db.insert(
      DbConstants.tableSyncMeta,
      {
        DbConstants.colKey: key,
        DbConstants.colValue: value,
        DbConstants.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
