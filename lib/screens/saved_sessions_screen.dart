import 'package:flutter/material.dart';

import '../models/survey_session.dart';
import '../services/storage_service.dart';

class SavedSessionsScreen extends StatefulWidget {
  final StorageService storageService;

  const SavedSessionsScreen({super.key, required this.storageService});

  @override
  State<SavedSessionsScreen> createState() => _SavedSessionsScreenState();
}

class _SavedSessionsScreenState extends State<SavedSessionsScreen> {
  late Future<List<SurveySession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = widget.storageService.fetchSessions();
  }

  Future<void> _refresh() async {
    setState(() {
      _sessionsFuture = widget.storageService.fetchSessions();
    });
  }

  Future<void> _delete(String sessionId) async {
    await widget.storageService.deleteSession(sessionId);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('저장된 작업'),
      ),
      body: FutureBuilder<List<SurveySession>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return const Center(child: Text('저장된 작업이 없습니다.'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return ListTile(
                  title: Text(session.title),
                  subtitle: Text(
                      'No.${session.startPointNum}~No.${session.endPointNum} • ${session.updatedAt.toLocal()}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(session.id),
                  ),
                  onTap: () => Navigator.pop(context, session),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
