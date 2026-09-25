import 'package:mess_app/core/database/app_database.dart';
import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/data/models/tree_task_model.dart';
import 'package:sqflite/sqflite.dart';

/// Local storage for [TreeTaskModel] records.
///
/// Tasks are created by the admin panel and synced down to the device.
/// The volunteer assigns workers to pending tasks; assignment changes are
/// queued for server upload.
class TreeTaskRepository {
  TreeTaskRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  // ── Reads ──────────────────────────────────────────────────────────────

  Future<List<TreeTaskModel>> getAll({
    TaskStatus? filter,
    String? plotId,
  }) async {
    final db = await _database;
    String? where;
    List<Object?>? whereArgs;

    if (filter != null && plotId != null) {
      where =
          '${DbConstants.colTaskStatus} = ? AND ${DbConstants.colPlotId} = ?';
      whereArgs = [filter.value, plotId];
    } else if (filter != null) {
      where = '${DbConstants.colTaskStatus} = ?';
      whereArgs = [filter.value];
    } else if (plotId != null) {
      where = '${DbConstants.colPlotId} = ?';
      whereArgs = [plotId];
    }

    final rows = await db.query(
      DbConstants.tableTreeTasks,
      where: where,
      whereArgs: whereArgs,
      orderBy:
          '${DbConstants.colTargetDate} ASC, ${DbConstants.colCreatedAt} ASC',
    );
    return rows.map(TreeTaskModel.fromMap).toList();
  }

  Future<TreeTaskModel?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tableTreeTasks,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : TreeTaskModel.fromMap(rows.first);
  }

  Future<int> getPendingCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM ${DbConstants.tableTreeTasks} "
      "WHERE ${DbConstants.colTaskStatus} = 'pending'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Tasks assigned to a specific worker (for the worker home screen).
  Future<List<TreeTaskModel>> getByWorkerId(
    String workerId, {
    TaskStatus? filter,
  }) async {
    final db = await _database;
    String where = '${DbConstants.colWorkerId} = ?';
    final args = <Object?>[workerId];
    if (filter != null) {
      where += ' AND ${DbConstants.colTaskStatus} = ?';
      args.add(filter.value);
    }
    final rows = await db.query(
      DbConstants.tableTreeTasks,
      where: where,
      whereArgs: args,
      orderBy:
          '${DbConstants.colTargetDate} ASC, ${DbConstants.colCreatedAt} ASC',
    );
    return rows.map(TreeTaskModel.fromMap).toList();
  }

  Future<int> getCountByStatus(TaskStatus status) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbConstants.tableTreeTasks} '
      'WHERE ${DbConstants.colTaskStatus} = ?',
      [status.value],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Writes ─────────────────────────────────────────────────────────────

  /// Upserts a task received from the server.
  Future<void> upsert(TreeTaskModel task) async {
    final db = await _database;
    await db.insert(
      DbConstants.tableTreeTasks,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Full replace so local tasks match the region-scoped server payload.
  Future<void> replaceAll(List<TreeTaskModel> tasks) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(DbConstants.tableTreeTasks);
      for (final task in tasks) {
        await txn.insert(
          DbConstants.tableTreeTasks,
          task.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Assigns [workerId] to the task and updates status to [TaskStatus.assigned].
  /// Returns the updated task.
  Future<TreeTaskModel?> assignWorker(
    String taskId,
    String workerId, {
    String? workerName,
  }) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      DbConstants.tableTreeTasks,
      {
        DbConstants.colWorkerId: workerId,
        if (workerName != null) DbConstants.colWorkerName: workerName,
        DbConstants.colTaskStatus: TaskStatus.assigned.value,
        DbConstants.colSyncStatus: 'pending',
        DbConstants.colUpdatedAt: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [taskId],
    );
    return getById(taskId);
  }

  /// Removes the worker assignment and reverts status to [TaskStatus.pending].
  Future<void> unassignWorker(String taskId) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      DbConstants.tableTreeTasks,
      {
        DbConstants.colWorkerId: null,
        DbConstants.colTaskStatus: TaskStatus.pending.value,
        DbConstants.colSyncStatus: 'pending',
        DbConstants.colUpdatedAt: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [taskId],
    );
  }

  /// Marks a task as planted. Saves the worker's [notes] and optional
  /// [photoPath] captured at planting time.
  Future<void> markAsPlanted(
    String taskId, {
    String? notes,
    String? photoPath,
  }) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      DbConstants.tableTreeTasks,
      {
        DbConstants.colTaskStatus: TaskStatus.planted.value,
        DbConstants.colSyncStatus: 'pending',
        DbConstants.colUpdatedAt: now,
        if (notes != null) DbConstants.colNotes: notes,
        if (photoPath != null) DbConstants.colPhotoPath: photoPath,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [taskId],
    );
  }

  /// Marks a task as cancelled with an optional [reason] stored in last_error.
  Future<void> cancelTask(String taskId, {String? reason}) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      DbConstants.tableTreeTasks,
      {
        DbConstants.colTaskStatus: TaskStatus.cancelled.value,
        DbConstants.colSyncStatus: 'pending',
        DbConstants.colUpdatedAt: now,
        if (reason != null) DbConstants.colLastError: reason,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> updateSyncState(
    String id, {
    required String syncStatus,
    String? serverId,
    String? lastError,
    int? retryCount,
  }) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      DbConstants.tableTreeTasks,
      {
        DbConstants.colSyncStatus: syncStatus,
        if (serverId != null) DbConstants.colServerId: serverId,
        if (lastError != null) DbConstants.colLastError: lastError,
        if (retryCount != null) DbConstants.colRetryCount: retryCount,
        if (syncStatus == 'synced') DbConstants.colSyncedAt: now,
        DbConstants.colUpdatedAt: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }
}
