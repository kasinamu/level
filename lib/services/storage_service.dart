import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/survey_session.dart';

class StorageService {
  Future<Directory> _getDirectory() async {
    return getApplicationDocumentsDirectory();
  }

  Future<File> _getFile(String sessionId) async {
    final dir = await _getDirectory();
    return File('${dir.path}/session_$sessionId.json');
  }

  Future<List<SurveySession>> fetchSessions() async {
    final dir = await _getDirectory();
    final List<SurveySession> sessions = [];

    // Check if directory exists
    if (!await dir.exists()) {
      return [];
    }

    final entities = dir.listSync();

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final session =
              SurveySession.fromJson(json.decode(content) as Map<String, dynamic>);
          sessions.add(session);
        } catch (e) {
          debugPrint('Error decoding session file: ${entity.path}, error: $e');
        }
      }
    }
    // Sort by most recently updated
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  Future<void> saveSession(SurveySession session) async {
    final file = await _getFile(session.id);
    final sessionToSave = session.copyWith(updatedAt: DateTime.now());
    await file.writeAsString(json.encode(sessionToSave.toJson()));
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      final file = await _getFile(sessionId);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting session: $e');
    }
  }

  // This method is new, to handle loading from a user-picked file
  Future<SurveySession> loadSessionFromFile(File file) async {
    final content = await file.readAsString();
    return SurveySession.fromJson(json.decode(content) as Map<String, dynamic>);
  }
}
