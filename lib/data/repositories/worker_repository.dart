import 'package:mess_app/core/database/app_database.dart';
import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/data/models/worker_model.dart';
import 'package:sqflite/sqflite.dart';

/// Local storage for [WorkerModel] records.
///
/// Workers (planters) are managed by the Volunteer. All writes are immediate so
/// the list is available offline. Newly created workers are queued for sync.
class WorkerRepository {
  WorkerRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  // ── Reads ──────────────────────────────────────────────────────────────

  Future<List<WorkerModel>> getAll() async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tableWorkers,
      orderBy: DbConstants.colName,
    );
    return rows.map(WorkerModel.fromMap).toList();
  }

  Future<WorkerModel?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tableWorkers,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : WorkerModel.fromMap(rows.first);
  }

  Future<int> getWorkerCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbConstants.tableWorkers} '
      'WHERE ${DbConstants.colIsActive} = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Number of workers who planted at least one tree today.
  Future<int> getActiveCountToday() async {
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT ${DbConstants.colWorkerId}) AS cnt
        FROM ${DbConstants.tableTrees}
       WHERE DATE(${DbConstants.colCreatedAt} / 1000, 'unixepoch', 'localtime')
             = DATE('now', 'localtime')
         AND ${DbConstants.colIsDead} = 0
         AND ${DbConstants.colWorkerId} IS NOT NULL
    ''');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns all active workers with their today's tree count, ordered by
  /// activity (most trees first, then alphabetically). This is a single
  /// JOIN query — efficient for small teams.
  Future<List<WorkerTodayStats>> getWorkersWithTodayStats() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT
        w.${DbConstants.colId},
        w.${DbConstants.colServerId},
        w.${DbConstants.colName},
        w.${DbConstants.colPhone},
        w.${DbConstants.colPhotoPath},
        w.${DbConstants.colVolunteerId},
        w.${DbConstants.colIsActive},
        w.${DbConstants.colSyncStatus},
        w.${DbConstants.colRetryCount},
        w.${DbConstants.colLastError},
        w.${DbConstants.colCreatedAt},
        w.${DbConstants.colUpdatedAt},
        w.${DbConstants.colSyncedAt},
        COALESCE(t.trees_today, 0) AS trees_today,
        t.last_activity,
        COALESCE(pa.plot_count, 0) AS plot_count,
        pa.plot_summary
      FROM ${DbConstants.tableWorkers} w
      LEFT JOIN (
        SELECT
          ${DbConstants.colWorkerId},
          COUNT(*) AS trees_today,
          MAX(${DbConstants.colCreatedAt}) AS last_activity
        FROM ${DbConstants.tableTrees}
        WHERE DATE(${DbConstants.colCreatedAt} / 1000, 'unixepoch', 'localtime')
              = DATE('now', 'localtime')
          AND ${DbConstants.colIsDead} = 0
        GROUP BY ${DbConstants.colWorkerId}
      ) t ON w.${DbConstants.colId} = t.${DbConstants.colWorkerId}
      LEFT JOIN (
        SELECT
          a.${DbConstants.colWorkerId},
          COUNT(*) AS plot_count,
          GROUP_CONCAT(p.${DbConstants.colName}, ', ') AS plot_summary
        FROM ${DbConstants.tableWorkerPlotAssignments} a
        INNER JOIN ${DbConstants.tablePlots} p
                ON p.${DbConstants.colId} = a.${DbConstants.colPlotId}
        GROUP BY a.${DbConstants.colWorkerId}
      ) pa ON w.${DbConstants.colId} = pa.${DbConstants.colWorkerId}
      WHERE w.${DbConstants.colIsActive} = 1
      ORDER BY trees_today DESC, w.${DbConstants.colName} ASC
    ''');

    return rows.map((row) {
      final worker = WorkerModel.fromMap(row);
      final treesToday = (row['trees_today'] as int?) ?? 0;
      final lastMs = row['last_activity'] as int?;
      final plotCount = (row['plot_count'] as int?) ?? 0;
      final plotSummary = row['plot_summary'] as String?;
      return WorkerTodayStats(
        worker: worker,
        treesToday: treesToday,
        lastActivity: lastMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastMs)
            : null,
        assignedPlotCount: plotCount,
        assignedPlotSummary: plotSummary,
      );
    }).toList();
  }

  /// Trees planted by a specific worker (most recent first) — used on the
  /// worker detail screen.
  Future<List<Map<String, dynamic>>> getTreesByWorker(
    String workerId, {
    int limit = 30,
  }) async {
    final db = await _database;
    return db.query(
      DbConstants.tableTrees,
      where: '${DbConstants.colWorkerId} = ?',
      whereArgs: [workerId],
      orderBy: '${DbConstants.colCreatedAt} DESC',
      limit: limit,
    );
  }

  Future<int> getTotalTreesByWorker(String workerId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbConstants.tableTrees} '
      'WHERE ${DbConstants.colWorkerId} = ? AND ${DbConstants.colIsDead} = 0',
      [workerId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTodayTreesByWorker(String workerId) async {
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS cnt
        FROM ${DbConstants.tableTrees}
       WHERE ${DbConstants.colWorkerId} = ?
         AND ${DbConstants.colIsDead} = 0
         AND DATE(${DbConstants.colCreatedAt} / 1000, 'unixepoch', 'localtime')
             = DATE('now', 'localtime')
    ''', [workerId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Writes ─────────────────────────────────────────────────────────────

  /// Inserts a new worker. Fails on duplicate [worker.id].
  Future<void> insert(WorkerModel worker) async {
    final db = await _database;
    await db.insert(
      DbConstants.tableWorkers,
      worker.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Full upsert — used when the server sends down a canonical worker record.
  Future<void> upsert(WorkerModel worker) async {
    final db = await _database;
    await db.insert(
      DbConstants.tableWorkers,
      worker.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setActiveStatus(String id, {required bool isActive}) async {
    final db = await _database;
    await db.update(
      DbConstants.tableWorkers,
      {
        DbConstants.colIsActive: isActive ? 1 : 0,
        DbConstants.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSyncState(
    String id, {
    required String syncStatus,
    String? serverId,
    int? retryCount,
    String? lastError,
  }) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      DbConstants.tableWorkers,
      {
        DbConstants.colSyncStatus: syncStatus,
        if (serverId != null) DbConstants.colServerId: serverId,
        if (retryCount != null) DbConstants.colRetryCount: retryCount,
        if (lastError != null) DbConstants.colLastError: lastError,
        if (syncStatus == 'synced') DbConstants.colSyncedAt: now,
        DbConstants.colUpdatedAt: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }
}
