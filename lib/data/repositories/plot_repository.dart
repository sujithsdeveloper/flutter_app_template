import 'package:mess_app/core/database/app_database.dart';
import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/data/models/plot_model.dart';
import 'package:mess_app/data/models/sync_status.dart';
import 'package:sqflite/sqflite.dart';

/// Provides CRUD access to the local [DbConstants.tablePlots] table.
/// All writes go to SQLite immediately so the data survives app restarts
/// even without a network connection.
class PlotRepository {
  PlotRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  // ── Reads ──────────────────────────────────────────────────────────────

  /// Returns all plots assigned to this volunteer, ordered by name.
  Future<List<PlotModel>> getAssignedPlots() async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tablePlots,
      orderBy: DbConstants.colName,
    );
    return rows.map(PlotModel.fromMap).toList();
  }

  Future<int> getPlotCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbConstants.tablePlots}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<PlotModel?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(
      DbConstants.tablePlots,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : PlotModel.fromMap(rows.first);
  }

  // ── Writes ─────────────────────────────────────────────────────────────

  /// Inserts or replaces a plot. Used when the server sends down an updated
  /// assignment list after a successful sync, or when a privileged volunteer
  /// creates a plot locally.
  Future<void> upsert(PlotModel plot) async {
    final db = await _database;
    await db.insert(
      DbConstants.tablePlots,
      plot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Generates the next local plot ID in the PLT-XXX format.
  Future<String> generatePlotId() async {
    final count = await getPlotCount();
    return 'PLT-${(count + 100).toString().padLeft(3, '0')}';
  }

  /// Creates a new plot assigned to [volunteerId].
  Future<PlotModel> create({
    required String id,
    required String name,
    required String location,
    required String volunteerId,
    String? district,
    double? latitude,
    double? longitude,
    double? areaHectares,
    String? serverId,
    SyncStatus syncStatus = SyncStatus.pending,
  }) async {
    final now = DateTime.now();
    final plot = PlotModel(
      id: id,
      serverId: serverId,
      name: name.trim(),
      location: location.trim(),
      district: district?.trim().isEmpty ?? true ? null : district?.trim(),
      latitude: latitude,
      longitude: longitude,
      areaHectares: areaHectares,
      assignedVolunteerId: volunteerId,
      syncStatus: syncStatus,
      createdAt: now,
      updatedAt: now,
      syncedAt: syncStatus == SyncStatus.synced ? now : null,
    );
    await upsert(plot);
    return plot;
  }

  /// Updates editable plot fields and marks the row pending until synced.
  Future<PlotModel?> update({
    required String id,
    required String name,
    required String location,
    String? district,
    double? latitude,
    double? longitude,
    double? areaHectares,
    SyncStatus? syncStatus,
    String? serverId,
  }) async {
    final existing = await getById(id);
    if (existing == null) return null;

    final now = DateTime.now();
    final updated = existing.copyWith(
      name: name.trim(),
      location: location.trim(),
      district: district?.trim().isEmpty ?? true ? null : district?.trim(),
      clearDistrict: district == null || district.trim().isEmpty,
      latitude: latitude,
      longitude: longitude,
      clearLatitude: latitude == null,
      clearLongitude: longitude == null,
      areaHectares: areaHectares,
      clearAreaHectares: areaHectares == null,
      syncStatus: syncStatus ?? SyncStatus.pending,
      serverId: serverId,
      updatedAt: now,
      syncedAt: (syncStatus ?? SyncStatus.pending) == SyncStatus.synced
          ? now
          : existing.syncedAt,
    );
    await upsert(updated);
    return updated;
  }

  /// Removes a plot from the local database (e.g. after ending/retiring remotely).
  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete(
      DbConstants.tablePlots,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Replaces the entire local plots table with [plots] from a field sync.
  /// Removes orphan/seed rows that are no longer in the API payload.
  Future<void> replaceAll(List<PlotModel> plots) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(DbConstants.tablePlots);
      for (final plot in plots) {
        await txn.insert(
          DbConstants.tablePlots,
          plot.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Increments [treeCount] by [delta] (can be negative for deletions).
  /// Called every time a tree is registered or removed on this device.
  Future<void> incrementTreeCount(String plotId, {int delta = 1}) async {
    final db = await _database;
    await db.rawUpdate(
      '''
      UPDATE ${DbConstants.tablePlots}
         SET ${DbConstants.colTreeCount} = ${DbConstants.colTreeCount} + ?,
             ${DbConstants.colUpdatedAt}  = ?
       WHERE ${DbConstants.colId} = ?
      ''',
      [delta, DateTime.now().millisecondsSinceEpoch, plotId],
    );
  }

  /// Updates the [status] column of a plot (used after inspection analysis).
  Future<void> updateStatus(String plotId, PlotStatus status) async {
    final db = await _database;
    await db.update(
      DbConstants.tablePlots,
      {
        DbConstants.colStatus: status.value,
        DbConstants.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [plotId],
    );
  }

  /// Returns the total number of trees across all assigned plots.
  Future<int> getTotalTreeCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT SUM(${DbConstants.colTreeCount}) AS total FROM ${DbConstants.tablePlots}',
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Number of plots whose [status] is 'inspection_due'.
  Future<int> getInspectionDueCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS cnt FROM ${DbConstants.tablePlots}
       WHERE ${DbConstants.colStatus} = 'inspection_due'
      ''',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
