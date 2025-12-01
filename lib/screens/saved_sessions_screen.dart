import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
    _sessionsFuture = widget.storageService.getSavedSessions();
  }

  Future<void> _refresh() async {
    setState(() {
      _sessionsFuture = widget.storageService.getSavedSessions();
    });
  }

  Future<void> _delete(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 작업을 삭제하시겠습니까? 이 동작은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed ?? false) {
      await widget.storageService.deleteSession(sessionId);
      await _refresh();
    }
  }

  Future<void> _pickAndLoadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final session = await widget.storageService.loadSessionFromFile(file);
        if (mounted) {
          Navigator.pop(context, session);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일을 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
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
            return const Center(
              child: Text('저장된 작업이 없습니다.\n외부 파일을 불러오려면 아래 버튼을 누르세요.', textAlign: TextAlign.center),
            );
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
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _delete(session.id),
                  ),
                  onTap: () => Navigator.pop(context, session),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndLoadFile,
        label: const Text('파일에서 불러오기'),
        icon: const Icon(Icons.upload_file),
      ),
    );
  }
}
