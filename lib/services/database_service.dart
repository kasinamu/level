import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static const _dbName = 'survey.db';
  static const _dbVersion = 1;

  // Reference Points Table
  static const tableReferencePoints = 'reference_points';
  static const colId = 'id';
  static const colName = 'name';
  static const colPhotoPath = 'photoPath';
  static const colCreatedAt = 'createdAt';

  // Survey Sessions Table
  static const tableSurveySessions = 'survey_sessions';
  static const colSessionId = 'id';
  static const colSessionTitle = 'title';
  static const colSessionInstrumentHeight = 'instrumentHeight';
  static const colSessionStartPointNum = 'startPointNum';
  static const colSessionEndPointNum = 'endPointNum';
  static const colSessionOffsetDirection = 'offsetDirection';
  static const colSessionPhase = 'phase';
  static const colSessionCurrentIndex = 'currentIndex';
  static const colSessionObservedReadings = 'observedReadings';
  static const colSessionCompletedPoints = 'completedPoints';
  static const colSessionUpdatedAt = 'updatedAt';

  // Main Points Table
  static const tableMainPoints = 'main_points';
  static const colPointId = 'id';
  static const colPointSessionId = 'sessionId'; // Foreign Key
  static const colPointName = 'name';
  static const colPointStation = 'station';
  static const colPointOffsetDistance = 'offsetDistance';
  static const colPointOffsetDirection = 'offsetDirection';
  static const colPointExcavationLevel = 'excavationLevel';


  // Singleton instance
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableReferencePoints (
        $colId TEXT PRIMARY KEY,
        $colName TEXT NOT NULL,
        $colPhotoPath TEXT NOT NULL,
        $colCreatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSurveySessions (
        $colSessionId TEXT PRIMARY KEY,
        $colSessionTitle TEXT NOT NULL,
        $colSessionInstrumentHeight REAL NOT NULL,
        $colSessionStartPointNum INTEGER NOT NULL,
        $colSessionEndPointNum INTEGER NOT NULL,
        $colSessionOffsetDirection TEXT NOT NULL,
        $colSessionPhase TEXT NOT NULL,
        $colSessionCurrentIndex INTEGER NOT NULL,
        $colSessionObservedReadings TEXT,
        $colSessionCompletedPoints TEXT,
        $colSessionUpdatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableMainPoints (
        $colPointId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colPointSessionId TEXT NOT NULL,
        $colPointName TEXT NOT NULL,
        $colPointStation REAL NOT NULL,
        $colPointOffsetDistance REAL NOT NULL,
        $colPointOffsetDirection TEXT NOT NULL,
        $colPointExcavationLevel REAL NOT NULL,
        FOREIGN KEY ($colPointSessionId) REFERENCES $tableSurveySessions ($colSessionId) ON DELETE CASCADE
      )
    ''');

    // Delete old json files if they exist
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final refFile = File(join(docDir.path, 'reference_points.json'));
      if (await refFile.exists()) {
        await refFile.delete();
      }
      final sessionFile = File(join(docDir.path, 'sessions.json'));
      if (await sessionFile.exists()) {
        await sessionFile.delete();
      }
    } catch (_) {
      // Ignore errors during cleanup
    }
  }
}
