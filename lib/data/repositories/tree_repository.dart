import 'package:mess_app/core/database/app_database.dart';
import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/data/models/tree_model.dart';
import 'package:sqflite/sqflite.dart';

/// Local storage for [TreeModel] records.
///
/// Every registration is written immediately to SQLite with
/// [SyncStatus.pending] so it can survive without any network connection.
/// The sync engine reads the pending rows later and uploads them to the server.
class TreeRepository {
  TreeRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  // ── Reads ──────────────────────────────────────────────────────────────

  Future<TreeModel?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tableTrees,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : TreeModel.fromMap(rows.first);
  }

  Future<List<TreeModel>> getByPlotId(String plotId) async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tableTrees,
      where: '${DbConstants.colPlotId} = ?',
      whereArgs: [plotId],
      orderBy: '${DbConstants.colCreatedAt} DESC',
    );
    return rows.map(TreeModel.fromMap).toList();
  }

  /// Planted trees on the current account's plots and from its latest field sync.
  Future<List<TreeModel>> getFieldInventory() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT t.*, p.${DbConstants.colName} AS current_plot_name,
             p.${DbConstants.colRegionName} AS current_region_name,
             w.${DbConstants.colName} AS current_worker_name
      FROM ${DbConstants.tableTrees} t
      LEFT JOIN ${DbConstants.tablePlots} p ON p.${DbConstants.colId} = t.${DbConstants.colPlotId}
      LEFT JOIN ${DbConstants.tableWorkers} w ON w.${DbConstants.colId} = t.${DbConstants.colWorkerId}
      WHERE t.${DbConstants.colPlantingDate} IS NOT NULL
        AND (p.${DbConstants.colId} IS NOT NULL OR t.${DbConstants.colSyncedAt} IS NOT NULL)
      ORDER BY COALESCE(p.${DbConstants.colRegionName}, t.${DbConstants.colRegionName}),
               COALESCE(p.${DbConstants.colName}, t.${DbConstants.colPlotName}),
               t.${DbConstants.colPlantingDate} DESC, t.${DbConstants.colId}
    ''');
    return rows.map((row) {
      return TreeModel.fromMap({
        ...row,
        DbConstants.colPlotName:
            row['current_plot_name'] ?? row[DbConstants.colPlotName],
        DbConstants.colRegionName:
            row['current_region_name'] ?? row[DbConstants.colRegionName],
        DbConstants.colPlantedBy:
            row[DbConstants.colPlantedBy] ?? row['current_worker_name'],
      });
    }).toList();
  }

  /// Total count of live (not dead) trees stored locally.
  Future<int> getTreeCount() async {
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS cnt FROM ${DbConstants.tableTrees}
       WHERE ${DbConstants.colIsDead} = 0
      ''');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Trees registered on today's date (local device time).
  Future<int> getRegisteredTodayCount() async {
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS cnt FROM ${DbConstants.tableTrees}
       WHERE DATE(COALESCE(${DbConstants.colPlantingDate}, ${DbConstants.colCreatedAt}) / 1000, 'unixepoch', 'localtime')
             = DATE('now', 'localtime')
      ''');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// All live trees registered by a specific worker, newest first.
  Future<List<TreeModel>> getByWorkerId(String workerId) async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tableTrees,
      where: '${DbConstants.colWorkerId} = ? AND ${DbConstants.colIsDead} = 0',
      whereArgs: [workerId],
      orderBy: '${DbConstants.colCreatedAt} DESC',
    );
    return rows.map(TreeModel.fromMap).toList();
  }

  /// Trees registered today by a specific worker.
  Future<int> getRegisteredTodayByWorker(String workerId) async {
    final db = await _database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS cnt FROM ${DbConstants.tableTrees}
       WHERE ${DbConstants.colWorkerId} = ?
         AND ${DbConstants.colIsDead} = 0
         AND DATE(COALESCE(${DbConstants.colPlantingDate}, ${DbConstants.colCreatedAt}) / 1000, 'unixepoch', 'localtime')
             = DATE('now', 'localtime')
      ''',
      [workerId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Writes ─────────────────────────────────────────────────────────────

  /// Reconciles the server's planted inventory while retaining local-only trees.
  Future<void> applyFieldTrees(List<TreeModel> trees) async {
    final db = await _database;
    final ids = trees.map((tree) => tree.id).toSet();
    const inventoryColumns = [
      DbConstants.colServerId,
      DbConstants.colSponsorshipCategory,
      DbConstants.colCorporateProgramId,
      DbConstants.colSpecies,
      DbConstants.colPlantingDate,
      DbConstants.colPlotId,
      DbConstants.colPlotName,
      DbConstants.colRegionName,
      DbConstants.colPlantedBy,
      DbConstants.colPlantedById,
      DbConstants.colLatitude,
      DbConstants.colLongitude,
      DbConstants.colNotes,
      DbConstants.colWorkerId,
      DbConstants.colIsDead,
      DbConstants.colSyncStatus,
      DbConstants.colCreatedAt,
      DbConstants.colUpdatedAt,
      DbConstants.colSyncedAt,
    ];
    await db.transaction((txn) async {
      final cached = await txn.query(
        DbConstants.tableTrees,
        columns: [DbConstants.colId],
        where:
            "${DbConstants.colSyncStatus} = 'synced' AND ${DbConstants.colSyncedAt} IS NOT NULL",
      );
      // Keep a parent tree if an older app saved unsynced growth locally.
      final pendingGrowth = await txn.query(
        DbConstants.tableTreeGrowthUpdates,
        columns: [DbConstants.colTreeId],
        where: "${DbConstants.colSyncStatus} <> 'synced'",
        distinct: true,
      );
      final localParents = pendingGrowth
          .map((row) => row[DbConstants.colTreeId])
          .toSet();
      final batch = txn.batch();
      for (final row in cached) {
        final id = row[DbConstants.colId];
        if (!ids.contains(id) && !localParents.contains(id)) {
          batch.delete(
            DbConstants.tableTrees,
            where: '${DbConstants.colId} = ?',
            whereArgs: [id],
          );
        }
      }
      for (final tree in trees) {
        final values = tree.toMap();
        batch.insert(
          DbConstants.tableTrees,
          values,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        batch.update(
          DbConstants.tableTrees,
          {for (final column in inventoryColumns) column: values[column]},
          where: '${DbConstants.colId} = ?',
          whereArgs: [tree.id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Saves a new tree record. Throws if a record with [tree.id] already
  /// exists, preventing accidental duplicates.
  Future<void> insert(TreeModel tree) async {
    final db = await _database;
    await db.insert(
      DbConstants.tableTrees,
      tree.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Updates [syncStatus], [serverId], [retryCount], and [lastError] after
  /// the sync engine processes this record.
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
      DbConstants.tableTrees,
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

  /// Marks a tree as dead and sets its [replacementForId] link.
  Future<void> markAsDead(String id, {String? replacementForId}) async {
    final db = await _database;
    await db.update(
      DbConstants.tableTrees,
      {
        DbConstants.colIsDead: 1,
        if (replacementForId != null)
          DbConstants.colReplacementForId: replacementForId,
        DbConstants.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Full upsert — used when the server returns a canonical record.
  Future<void> upsert(TreeModel tree) async {
    final db = await _database;
    await db.insert(
      DbConstants.tableTrees,
      tree.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
