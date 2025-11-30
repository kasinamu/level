import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/survey_point.dart';
import '../models/survey_session.dart';
import '../services/storage_service.dart';
import 'results_screen.dart';

class DataEntryScreen extends StatefulWidget {
  final double instrumentHeight;
  final int startPointNum;
  final int endPointNum;
  final OffsetDirection offsetDirection;
  final List<MainPoint> mainPoints;
  final String? initialTitle;
  final String? sessionId;
  final InputPhase initialPhase;
  final int initialIndex;
  final Map<String, double>? initialObservedReadings;
  final Set<String>? initialCompletedPoints;

  const DataEntryScreen({
    super.key,
    required this.instrumentHeight,
    required this.startPointNum,
    required this.endPointNum,
    required this.offsetDirection,
    required this.mainPoints,
    this.initialTitle,
    this.sessionId,
    this.initialPhase = InputPhase.offsets,
    this.initialIndex = 0,
    this.initialObservedReadings,
    this.initialCompletedPoints,
  });

  factory DataEntryScreen.fromSession(SurveySession session) {
    return DataEntryScreen(
      instrumentHeight: session.instrumentHeight,
      startPointNum: session.startPointNum,
      endPointNum: session.endPointNum,
      offsetDirection: session.offsetDirection,
      mainPoints: session.mainPoints,
      initialTitle: session.title,
      sessionId: session.id,
      initialPhase: session.phase,
      initialIndex: session.currentIndex,
      initialObservedReadings: session.observedReadings,
      initialCompletedPoints: session.completedPoints,
    );
  }

  @override
  State<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen> {
  late List<MainPoint> _mainPoints;
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _storageService = StorageService();
  final _fieldFocus = FocusNode();

  InputPhase _phase = InputPhase.offsets;
  int _currentIndex = 0;
  String? _sessionTitle;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mainPoints = widget.mainPoints.map((p) => p.copy()).toList();
    _sessionTitle = widget.initialTitle;
    _phase = widget.initialPhase;
    _currentIndex = widget.initialIndex.clamp(0, _mainPoints.length - 1);
    _loadCurrentValue();
    WidgetsBinding.instance.addPostFrameCallback((_) => _selectAll());
  }

  @override
  void dispose() {
    _valueController.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  MainPoint get _currentPoint => _mainPoints[_currentIndex];

  String get _labelText {
    final total = _mainPoints.length;
    final label = _phase == InputPhase.offsets ? '이격' : '레벨';
    return '${_currentPoint.name} (${_currentIndex + 1}/$total) $label';
  }

  String get _hintText {
    return _phase == InputPhase.offsets ? '이격 거리 입력' : '계획 레벨 입력';
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _next();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _loadCurrentValue() {
    final value = _phase == InputPhase.offsets
        ? _currentPoint.offsetDistance
        : _currentPoint.excavationLevel;
    _valueController.text = value.toString();
  }

  void _selectAll() {
    // Select text first
    _valueController.selection =
        TextSelection(baseOffset: 0, extentOffset: _valueController.text.length);
    
    // If it doesn't have focus, request it after a short delay.
    if (!_fieldFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) { // Check if the widget is still in the tree
          FocusScope.of(context).requestFocus(_fieldFocus);
        }
      });
    }
  }

  bool _saveValue() {
    final raw = _valueController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('값을 입력하세요.')));
      return false;
    }
    final value = double.tryParse(raw);
    if (value == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('숫자만 입력하세요.')));
      return false;
    }
    if (_phase == InputPhase.offsets) {
      _currentPoint.offsetDistance = value;
    } else {
      _currentPoint.excavationLevel = value;
    }
    return true;
  }

  void _next() {
    if (!_saveValue()) return;

    if (_currentIndex < _mainPoints.length - 1) {
      setState(() {
        _currentIndex++;
        _loadCurrentValue();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _selectAll());
      return;
    }

    if (_phase == InputPhase.offsets) {
      setState(() {
        _phase = InputPhase.levels;
        _currentIndex = 0;
        _loadCurrentValue();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _selectAll());
    } else {
      _navigateToResults();
    }
  }

  void _previous() {
    if (_currentIndex == 0 && _phase == InputPhase.offsets) return;

    if (_currentIndex == 0 && _phase == InputPhase.levels) {
      setState(() {
        _phase = InputPhase.offsets;
        _currentIndex = _mainPoints.length - 1;
        _loadCurrentValue();
      });
    } else {
      setState(() {
        _currentIndex--;
        _loadCurrentValue();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _selectAll());
  }

  Future<void> _navigateToResults() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          mainPoints: _mainPoints,
          instrumentHeight: widget.instrumentHeight,
          startPointNum: widget.startPointNum,
          endPointNum: widget.endPointNum,
          offsetDirection: widget.offsetDirection,
          sessionId: widget.sessionId,
          sessionTitle: _sessionTitle,
          storageService: _storageService,
          observedReadings: widget.initialObservedReadings ?? {},
          completedPoints: widget.initialCompletedPoints ?? {},
        ),
      ),
    );
  }

  SurveySession _buildSession(String title) {
    final id = widget.sessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
    return SurveySession(
      id: id,
      title: title,
      instrumentHeight: widget.instrumentHeight,
      startPointNum: widget.startPointNum,
      endPointNum: widget.endPointNum,
      offsetDirection: widget.offsetDirection,
      mainPoints: _mainPoints,
      phase: _phase,
      currentIndex: _currentIndex,
      observedReadings: widget.initialObservedReadings ?? {},
      completedPoints: widget.initialCompletedPoints ?? {},
    );
  }

  Future<void> _saveSession({String? forcedTitle, bool showToast = true}) async {
    if (_saving) return;
    final title = forcedTitle ?? _sessionTitle ?? '무제 작업';
    setState(() => _saving = true);
    try {
      await _storageService.saveSession(_buildSession(title));
      _sessionTitle = title;
      if (showToast && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('로컬 저장소')
                  ? '저장이 제한된 환경입니다. 앱을 재시작하거나 실제 기기/에뮬레이터에서 실행해 주세요.'
                  : '저장 중 오류가 발생했습니다: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<bool> _confirmExit() async {
    final controller = TextEditingController(text: _sessionTitle ?? '');
    final result = await showDialog<_ExitAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('작업을 저장할까요?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '제목',
              hintText: '예: 45~50 공구',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _ExitAction.discard),
              child: const Text('저장 안 함'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _ExitAction.cancel),
              child: const Text('계속 작업'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _ExitAction.save),
              child: const Text('저장 후 종료'),
            ),
          ],
        );
      },
    );

    if (result == _ExitAction.save) {
      await _saveSession(forcedTitle: controller.text.isEmpty ? '무제 작업' : controller.text);
      return true;
    }
    if (result == _ExitAction.discard) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final total = _mainPoints.length;

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _phase == InputPhase.offsets ? '이격 입력' : '레벨 입력',
          ),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            IconButton(
              tooltip: '임시저장',
              onPressed: _saving ? null : () => _saveSession(showToast: true),
              icon: const Icon(Icons.save_outlined),
            ),
            IconButton(
              tooltip: '취소',
              onPressed: () async {
                final navigator = Navigator.of(context);
                final shouldExit = await _confirmExit();
                if (shouldExit) {
                  navigator.pop();
                }
              },
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    title: Text('IH: ${widget.instrumentHeight}'),
                    subtitle: Text(
                        '구간: No.${widget.startPointNum} ~ No.${widget.endPointNum} (${widget.offsetDirection.name})'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _labelText,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Focus(
                  focusNode: _fieldFocus,
                  onKeyEvent: _handleKey,
                  child: TextFormField(
                    controller: _valueController,
                    decoration: InputDecoration(
                      labelText: _hintText,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true),
                    textInputAction: TextInputAction.done,
                    maxLines: 1,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d+\.?\d*'))
                    ],
                    onTap: _selectAll,
                    onFieldSubmitted: (_) => _next(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '진행: ${_currentIndex + 1} / $total (${_phase == InputPhase.offsets ? "이격" : "레벨"})',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _previous,
                      icon: const Icon(Icons.navigate_before),
                      label: const Text('이전'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _next,
                      icon: Icon(
                        _phase == InputPhase.levels && _currentIndex == total - 1
                            ? Icons.check
                            : Icons.navigate_next,
                      ),
                      label: Text(
                        _phase == InputPhase.levels && _currentIndex == total - 1
                            ? '결과 보기'
                            : '다음',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ExitAction { save, discard, cancel }
