import 'package:mess_app/core/database/app_database.dart';
import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/data/models/plot_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Links field volunteers to the plots they work on.
class WorkerPlotRepository {
  WorkerPlotRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;
  final _uuid = const Uuid();

  Future<Database> get _database => _db.database;

  Future<List<PlotModel>> getPlotsForWorker(String workerId) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT p.*
        FROM ${DbConstants.tablePlots} p
        INNER JOIN ${DbConstants.tableWorkerPlotAssignments} a
                ON a.${DbConstants.colPlotId} = p.${DbConstants.colId}
       WHERE a.${DbConstants.colWorkerId} = ?
       ORDER BY p.${DbConstants.colName}
    ''', [workerId]);
    return rows.map(PlotModel.fromMap).toList();
  }

  Future<List<String>> getPlotIdsForWorker(String workerId) async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tableWorkerPlotAssignments,
      columns: [DbConstants.colPlotId],
      where: '${DbConstants.colWorkerId} = ?',
      whereArgs: [workerId],
    );
    return rows
        .map((r) => r[DbConstants.colPlotId] as String)
        .toList();
  }

  Future<void> assign(String workerId, String plotId) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      DbConstants.tableWorkerPlotAssignments,
      {
        DbConstants.colId: _uuid.v4(),
        DbConstants.colWorkerId: workerId,
        DbConstants.colPlotId: plotId,
        DbConstants.colAssignedAt: now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> unassign(String workerId, String plotId) async {
    final db = await _database;
    await db.delete(
      DbConstants.tableWorkerPlotAssignments,
      where:
          '${DbConstants.colWorkerId} = ? AND ${DbConstants.colPlotId} = ?',
      whereArgs: [workerId, plotId],
    );
  }

  /// Replaces all plot links for [workerId].
  Future<void> setAssignments(String workerId, List<String> plotIds) async {
    final db = await _database;
    final batch = db.batch();
    batch.delete(
      DbConstants.tableWorkerPlotAssignments,
      where: '${DbConstants.colWorkerId} = ?',
      whereArgs: [workerId],
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final plotId in plotIds) {
      batch.insert(
        DbConstants.tableWorkerPlotAssignments,
        {
          DbConstants.colId: _uuid.v4(),
          DbConstants.colWorkerId: workerId,
          DbConstants.colPlotId: plotId,
          DbConstants.colAssignedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> getAssignmentCount(String workerId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbConstants.tableWorkerPlotAssignments} '
      'WHERE ${DbConstants.colWorkerId} = ?',
      [workerId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
