import 'package:mess_app/core/database/app_database.dart';
import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/data/models/tree_growth_update_model.dart';
import 'package:sqflite/sqflite.dart';

/// Manages growth-stage updates for planted trees.
class TreeGrowthRepository {
  TreeGrowthRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;
  Future<Database> get _database => _db.database;

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// All growth updates for [treeId], newest first.
  Future<List<TreeGrowthUpdateModel>> getForTree(String treeId) async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tableTreeGrowthUpdates,
      where: '${DbConstants.colTreeId} = ?',
      whereArgs: [treeId],
      orderBy: '${DbConstants.colRecordedAt} DESC',
    );
    return rows.map(TreeGrowthUpdateModel.fromMap).toList();
  }

  /// The most recent growth update for [treeId], or null if none exists.
  Future<TreeGrowthUpdateModel?> getLatest(String treeId) async {
    final updates = await getForTree(treeId);
    return updates.isEmpty ? null : updates.first;
  }

  /// Growth updates recorded for trees owned by [workerId], newest first.
  /// Used by volunteer (admin) to review field volunteer activity.
  Future<List<WorkerTreeGrowthUpdate>> getForWorker(
    String workerId, {
    int limit = 40,
  }) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT
        gu.*,
        t.${DbConstants.colSpecies} AS tree_species,
        t.${DbConstants.colPlotId} AS tree_plot_id
      FROM ${DbConstants.tableTreeGrowthUpdates} gu
      INNER JOIN ${DbConstants.tableTrees} t
         ON t.${DbConstants.colId} = gu.${DbConstants.colTreeId}
      WHERE t.${DbConstants.colWorkerId} = ?
      ORDER BY gu.${DbConstants.colRecordedAt} DESC
      LIMIT ?
      ''',
      [workerId, limit],
    );
    return rows.map(WorkerTreeGrowthUpdate.fromMap).toList();
  }

  /// Returns a map of treeId → latest [GrowthStage] for all of a worker's
  /// trees in a single SQL query.
  Future<Map<String, GrowthStage>> getLatestStagesForWorker(
    String workerId,
  ) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT gu.${DbConstants.colTreeId}, gu.${DbConstants.colGrowthStage}
        FROM ${DbConstants.tableTreeGrowthUpdates} gu
       INNER JOIN ${DbConstants.tableTrees} t
          ON t.${DbConstants.colId} = gu.${DbConstants.colTreeId}
       WHERE t.${DbConstants.colWorkerId} = ?
         AND gu.${DbConstants.colRecordedAt} = (
               SELECT MAX(gu2.${DbConstants.colRecordedAt})
                 FROM ${DbConstants.tableTreeGrowthUpdates} gu2
                WHERE gu2.${DbConstants.colTreeId} = gu.${DbConstants.colTreeId}
             )
      ''',
      [workerId],
    );
    return Map.fromEntries(
      rows.map(
        (r) => MapEntry(
          r[DbConstants.colTreeId] as String,
          GrowthStage.fromValue(
            r[DbConstants.colGrowthStage] as String? ?? 'planted',
          ),
        ),
      ),
    );
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<void> insert(TreeGrowthUpdateModel update) async {
    final db = await _database;
    await db.insert(
      DbConstants.tableTreeGrowthUpdates,
      update.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }
}

/// A growth update joined with tree species / plot for admin review lists.
class WorkerTreeGrowthUpdate {
  const WorkerTreeGrowthUpdate({
    required this.update,
    this.species,
    required this.plotId,
  });

  final TreeGrowthUpdateModel update;
  final String? species;
  final String plotId;

  factory WorkerTreeGrowthUpdate.fromMap(Map<String, dynamic> map) {
    return WorkerTreeGrowthUpdate(
      update: TreeGrowthUpdateModel.fromMap(map),
      species: map['tree_species'] as String?,
      plotId: (map['tree_plot_id'] as String?) ?? '—',
    );
  }
}
