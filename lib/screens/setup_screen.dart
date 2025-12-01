import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/survey_point.dart';
import '../models/survey_session.dart';
import '../services/storage_service.dart';
import 'data_entry_screen.dart';
import 'saved_sessions_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ihController = TextEditingController();
  final _startPointController = TextEditingController();
  final _endPointController = TextEditingController();
  final _ihFocus = FocusNode();
  final _startFocus = FocusNode();
  final _endFocus = FocusNode();
  final _offsetFocus = FocusNode();
  final _storageService = StorageService();

  OffsetDirection _offsetDirection = OffsetDirection.Right;
  bool _loadingSessions = false;
  List<SurveySession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loadingSessions = true);
    try {
      final sessions = await _storageService.getSavedSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessions = [];
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSessions = false);
      }
    }
  }

  List<MainPoint> _buildMainPoints({
    required int start,
    required int end,
    required OffsetDirection direction,
  }) {
    final step = start <= end ? 1 : -1;
    final total = (end - start).abs() + 1;

    return List.generate(total, (index) {
      final pointNum = start + index * step;
      return MainPoint(
        name: 'No.$pointNum',
        station: index * 20.0,
        offsetDirection: direction,
        offsetDistance: 0.0,
        excavationLevel: 0.0,
      );
    });
  }

  void _generatePoints() {
    if (_formKey.currentState!.validate()) {
      final double ih = double.parse(_ihController.text);
      final int start = int.parse(_startPointController.text);
      final int end = int.parse(_endPointController.text);

      final points = _buildMainPoints(
        start: start,
        end: end,
        direction: _offsetDirection,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DataEntryScreen(
            instrumentHeight: ih,
            startPointNum: start,
            endPointNum: end,
            offsetDirection: _offsetDirection,
            mainPoints: points,
          ),
        ),
      );
    }
  }

  Future<void> _openSavedSessions() async {
    final session = await Navigator.push<SurveySession?>(
      context,
      MaterialPageRoute(
        builder: (context) => SavedSessionsScreen(
          storageService: _storageService,
        ),
      ),
    );

    if (!mounted) return;

    if (session != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DataEntryScreen.fromSession(session),
        ),
      );
    }
  }

  @override
  void dispose() {
    _ihController.dispose();
    _startPointController.dispose();
    _endPointController.dispose();
    _ihFocus.dispose();
    _startFocus.dispose();
    _endFocus.dispose();
    _offsetFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('측량 준비'),
        actions: [
          IconButton(
            onPressed: _openSavedSessions,
            icon: const Icon(Icons.folder_open),
            tooltip: '저장된 작업 불러오기',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _ihController,
                focusNode: _ihFocus,
                decoration: const InputDecoration(
                  labelText: 'IH (기계고)',
                  border: OutlineInputBorder(),
                  hintText: '100.0',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _startFocus.requestFocus(),
                validator: (value) =>
                    value == null || value.isEmpty ? 'IH 값을 입력하세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startPointController,
                focusNode: _startFocus,
                decoration: const InputDecoration(
                  labelText: '시작 포인트 번호',
                  border: OutlineInputBorder(),
                  hintText: '0',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _endFocus.requestFocus(),
                validator: (value) =>
                    value == null || value.isEmpty ? '시작 번호를 입력하세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _endPointController,
                focusNode: _endFocus,
                decoration: const InputDecoration(
                  labelText: '끝 포인트 번호',
                  border: OutlineInputBorder(),
                  hintText: '10',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _offsetFocus.requestFocus(),
                validator: (value) =>
                    value == null || value.isEmpty ? '끝 번호를 입력하세요.' : null,
              ),
              const SizedBox(height: 16),
              Focus(
                focusNode: _offsetFocus,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                    _generatePoints();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: DropdownButtonFormField<OffsetDirection>(
                  value: _offsetDirection,
                  decoration: const InputDecoration(
                    labelText: '오프셋 방향',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: OffsetDirection.Left, child: Text('좌측')),
                    DropdownMenuItem(value: OffsetDirection.Right, child: Text('우측')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _offsetDirection = value);
                    }
                  },
                  onSaved: (_) {},
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generatePoints,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                icon: const Icon(Icons.playlist_add),
                label: const Text('포인트 목록 생성'),
              ),
              const SizedBox(height: 24),
              if (_loadingSessions)
                const Center(child: CircularProgressIndicator())
              else if (_sessions.isEmpty)
                const SizedBox.shrink()
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '최근 저장된 작업',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._sessions.take(3).map(
                      (s) => Card(
                        child: ListTile(
                          title: Text(s.title),
                          subtitle: Text(
                              'No.${s.startPointNum}~No.${s.endPointNum} • ${s.updatedAt.toLocal()}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DataEntryScreen.fromSession(s),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
