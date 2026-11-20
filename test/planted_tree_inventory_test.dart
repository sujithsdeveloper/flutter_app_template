import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mess_app/core/database/app_database.dart';
import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/data/models/sync_status.dart';
import 'package:mess_app/data/models/tree_model.dart';
import 'package:mess_app/data/repositories/tree_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfiNoIsolate, sqfliteFfiInit;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'planted tree sync groups records by plot and keeps local plantings',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final directory = await Directory.systemTemp.createTemp('omy-tree-test-');
      addTearDown(() => directory.delete(recursive: true));
      await databaseFactory.setDatabasesPath(directory.path);

      final database = AppDatabase.instance;
      await database.init();
      final db = await database.database;
      addTearDown(db.close);
      final repository = TreeRepository(db: database);
      final date = DateTime(2026, 1, 1);

      TreeModel tree(String id, String plot, {bool remote = false}) =>
          TreeModel(
            id: id,
            plotId: plot,
            plotName: plot == 'north' ? 'North Orchard' : 'South Orchard',
            regionName: plot == 'north' ? 'North Kerala' : 'South Kerala',
            plantedBy: remote ? 'Anu' : 'Local Planter',
            plantedById: remote ? 'field-admin' : 'worker',
            workerId: remote ? null : 'worker',
            latitude: 10,
            longitude: 76,
            plantingDate: date,
            createdAt: date,
            updatedAt: date,
            syncStatus: remote ? SyncStatus.synced : SyncStatus.pending,
            syncedAt: remote ? date : null,
          );

      await db.insert(DbConstants.tablePlots, {
        DbConstants.colId: 'north',
        DbConstants.colName: 'North Orchard',
        DbConstants.colRegionName: 'North Kerala',
        DbConstants.colLocation: 'North Orchard',
        DbConstants.colCreatedAt: date.millisecondsSinceEpoch,
        DbConstants.colUpdatedAt: date.millisecondsSinceEpoch,
      });
      await repository.insert(tree('local-tree', 'north'));
      await repository.insert(tree('outside-plot', 'outside'));
      final north = tree('north-tree', 'north', remote: true);
      await repository.applyFieldTrees([
        north,
        tree('south-tree', 'south', remote: true),
      ]);
      await repository.applyFieldTrees([north]);
      final trees = await repository.getByPlotId('north');

      expect(
        trees.map((tree) => tree.id),
        unorderedEquals(['local-tree', 'north-tree']),
      );
      expect(await repository.getByPlotId('south'), isEmpty);
      expect(
        (await repository.getFieldInventory()).map((tree) => tree.id),
        unorderedEquals(['local-tree', 'north-tree']),
      );
      final planted = trees.singleWhere((tree) => tree.id == 'north-tree');
      expect(planted.plotName, 'North Orchard');
      expect(planted.regionName, 'North Kerala');
      expect(planted.plantedBy, 'Anu');
      expect(planted.plantedById, 'field-admin');
    },
  );
}
