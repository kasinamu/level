import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/reference_point.dart';
import 'database_service.dart';

class ReferencePointService {
  final _dbService = DatabaseService.instance;

  Future<Directory> _getBaseDir() => getApplicationDocumentsDirectory();

  Future<Directory> _getPhotosDir() async {
    final dir = Directory(p.join((await _getBaseDir()).path, 'reference_photos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<ReferencePoint>> fetchPoints() async {
    final db = await _dbService.database;
    final maps = await db.query(
      DatabaseService.tableReferencePoints,
      orderBy: '${DatabaseService.colCreatedAt} DESC',
    );
    return maps.map((map) => ReferencePoint.fromMap(map)).toList();
  }

  Future<ReferencePoint> addPoint({
    required String name,
    required File photoSource,
  }) async {
    final photosDir = await _getPhotosDir();
    final suffix = p.extension(photoSource.path.isEmpty ? '.jpg' : photoSource.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'ref_$timestamp$suffix';
    final destination = File(p.join(photosDir.path, filename));
    await photoSource.copy(destination.path);

    final newPoint = ReferencePoint(
      id: timestamp.toString(),
      name: name,
      photoPath: destination.path,
      createdAt: DateTime.now(),
    );

    final db = await _dbService.database;
    await db.insert(DatabaseService.tableReferencePoints, newPoint.toMap());
    return newPoint;
  }

  Future<void> deletePoint(ReferencePoint point) async {
    final db = await _dbService.database;
    await db.delete(
      DatabaseService.tableReferencePoints,
      where: '${DatabaseService.colId} = ?',
      whereArgs: [point.id],
    );

    final photoFile = File(point.photoPath);
    if (await photoFile.exists()) {
      await photoFile.delete();
    }
  }
}
