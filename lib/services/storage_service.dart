import 'package:shared_preferences/shared_preferences.dart';

import '../models/survey_session.dart';

class StorageService {
  static const _sessionsKey = 'saved_sessions';

  static final Map<String, String> _memoryStore = {};
  static bool _useFallback = false;

  Future<SharedPreferences?> _prefsOrNull() async {
    if (_useFallback) return null;
    try {
      return await SharedPreferences.getInstance();
    } on Exception {
      _useFallback = true;
      return null;
    }
  }

  Future<String?> _readRaw() async {
    final prefs = await _prefsOrNull();
    if (prefs != null) {
      return prefs.getString(_sessionsKey);
    }
    return _memoryStore[_sessionsKey];
  }

  Future<void> _writeRaw(String value) async {
    final prefs = await _prefsOrNull();
    if (prefs != null) {
      await prefs.setString(_sessionsKey, value);
    } else {
      _memoryStore[_sessionsKey] = value;
    }
  }

  Future<List<SurveySession>> fetchSessions() async {
    final stored = await _readRaw();
    if (stored == null || stored.isEmpty) {
      return [];
    }
    try {
      return SurveySession.decodeList(stored);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSession(SurveySession session) async {
    final existing = await fetchSessions();
    final filtered = existing.where((s) => s.id != session.id).toList();
    filtered.add(session.copyWith(updatedAt: DateTime.now()));
    await _writeRaw(SurveySession.encodeList(filtered));
  }

  Future<void> deleteSession(String sessionId) async {
    final existing = await fetchSessions();
    final filtered = existing.where((s) => s.id != sessionId).toList();
    await _writeRaw(SurveySession.encodeList(filtered));
  }
}
