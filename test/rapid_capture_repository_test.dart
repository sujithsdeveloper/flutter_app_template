import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mess_app/core/database/app_database.dart';
import 'package:mess_app/data/repositories/rapid_capture_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfiNoIsolate, sqfliteFfiInit;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'rapid captures retain offline images across runs until each photo is acknowledged',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final directory = await Directory.systemTemp.createTemp(
        'omy-rapid-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await databaseFactory.setDatabasesPath(directory.path);
      final database = AppDatabase.instance;
      await database.init();
      final connection = await database.database;
      addTearDown(connection.close);
      final repository = RapidCaptureRepository(database);
      final photo = Uint8List.fromList([1, 2, 3, 4]);

      await repository.addRun(
        'account',
        'batch',
        'first',
        '2026-11-20T10:00:00.000Z',
      );
      await repository.addTree('first', {
        'id': 'tree-a',
        'captured_at': '2026-11-20T10:01:00.000Z',
        'notes': 'GPS unavailable',
      }, photo);
      await repository.changeState('first', 'paused');
      expect(await repository.runState('first'), 'paused');
      await repository.changeState('first', 'finished');
      await repository.addRun(
        'account',
        'batch',
        'second',
        '2026-11-20T10:02:00.000Z',
      );
      await repository.addTree('second', {
        'id': 'tree-b',
        'captured_at': '2026-11-20T10:03:00.000Z',
        'lat': 10.5,
        'lng': 76.2,
      }, photo);

      final reopened = RapidCaptureRepository(database);
      expect((await reopened.latestRun('account', 'batch'))?['id'], 'second');
      expect(await reopened.pendingCounts('other', 'batch'), (0, 0));
      expect(await reopened.pendingCounts('account', 'batch'), (2, 2));
      expect(
        (await reopened.runsToSync('account', 'batch')).map((run) => run['id']),
        ['first', 'second'],
      );
      expect(await reopened.photo('tree-a'), photo);

      await reopened.markTreeSynced('tree-a');
      await reopened.markFinishedSynced('first');
      expect(await reopened.pendingCounts('account', 'batch'), (1, 2));
      expect(await reopened.photo('tree-a'), photo);

      await reopened.markPhotoSynced('tree-a');
      expect(await reopened.photo('tree-a'), isNull);
      expect(await reopened.pendingCounts('account', 'batch'), (1, 1));
      expect(
        (await reopened.runsToSync('account', 'batch')).single['id'],
        'second',
      );
      expect(await reopened.photo('tree-b'), photo);
    },
  );
}
