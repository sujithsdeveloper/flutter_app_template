import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:mess_app/core/constants/app_logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'db_constants.dart';
import 'sample_photo_writer.dart';

/// Singleton SQLite database for the app.
///
/// Call [init] once from [main] before [runApp]. Every repository receives
/// this instance via the DI container and accesses [database] to obtain the
/// open [Database] handle.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  bool get isInitialized => _db != null;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<void> init() async {
    _db ??= await _open();
    // Ensure auth credentials exist regardless of whether this is a fresh
    // install or an upgrade from a prior version (IGNORE = no-op if present).
    await _seedAuthCredentials(_db!);
    AppLogger.request('[AppDatabase] opened at ${_db!.path}');
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, DbConstants.dbName);
    return openDatabase(
      path,
      version: DbConstants.version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ── DDL ──────────────────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _seedSampleData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      switch (v) {
        case 2:
          // Add workers table and worker_id column to trees.
          await _createWorkersTable(db);
          try {
            await db.execute(
              'ALTER TABLE ${DbConstants.tableTrees} ADD COLUMN '
              '${DbConstants.colWorkerId} TEXT',
            );
          } catch (_) {
            // Column might already exist in some edge-case dev builds.
          }
          await _seedSampleWorkers(db);
        case 3:
          // Add tree_tasks table (admin-assigned planting tasks).
          await _createTreeTasksTable(db);
          await _seedTreeTasks(db);
        case 4:
          try {
            await db.execute(
              'ALTER TABLE ${DbConstants.tableTreeTasks} ADD COLUMN '
              '${DbConstants.colPhotoPath} TEXT',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE ${DbConstants.tableTrees} ADD COLUMN '
              '${DbConstants.colWorkerId} TEXT',
            );
          } catch (_) {}
        case 5:
          // Add tree_growth_updates table for recording growing stages.
          await _createTreeGrowthUpdatesTable(db);
        case 6:
          await _createWorkerPlotAssignmentsTable(db);
          await _seedSamplePlotAssignments(db);
        case 7:
          // Ensure sample trees exist, then attach growth updates + photos.
          await _seedSampleTrees(db);
          await _seedSampleGrowthUpdates(db);
        case 8:
          try {
            await db.execute(
              'ALTER TABLE ${DbConstants.tableTreeTasks} ADD COLUMN '
              '${DbConstants.colTreeId} TEXT',
            );
          } catch (_) {}
        case 9:
          // Drop offline demo plots (and dependents). Real plots arrive via
          // GET /field/sync and fully replace the local plots table.
          await _purgeDemoSeedPlots(db);
        case 10:
          // Region / sponsor metadata for planting tasks.
          for (final col in [
            DbConstants.colPlotName,
            DbConstants.colWorkerName,
            DbConstants.colRegionId,
            DbConstants.colRegionName,
            DbConstants.colSponsorshipId,
            DbConstants.colSponsorIntent,
          ]) {
            try {
              await db.execute(
                'ALTER TABLE ${DbConstants.tableTreeTasks} ADD COLUMN $col TEXT',
              );
            } catch (_) {}
          }
        case 11:
          try {
            await db.execute(
              'ALTER TABLE ${DbConstants.tableTreeTasks} ADD COLUMN '
              '${DbConstants.colProgramName} TEXT',
            );
          } catch (_) {}
        case 12:
          await db.execute(
            'ALTER TABLE ${DbConstants.tablePlots} ADD COLUMN ${DbConstants.colRegionName} TEXT',
          );
          for (final column in [
            DbConstants.colPlotName,
            DbConstants.colRegionName,
            DbConstants.colPlantedBy,
            DbConstants.colPlantedById,
          ]) {
            await db.execute(
              'ALTER TABLE ${DbConstants.tableTrees} ADD COLUMN $column TEXT',
            );
          }
        case 13:
          for (final column in [
            DbConstants.colSponsorshipCategory,
            DbConstants.colCorporateProgramId,
          ]) {
            await db.execute(
              'ALTER TABLE ${DbConstants.tableTrees} ADD COLUMN $column TEXT',
            );
          }
        default:
          break;
      }
    }
  }

  // ── Table creation ────────────────────────────────────────────────────────

  Future<void> _createTables(Database db) async {
    final batch = db.batch();

    // ── plots ──────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.tablePlots} (
        ${DbConstants.colId}                  TEXT PRIMARY KEY,
        ${DbConstants.colServerId}            TEXT,
        ${DbConstants.colName}                TEXT NOT NULL,
        ${DbConstants.colLocation}            TEXT NOT NULL,
        ${DbConstants.colRegionName}          TEXT,
        ${DbConstants.colDistrict}            TEXT,
        ${DbConstants.colLatitude}            REAL,
        ${DbConstants.colLongitude}           REAL,
        ${DbConstants.colAreaHectares}        REAL,
        ${DbConstants.colTreeCount}           INTEGER NOT NULL DEFAULT 0,
        ${DbConstants.colStatus}              TEXT NOT NULL DEFAULT 'healthy',
        ${DbConstants.colAssignedVolunteerId} TEXT,
        ${DbConstants.colSyncStatus}          TEXT NOT NULL DEFAULT 'synced',
        ${DbConstants.colCreatedAt}           INTEGER NOT NULL,
        ${DbConstants.colUpdatedAt}           INTEGER NOT NULL,
        ${DbConstants.colSyncedAt}            INTEGER
      )
    ''');

    // ── workers ────────────────────────────────────────────────────────────
    batch.execute(_workersCreateSql());
    batch.execute(_workerPlotAssignmentsCreateSql());

    // ── tree_tasks ─────────────────────────────────────────────────────────
    batch.execute(_treeTasksCreateSql());
    batch.execute(_treeGrowthUpdatesCreateSql());

    // ── trees ──────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.tableTrees} (
        ${DbConstants.colId}              TEXT PRIMARY KEY,
        ${DbConstants.colServerId}        TEXT,
        ${DbConstants.colWorkerId}        TEXT,
        ${DbConstants.colSpecies}         TEXT,
        ${DbConstants.colPlantingDate}    INTEGER,
        ${DbConstants.colPlotId}          TEXT NOT NULL,
        ${DbConstants.colPlotName}        TEXT,
        ${DbConstants.colSponsorshipCategory} TEXT,
        ${DbConstants.colCorporateProgramId} TEXT,
        ${DbConstants.colRegionName}      TEXT,
        ${DbConstants.colPlantedBy}       TEXT,
        ${DbConstants.colPlantedById}     TEXT,
        ${DbConstants.colBatch}           TEXT,
        ${DbConstants.colSaplingSource}   TEXT,
        ${DbConstants.colLatitude}        REAL NOT NULL,
        ${DbConstants.colLongitude}       REAL NOT NULL,
        ${DbConstants.colGpsAccuracy}     REAL,
        ${DbConstants.colNotes}           TEXT,
        ${DbConstants.colIsDead}          INTEGER NOT NULL DEFAULT 0,
        ${DbConstants.colReplacementForId} TEXT,
        ${DbConstants.colSyncStatus}      TEXT NOT NULL DEFAULT 'pending',
        ${DbConstants.colRetryCount}      INTEGER NOT NULL DEFAULT 0,
        ${DbConstants.colLastError}       TEXT,
        ${DbConstants.colCreatedAt}       INTEGER NOT NULL,
        ${DbConstants.colUpdatedAt}       INTEGER NOT NULL,
        ${DbConstants.colSyncedAt}        INTEGER,
        FOREIGN KEY (${DbConstants.colPlotId})
          REFERENCES ${DbConstants.tablePlots}(${DbConstants.colId})
      )
    ''');

    // ── inspections ────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.tableInspections} (
        ${DbConstants.colId}              TEXT PRIMARY KEY,
        ${DbConstants.colServerId}        TEXT,
        ${DbConstants.colTreeId}          TEXT NOT NULL,
        ${DbConstants.colGbhCm}           REAL,
        ${DbConstants.colHeightM}         REAL,
        ${DbConstants.colSurvivalStatus}  TEXT,
        ${DbConstants.colHealthRating}    INTEGER,
        ${DbConstants.colPestNotes}       TEXT,
        ${DbConstants.colDiseaseNotes}    TEXT,
        ${DbConstants.colNotes}           TEXT,
        ${DbConstants.colLatitude}        REAL,
        ${DbConstants.colLongitude}       REAL,
        ${DbConstants.colGpsAccuracy}     REAL,
        ${DbConstants.colInspectedAt}     INTEGER NOT NULL,
        ${DbConstants.colSyncStatus}      TEXT NOT NULL DEFAULT 'pending',
        ${DbConstants.colRetryCount}      INTEGER NOT NULL DEFAULT 0,
        ${DbConstants.colLastError}       TEXT,
        ${DbConstants.colCreatedAt}       INTEGER NOT NULL,
        ${DbConstants.colUpdatedAt}       INTEGER NOT NULL,
        ${DbConstants.colSyncedAt}        INTEGER,
        FOREIGN KEY (${DbConstants.colTreeId})
          REFERENCES ${DbConstants.tableTrees}(${DbConstants.colId})
      )
    ''');

    // ── photos ─────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.tablePhotos} (
        ${DbConstants.colId}              TEXT PRIMARY KEY,
        ${DbConstants.colServerId}        TEXT,
        ${DbConstants.colTreeId}          TEXT,
        ${DbConstants.colInspectionId}    TEXT,
        ${DbConstants.colLocalPath}       TEXT NOT NULL,
        ${DbConstants.colFileSizeBytes}   INTEGER,
        ${DbConstants.colLatitude}        REAL,
        ${DbConstants.colLongitude}       REAL,
        ${DbConstants.colTakenAt}         INTEGER NOT NULL,
        ${DbConstants.colSyncStatus}      TEXT NOT NULL DEFAULT 'pending',
        ${DbConstants.colRetryCount}      INTEGER NOT NULL DEFAULT 0,
        ${DbConstants.colLastError}       TEXT,
        ${DbConstants.colCreatedAt}       INTEGER NOT NULL,
        ${DbConstants.colUpdatedAt}       INTEGER NOT NULL,
        ${DbConstants.colSyncedAt}        INTEGER
      )
    ''');

    // ── sync_queue ─────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.tableSyncQueue} (
        ${DbConstants.colId}          TEXT PRIMARY KEY,
        ${DbConstants.colEntityType}  TEXT NOT NULL,
        ${DbConstants.colEntityId}    TEXT NOT NULL,
        ${DbConstants.colOperation}   TEXT NOT NULL,
        ${DbConstants.colPayload}     TEXT,
        ${DbConstants.colSyncStatus}  TEXT NOT NULL DEFAULT 'pending',
        ${DbConstants.colRetryCount}  INTEGER NOT NULL DEFAULT 0,
        ${DbConstants.colLastError}   TEXT,
        ${DbConstants.colCreatedAt}   INTEGER NOT NULL,
        ${DbConstants.colUpdatedAt}   INTEGER NOT NULL,
        ${DbConstants.colSyncedAt}    INTEGER
      )
    ''');

    batch.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_queue_entity
        ON ${DbConstants.tableSyncQueue}
        (${DbConstants.colEntityType}, ${DbConstants.colEntityId},
         ${DbConstants.colOperation})
    ''');

    // ── sync_meta ──────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.tableSyncMeta} (
        ${DbConstants.colKey}       TEXT PRIMARY KEY,
        ${DbConstants.colValue}     TEXT,
        ${DbConstants.colUpdatedAt} INTEGER NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> _createWorkersTable(Database db) async {
    await db.execute(_workersCreateSql());
  }

  Future<void> _createTreeTasksTable(Database db) async {
    await db.execute(_treeTasksCreateSql());
  }

  String _treeTasksCreateSql() =>
      '''
    CREATE TABLE IF NOT EXISTS ${DbConstants.tableTreeTasks} (
      ${DbConstants.colId}            TEXT PRIMARY KEY,
      ${DbConstants.colServerId}      TEXT,
      ${DbConstants.colPlotId}        TEXT NOT NULL,
      ${DbConstants.colPlotName}      TEXT,
      ${DbConstants.colSpecies}       TEXT NOT NULL,
      ${DbConstants.colLatitude}      REAL NOT NULL,
      ${DbConstants.colLongitude}     REAL NOT NULL,
      ${DbConstants.colNotes}         TEXT,
      ${DbConstants.colAdminNotes}    TEXT,
      ${DbConstants.colSponsorIntent} TEXT,
      ${DbConstants.colProgramName}   TEXT,
      ${DbConstants.colTargetDate}    INTEGER,
      ${DbConstants.colVolunteerId}   TEXT,
      ${DbConstants.colWorkerId}      TEXT,
      ${DbConstants.colWorkerName}    TEXT,
      ${DbConstants.colPhotoPath}     TEXT,
      ${DbConstants.colTreeId}        TEXT,
      ${DbConstants.colRegionId}      TEXT,
      ${DbConstants.colRegionName}    TEXT,
      ${DbConstants.colSponsorshipId} TEXT,
      ${DbConstants.colTaskStatus}    TEXT NOT NULL DEFAULT 'pending',
      ${DbConstants.colSyncStatus}    TEXT NOT NULL DEFAULT 'synced',
      ${DbConstants.colRetryCount}    INTEGER NOT NULL DEFAULT 0,
      ${DbConstants.colLastError}     TEXT,
      ${DbConstants.colCreatedAt}     INTEGER NOT NULL,
      ${DbConstants.colUpdatedAt}     INTEGER NOT NULL,
      ${DbConstants.colSyncedAt}      INTEGER
    )
  ''';

  String _workerPlotAssignmentsCreateSql() =>
      '''
    CREATE TABLE IF NOT EXISTS ${DbConstants.tableWorkerPlotAssignments} (
      ${DbConstants.colId}        TEXT PRIMARY KEY,
      ${DbConstants.colWorkerId}  TEXT NOT NULL,
      ${DbConstants.colPlotId}    TEXT NOT NULL,
      ${DbConstants.colAssignedAt} INTEGER NOT NULL,
      UNIQUE(${DbConstants.colWorkerId}, ${DbConstants.colPlotId})
    )
  ''';

  Future<void> _createWorkerPlotAssignmentsTable(Database db) async {
    await db.execute(_workerPlotAssignmentsCreateSql());
  }

  String _workersCreateSql() =>
      '''
    CREATE TABLE IF NOT EXISTS ${DbConstants.tableWorkers} (
      ${DbConstants.colId}          TEXT PRIMARY KEY,
      ${DbConstants.colServerId}    TEXT,
      ${DbConstants.colName}        TEXT NOT NULL,
      ${DbConstants.colPhone}       TEXT,
      ${DbConstants.colPhotoPath}   TEXT,
      ${DbConstants.colVolunteerId} TEXT,
      ${DbConstants.colIsActive}    INTEGER NOT NULL DEFAULT 1,
      ${DbConstants.colSyncStatus}  TEXT NOT NULL DEFAULT 'pending',
      ${DbConstants.colRetryCount}  INTEGER NOT NULL DEFAULT 0,
      ${DbConstants.colLastError}   TEXT,
      ${DbConstants.colCreatedAt}   INTEGER NOT NULL,
      ${DbConstants.colUpdatedAt}   INTEGER NOT NULL,
      ${DbConstants.colSyncedAt}    INTEGER
    )
  ''';

  Future<void> _createTreeGrowthUpdatesTable(Database db) async {
    await db.execute(_treeGrowthUpdatesCreateSql());
  }

  String _treeGrowthUpdatesCreateSql() =>
      '''
    CREATE TABLE IF NOT EXISTS ${DbConstants.tableTreeGrowthUpdates} (
      ${DbConstants.colId}          TEXT PRIMARY KEY,
      ${DbConstants.colTreeId}      TEXT NOT NULL,
      ${DbConstants.colGrowthStage} TEXT NOT NULL DEFAULT 'planted',
      ${DbConstants.colHeightCm}    REAL,
      ${DbConstants.colNotes}       TEXT,
      ${DbConstants.colPhotoPath}   TEXT,
      ${DbConstants.colRecordedBy}  TEXT,
      ${DbConstants.colRecordedAt}  INTEGER NOT NULL,
      ${DbConstants.colSyncStatus}  TEXT NOT NULL DEFAULT 'pending',
      ${DbConstants.colRetryCount}  INTEGER NOT NULL DEFAULT 0,
      ${DbConstants.colLastError}   TEXT,
      ${DbConstants.colCreatedAt}   INTEGER NOT NULL,
      ${DbConstants.colUpdatedAt}   INTEGER NOT NULL
    )
  ''';

  // ── Seed data (first install only) ───────────────────────────────────────

  Future<void> _seedSampleData(Database db) async {
    // Plots/workers/tasks come from GET /field/sync after login — do not
    // insert offline demo plots that would mix with admin Postgres data.
    await _seedAuthCredentials(db);
  }

  /// Known offline-demo plot IDs shipped in older app builds.
  static const _demoSeedPlotIds = ['PLT-104', 'PLT-097', 'PLT-088'];

  /// Removes legacy SQLite demo plots and rows that reference them.
  Future<void> _purgeDemoSeedPlots(Database db) async {
    final placeholders = List.filled(_demoSeedPlotIds.length, '?').join(',');
    final args = _demoSeedPlotIds;

    await db.delete(
      DbConstants.tableWorkerPlotAssignments,
      where: '${DbConstants.colPlotId} IN ($placeholders)',
      whereArgs: args,
    );
    await db.delete(
      DbConstants.tableTreeTasks,
      where: '${DbConstants.colPlotId} IN ($placeholders)',
      whereArgs: args,
    );
    await db.rawDelete('''
      DELETE FROM ${DbConstants.tableTreeGrowthUpdates}
       WHERE ${DbConstants.colTreeId} IN (
         SELECT ${DbConstants.colId} FROM ${DbConstants.tableTrees}
          WHERE ${DbConstants.colPlotId} IN ($placeholders)
       )
      ''', args);
    await db.delete(
      DbConstants.tableTrees,
      where: '${DbConstants.colPlotId} IN ($placeholders)',
      whereArgs: args,
    );
    await db.delete(
      DbConstants.tablePlots,
      where: '${DbConstants.colId} IN ($placeholders)',
      whereArgs: args,
    );
    AppLogger.request(
      '[AppDatabase] purged demo seed plots: ${_demoSeedPlotIds.join(", ")}',
    );
  }

  /// Seeds volunteer login credentials and the worker access code into
  /// sync_meta. In production these arrive from the admin panel via sync.
  Future<void> _seedAuthCredentials(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = [
      (DbConstants.metaKeyAuthVolEmail, 'volunteer@omyearth.in'),
      (DbConstants.metaKeyAuthVolPassword, 'OmyVol@2026'),
      (DbConstants.metaKeyAuthVolCode, 'OMY-2026'),
      (DbConstants.metaKeyAuthVolName, 'Field Volunteer'),
      (DbConstants.metaKeyAuthVolId, 'VOL-001'),
    ];

    final batch = db.batch();
    for (final (key, value) in entries) {
      batch.insert(DbConstants.tableSyncMeta, {
        DbConstants.colKey: key,
        DbConstants.colValue: value,
        DbConstants.colUpdatedAt: now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _seedSampleWorkers(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    final workers = [
      {
        DbConstants.colId: 'WORKER-001',
        DbConstants.colName: 'Rajan P',
        DbConstants.colPhone: '97461 23456',
        DbConstants.colVolunteerId: 'VOL-001',
        DbConstants.colIsActive: 1,
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: now,
        DbConstants.colUpdatedAt: now,
        DbConstants.colSyncedAt: now,
      },
      {
        DbConstants.colId: 'WORKER-002',
        DbConstants.colName: 'Suresh K',
        DbConstants.colPhone: '98456 78901',
        DbConstants.colVolunteerId: 'VOL-001',
        DbConstants.colIsActive: 1,
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: now,
        DbConstants.colUpdatedAt: now,
        DbConstants.colSyncedAt: now,
      },
      {
        DbConstants.colId: 'WORKER-003',
        DbConstants.colName: 'Mohan V',
        DbConstants.colPhone: '70345 67890',
        DbConstants.colVolunteerId: 'VOL-001',
        DbConstants.colIsActive: 1,
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: now,
        DbConstants.colUpdatedAt: now,
        DbConstants.colSyncedAt: now,
      },
    ];

    for (final worker in workers) {
      batch.insert(
        DbConstants.tableWorkers,
        worker,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _seedSamplePlotAssignments(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    final assignments = [
      ('WORKER-001', 'PLT-104'),
      ('WORKER-001', 'PLT-097'),
      ('WORKER-002', 'PLT-097'),
      ('WORKER-003', 'PLT-088'),
    ];
    for (final (workerId, plotId) in assignments) {
      batch.insert(DbConstants.tableWorkerPlotAssignments, {
        DbConstants.colId: '$workerId-$plotId',
        DbConstants.colWorkerId: workerId,
        DbConstants.colPlotId: plotId,
        DbConstants.colAssignedAt: now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  /// Seeds a few trees *registered today* so the dashboard shows
  /// realistic per-worker activity on first launch.
  Future<void> _seedSampleTrees(Database db) async {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day, 8);
    final plantedDaysAgo = today.subtract(const Duration(days: 18));
    final batch = db.batch();

    // Rajan P (WORKER-001) — 5 trees in PLT-104
    for (var i = 0; i < 5; i++) {
      final ts = base.add(Duration(minutes: i * 18)).millisecondsSinceEpoch;
      final plantedAt = plantedDaysAgo
          .add(Duration(days: i))
          .millisecondsSinceEpoch;
      batch.insert(DbConstants.tableTrees, {
        DbConstants.colId: 'SEED-TREE-W1-$i',
        DbConstants.colWorkerId: 'WORKER-001',
        DbConstants.colPlotId: 'PLT-104',
        DbConstants.colSpecies: 'Teak',
        DbConstants.colPlantingDate: plantedAt,
        DbConstants.colLatitude: 11.5129 + i * 0.0001,
        DbConstants.colLongitude: 76.0818 + i * 0.0001,
        DbConstants.colNotes: i == 0 ? 'Healthy sapling near east fence' : null,
        DbConstants.colIsDead: 0,
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: ts,
        DbConstants.colUpdatedAt: ts,
        DbConstants.colSyncedAt: ts,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Suresh K (WORKER-002) — 3 trees in PLT-097
    for (var i = 0; i < 3; i++) {
      final ts = base
          .add(Duration(minutes: 60 + i * 22))
          .millisecondsSinceEpoch;
      final plantedAt = plantedDaysAgo
          .add(Duration(days: 3 + i * 2))
          .millisecondsSinceEpoch;
      batch.insert(DbConstants.tableTrees, {
        DbConstants.colId: 'SEED-TREE-W2-$i',
        DbConstants.colWorkerId: 'WORKER-002',
        DbConstants.colPlotId: 'PLT-097',
        DbConstants.colSpecies: 'Rosewood',
        DbConstants.colPlantingDate: plantedAt,
        DbConstants.colLatitude: 11.6068 + i * 0.0001,
        DbConstants.colLongitude: 76.0836 + i * 0.0001,
        DbConstants.colNotes: i == 1 ? 'Mulched after planting' : null,
        DbConstants.colIsDead: 0,
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: ts,
        DbConstants.colUpdatedAt: ts,
        DbConstants.colSyncedAt: ts,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Mohan V (WORKER-003) — 2 trees in PLT-088
    for (var i = 0; i < 2; i++) {
      final ts = base
          .add(Duration(minutes: 120 + i * 15))
          .millisecondsSinceEpoch;
      final plantedAt = plantedDaysAgo
          .add(Duration(days: 8 + i))
          .millisecondsSinceEpoch;
      batch.insert(DbConstants.tableTrees, {
        DbConstants.colId: 'SEED-TREE-W3-$i',
        DbConstants.colWorkerId: 'WORKER-003',
        DbConstants.colPlotId: 'PLT-088',
        DbConstants.colSpecies: 'Bamboo',
        DbConstants.colPlantingDate: plantedAt,
        DbConstants.colLatitude: 10.0889 + i * 0.0001,
        DbConstants.colLongitude: 77.0595 + i * 0.0001,
        DbConstants.colIsDead: 0,
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: ts,
        DbConstants.colUpdatedAt: ts,
        DbConstants.colSyncedAt: ts,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await batch.commit(noResult: true);
  }

  /// Tiny solid-color PNGs used as sample field photos (1×1, stretches cleanly).
  static const _samplePhotoGreen =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
  static const _samplePhotoLeaf =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPj/HwADBwIAMCbHYQAAAABJRU5ErkJggg==';
  static const _samplePhotoEarth =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
  static const _samplePhotoSun =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=';

  Future<String> _writeSamplePhoto(String fileName, String base64Png) async {
    if (kIsWeb) {
      return 'data:image/png;base64,$base64Png';
    }

    return writeSamplePhotoFile(fileName, base64Decode(base64Png));
  }

  /// Seeds growth-stage updates (with photos) so admin volunteers can review
  /// field activity on first launch / upgrade.
  Future<void> _seedSampleGrowthUpdates(Database db) async {
    final green = await _writeSamplePhoto('teak_green.png', _samplePhotoGreen);
    final leaf = await _writeSamplePhoto('teak_leaf.png', _samplePhotoLeaf);
    final earth = await _writeSamplePhoto(
      'rosewood_earth.png',
      _samplePhotoEarth,
    );
    final sun = await _writeSamplePhoto('bamboo_sun.png', _samplePhotoSun);

    final now = DateTime.now();
    final batch = db.batch();

    void addUpdate({
      required String id,
      required String treeId,
      required String workerId,
      required String stage,
      required int daysAgo,
      double? heightCm,
      String? notes,
      String? photoPath,
    }) {
      final recordedAt = now.subtract(Duration(days: daysAgo, hours: daysAgo));
      final ms = recordedAt.millisecondsSinceEpoch;
      batch.insert(DbConstants.tableTreeGrowthUpdates, {
        DbConstants.colId: id,
        DbConstants.colTreeId: treeId,
        DbConstants.colGrowthStage: stage,
        DbConstants.colHeightCm: heightCm,
        DbConstants.colNotes: notes,
        DbConstants.colPhotoPath: photoPath,
        DbConstants.colRecordedBy: workerId,
        DbConstants.colRecordedAt: ms,
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: ms,
        DbConstants.colUpdatedAt: ms,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Rajan — Teak trees
    addUpdate(
      id: 'GROWTH-W1-0-1',
      treeId: 'SEED-TREE-W1-0',
      workerId: 'WORKER-001',
      stage: 'planted',
      daysAgo: 18,
      heightCm: 28,
      notes: 'Planted with compost mix',
      photoPath: green,
    );
    addUpdate(
      id: 'GROWTH-W1-0-2',
      treeId: 'SEED-TREE-W1-0',
      workerId: 'WORKER-001',
      stage: 'sprouting',
      daysAgo: 10,
      heightCm: 34,
      notes: 'New leaves visible',
      photoPath: leaf,
    );
    addUpdate(
      id: 'GROWTH-W1-0-3',
      treeId: 'SEED-TREE-W1-0',
      workerId: 'WORKER-001',
      stage: 'growing',
      daysAgo: 2,
      heightCm: 42,
      notes: 'Strong growth after rain',
      photoPath: green,
    );
    addUpdate(
      id: 'GROWTH-W1-1-1',
      treeId: 'SEED-TREE-W1-1',
      workerId: 'WORKER-001',
      stage: 'planted',
      daysAgo: 15,
      heightCm: 26,
      photoPath: earth,
    );
    addUpdate(
      id: 'GROWTH-W1-1-2',
      treeId: 'SEED-TREE-W1-1',
      workerId: 'WORKER-001',
      stage: 'growing',
      daysAgo: 4,
      heightCm: 38,
      notes: 'Watered twice this week',
      photoPath: leaf,
    );
    addUpdate(
      id: 'GROWTH-W1-2-1',
      treeId: 'SEED-TREE-W1-2',
      workerId: 'WORKER-001',
      stage: 'planted',
      daysAgo: 12,
      heightCm: 24,
      photoPath: green,
    );
    addUpdate(
      id: 'GROWTH-W1-2-2',
      treeId: 'SEED-TREE-W1-2',
      workerId: 'WORKER-001',
      stage: 'needs_attention',
      daysAgo: 1,
      heightCm: 25,
      notes: 'Yellow leaves — possible pest',
      photoPath: sun,
    );

    // Suresh — Rosewood trees
    addUpdate(
      id: 'GROWTH-W2-0-1',
      treeId: 'SEED-TREE-W2-0',
      workerId: 'WORKER-002',
      stage: 'planted',
      daysAgo: 14,
      heightCm: 30,
      notes: 'Planted on contour line',
      photoPath: earth,
    );
    addUpdate(
      id: 'GROWTH-W2-0-2',
      treeId: 'SEED-TREE-W2-0',
      workerId: 'WORKER-002',
      stage: 'sprouting',
      daysAgo: 7,
      heightCm: 35,
      photoPath: leaf,
    );
    addUpdate(
      id: 'GROWTH-W2-0-3',
      treeId: 'SEED-TREE-W2-0',
      workerId: 'WORKER-002',
      stage: 'growing',
      daysAgo: 1,
      heightCm: 41,
      notes: 'Looking healthy',
      photoPath: green,
    );
    addUpdate(
      id: 'GROWTH-W2-1-1',
      treeId: 'SEED-TREE-W2-1',
      workerId: 'WORKER-002',
      stage: 'planted',
      daysAgo: 11,
      heightCm: 29,
      photoPath: earth,
    );
    addUpdate(
      id: 'GROWTH-W2-1-2',
      treeId: 'SEED-TREE-W2-1',
      workerId: 'WORKER-002',
      stage: 'established',
      daysAgo: 3,
      heightCm: 48,
      notes: 'Well established, mulched',
      photoPath: sun,
    );

    // Mohan — Bamboo
    addUpdate(
      id: 'GROWTH-W3-0-1',
      treeId: 'SEED-TREE-W3-0',
      workerId: 'WORKER-003',
      stage: 'planted',
      daysAgo: 9,
      heightCm: 45,
      photoPath: sun,
    );
    addUpdate(
      id: 'GROWTH-W3-0-2',
      treeId: 'SEED-TREE-W3-0',
      workerId: 'WORKER-003',
      stage: 'growing',
      daysAgo: 2,
      heightCm: 58,
      notes: 'Cluster sprouting well',
      photoPath: leaf,
    );
    addUpdate(
      id: 'GROWTH-W3-1-1',
      treeId: 'SEED-TREE-W3-1',
      workerId: 'WORKER-003',
      stage: 'planted',
      daysAgo: 8,
      heightCm: 40,
      photoPath: green,
    );

    await batch.commit(noResult: true);
  }

  /// Seeds admin-assigned planting tasks that the volunteer must act on.
  /// Covers all four [TaskStatus] values so the UI shows a realistic
  /// mix of states on first launch.
  Future<void> _seedTreeTasks(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final nextWeek = DateTime.now().add(const Duration(days: 7));

    final tasks = [
      // Pending — no worker assigned yet
      {
        DbConstants.colId: 'TASK-001',
        DbConstants.colServerId: 'TASK-001',
        DbConstants.colPlotId: 'PLT-104',
        DbConstants.colSpecies: 'Teak',
        DbConstants.colLatitude: 11.5131,
        DbConstants.colLongitude: 76.0821,
        DbConstants.colAdminNotes:
            'Plant near the eastern boundary. Ensure 2m spacing.',
        DbConstants.colTargetDate: tomorrow.millisecondsSinceEpoch,
        DbConstants.colVolunteerId: 'VOL-001',
        DbConstants.colWorkerId: null,
        DbConstants.colTaskStatus: 'pending',
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: now,
        DbConstants.colUpdatedAt: now,
        DbConstants.colSyncedAt: now,
      },
      {
        DbConstants.colId: 'TASK-002',
        DbConstants.colServerId: 'TASK-002',
        DbConstants.colPlotId: 'PLT-097',
        DbConstants.colSpecies: 'Rosewood',
        DbConstants.colLatitude: 11.6071,
        DbConstants.colLongitude: 76.0839,
        DbConstants.colAdminNotes:
            'High priority. Replaces dead sapling from batch B-12.',
        DbConstants.colTargetDate: tomorrow.millisecondsSinceEpoch,
        DbConstants.colVolunteerId: 'VOL-001',
        DbConstants.colWorkerId: null,
        DbConstants.colTaskStatus: 'pending',
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: now,
        DbConstants.colUpdatedAt: now,
        DbConstants.colSyncedAt: now,
      },
      {
        DbConstants.colId: 'TASK-003',
        DbConstants.colServerId: 'TASK-003',
        DbConstants.colPlotId: 'PLT-088',
        DbConstants.colSpecies: 'Bamboo',
        DbConstants.colLatitude: 10.0892,
        DbConstants.colLongitude: 77.0598,
        DbConstants.colAdminNotes: 'Cluster planting, 5 stems per hole.',
        DbConstants.colTargetDate: nextWeek.millisecondsSinceEpoch,
        DbConstants.colVolunteerId: 'VOL-001',
        DbConstants.colWorkerId: null,
        DbConstants.colTaskStatus: 'pending',
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: now,
        DbConstants.colUpdatedAt: now,
        DbConstants.colSyncedAt: now,
      },
      // Assigned — worker set, not yet planted
      {
        DbConstants.colId: 'TASK-004',
        DbConstants.colServerId: 'TASK-004',
        DbConstants.colPlotId: 'PLT-104',
        DbConstants.colSpecies: 'Mahogany',
        DbConstants.colLatitude: 11.5133,
        DbConstants.colLongitude: 76.0823,
        DbConstants.colAdminNotes: null,
        DbConstants.colTargetDate: tomorrow.millisecondsSinceEpoch,
        DbConstants.colVolunteerId: 'VOL-001',
        DbConstants.colWorkerId: 'WORKER-001',
        DbConstants.colTaskStatus: 'assigned',
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: now,
        DbConstants.colUpdatedAt: now,
        DbConstants.colSyncedAt: now,
      },
      {
        DbConstants.colId: 'TASK-005',
        DbConstants.colServerId: 'TASK-005',
        DbConstants.colPlotId: 'PLT-097',
        DbConstants.colSpecies: 'Jackfruit',
        DbConstants.colLatitude: 11.6073,
        DbConstants.colLongitude: 76.0841,
        DbConstants.colAdminNotes: 'Near stream edge. Dig 60cm pit.',
        DbConstants.colTargetDate: nextWeek.millisecondsSinceEpoch,
        DbConstants.colVolunteerId: 'VOL-001',
        DbConstants.colWorkerId: 'WORKER-002',
        DbConstants.colTaskStatus: 'assigned',
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: now,
        DbConstants.colUpdatedAt: now,
        DbConstants.colSyncedAt: now,
      },
      // Planted — completed
      {
        DbConstants.colId: 'TASK-006',
        DbConstants.colServerId: 'TASK-006',
        DbConstants.colPlotId: 'PLT-088',
        DbConstants.colSpecies: 'Mango',
        DbConstants.colLatitude: 10.0894,
        DbConstants.colLongitude: 77.0600,
        DbConstants.colAdminNotes: null,
        DbConstants.colTargetDate: now - 86400000,
        DbConstants.colVolunteerId: 'VOL-001',
        DbConstants.colWorkerId: 'WORKER-001',
        DbConstants.colTaskStatus: 'planted',
        DbConstants.colSyncStatus: 'synced',
        DbConstants.colRetryCount: 0,
        DbConstants.colCreatedAt: now,
        DbConstants.colUpdatedAt: now,
        DbConstants.colSyncedAt: now,
      },
    ];

    final batch = db.batch();
    for (final task in tasks) {
      batch.insert(
        DbConstants.tableTreeTasks,
        task,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }
}
