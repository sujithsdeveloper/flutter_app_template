import 'dart:typed_data';

import 'package:mess_app/core/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

typedef RapidRow = Map<String, dynamic>;

class RapidCaptureRepository {
  RapidCaptureRepository(AppDatabase database) : _database = database.database;

  final Future<Database> _database;

  Future<RapidRow?> latestRun(String account, String batch) async {
    final db = await _database;
    final rows = await db.query(
      'rapid_runs',
      where: 'account=? AND batch_id=?',
      whereArgs: [account, batch],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.firstOrNull;
  }

  Future<void> addRun(
    String account,
    String batch,
    String id,
    String startedAt,
  ) async {
    final db = await _database;
    await db.insert('rapid_runs', {
      'id': id,
      'account': account,
      'batch_id': batch,
      'started_at': startedAt,
      'state': 'active',
    });
  }

  Future<void> changeState(String id, String state) async {
    final db = await _database;
    await db.update(
      'rapid_runs',
      {'state': state},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> markFinishedSynced(String id) async {
    final db = await _database;
    await db.update(
      'rapid_runs',
      {'server_finished': 1},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<List<RapidRow>> trees(String runId) async {
    final db = await _database;
    return db.query(
      'rapid_trees',
      columns: [
        'id',
        'captured_at',
        'lat',
        'lng',
        'notes',
        'tree_synced',
        'photo_synced',
      ],
      where: 'run_id=?',
      whereArgs: [runId],
      orderBy: 'captured_at,id',
    );
  }

  Future<List<RapidRow>> runsToSync(String account, String batch) async {
    final db = await _database;
    return db.rawQuery(
      """
      SELECT r.* FROM rapid_runs r WHERE r.account=? AND r.batch_id=? AND (
        r.server_finished=0 OR EXISTS(SELECT 1 FROM rapid_trees t
          WHERE t.run_id=r.id AND (t.tree_synced=0 OR t.photo_synced=0))
      ) ORDER BY r.started_at,r.id
    """,
      [account, batch],
    );
  }

  Future<String> runState(String id) async {
    final db = await _database;
    final rows = await db.query(
      'rapid_runs',
      columns: ['state'],
      where: 'id=?',
      whereArgs: [id],
    );
    return rows.single['state'] as String;
  }

  Future<(int, int)> pendingCounts(String account, String batch) async {
    final db = await _database;
    final rows = await db.rawQuery(
      """
      SELECT COUNT(CASE WHEN t.tree_synced=0 THEN 1 END) AS trees,
        COUNT(CASE WHEN t.photo_synced=0 THEN 1 END) AS photos
      FROM rapid_trees t JOIN rapid_runs r ON r.id=t.run_id
      WHERE r.account=? AND r.batch_id=?
    """,
      [account, batch],
    );
    return (rows.single['trees'] as int, rows.single['photos'] as int);
  }

  Future<void> addTree(String runId, RapidRow row, Uint8List photo) async {
    final db = await _database;
    await db.insert('rapid_trees', {...row, 'run_id': runId, 'photo': photo});
  }

  Future<void> markTreeSynced(String id) async {
    final db = await _database;
    await db.update(
      'rapid_trees',
      {'tree_synced': 1},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<Uint8List?> photo(String id) async {
    final db = await _database;
    final rows = await db.query(
      'rapid_trees',
      columns: ['photo'],
      where: 'id=?',
      whereArgs: [id],
    );
    return rows.firstOrNull?['photo'] as Uint8List?;
  }

  Future<void> markPhotoSynced(String id) async {
    final db = await _database;
    await db.update(
      'rapid_trees',
      {'photo_synced': 1, 'photo': null},
      where: 'id=?',
      whereArgs: [id],
    );
  }
}
