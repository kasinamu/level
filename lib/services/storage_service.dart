import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/survey_session.dart';
import '../models/survey_point.dart';
import 'database_service.dart';

class StorageService {
  final _dbService = DatabaseService.instance;

  Future<List<SurveySession>> getSavedSessions() async {
    final db = await _dbService.database;
    final List<SurveySession> sessions = [];

    final sessionMaps = await db.query(
      DatabaseService.tableSurveySessions,
      orderBy: '${DatabaseService.colSessionUpdatedAt} DESC',
    );

    for (final sessionMap in sessionMaps) {
      final pointMaps = await db.query(
        DatabaseService.tableMainPoints,
        where: '${DatabaseService.colPointSessionId} = ?',
        whereArgs: [sessionMap[DatabaseService.colSessionId]],
      );
      final points = pointMaps.map((p) => MainPoint.fromMap(p)).toList();
      sessions.add(SurveySession.fromMap(sessionMap, points));
    }

    return sessions;
  }

  Future<void> saveSession(SurveySession session) async {
    final db = await _dbService.database;
    final sessionToSave = session.copyWith(updatedAt: DateTime.now());

    await db.transaction((txn) async {
      // Upsert session
      await txn.insert(
        DatabaseService.tableSurveySessions,
        sessionToSave.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // Delete old points
      await txn.delete(
        DatabaseService.tableMainPoints,
        where: '${DatabaseService.colPointSessionId} = ?',
        whereArgs: [sessionToSave.id],
      );
      // Insert new points
      final batch = txn.batch();
      for (final point in sessionToSave.mainPoints) {
        batch.insert(
          DatabaseService.tableMainPoints,
          point.toMap(sessionToSave.id),
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await _dbService.database;
    await db.delete(
      DatabaseService.tableSurveySessions,
      where: '${DatabaseService.colSessionId} = ?',
      whereArgs: [sessionId],
    );
  }

  // This method is new, to handle loading from a user-picked file
  Future<SurveySession> loadSessionFromFile(File file) async {
    final content = await file.readAsString();
    final originalSession = SurveySession.fromJson(json.decode(content) as Map<String, dynamic>);

    // Create a new session with a new ID and updated timestamp to avoid conflicts
    final newSession = originalSession.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      updatedAt: DateTime.now(),
      title: '${originalSession.title} (가져옴)', // Add a suffix to indicate it's an import
    );

    await saveSession(newSession);
    return newSession;
  }
}
