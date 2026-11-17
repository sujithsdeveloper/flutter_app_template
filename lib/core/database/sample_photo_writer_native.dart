import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<String> writeSamplePhotoFile(String fileName, Uint8List bytes) async {
  final root = await getDatabasesPath();
  final folder = Directory(p.join(root, 'sample_photos'));
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  final file = File(p.join(folder.path, fileName));
  if (!await file.exists()) {
    await file.writeAsBytes(bytes, flush: true);
  }
  return file.path;
}
