import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/layout_preferences.dart';
import '../models/survey_point.dart';
import '../models/survey_session.dart';
import '../services/storage_service.dart';
import '../services/survey_calculator.dart';

class ResultsScreen extends StatefulWidget {
  final List<MainPoint> mainPoints;
  final double instrumentHeight;
  final int startPointNum;
  final int endPointNum;
  final OffsetDirection offsetDirection;
  final String? sessionId;
  final String? sessionTitle;
  final StorageService storageService;
  final Map<String, double> observedReadings;
  final Set<String> completedPoints;

  const ResultsScreen({
    super.key,
    required this.mainPoints,
    required this.instrumentHeight,
    required this.startPointNum,
    required this.endPointNum,
    required this.offsetDirection,
    required this.storageService,
    this.sessionId,
    this.sessionTitle,
    Map<String, double>? observedReadings,
    Set<String>? completedPoints,
  })  : observedReadings = observedReadings ?? const {},
        completedPoints = completedPoints ?? const {};

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _calculator = SurveyCalculator();
  late List<CalculatedPoint> _calculatedPoints;
  late List<bool> _completed;
  late double _instrumentHeight;
  String? _sessionTitle;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _instrumentHeight = widget.instrumentHeight;
    _sessionTitle = widget.sessionTitle;
    _calculatedPoints = _calculator.calculate(widget.mainPoints);
    final observed = widget.observedReadings;
    final completed = widget.completedPoints;
    for (final point in _calculatedPoints) {
      final value = observed[point.name];
      if (value != null) {
        point.observedReading = value;
      }
    }
    _completed = _calculatedPoints
        .map((point) => completed.contains(point.name))
        .toList(growable: false);
  }

  String _directionLabel(OffsetDirection direction) {
    switch (direction) {
      case OffsetDirection.Left:
        return '좌안';
      case OffsetDirection.Right:
        return '우안';
      case OffsetDirection.Center:
        return '중앙';
    }
  }

  ({String base, int? segment}) _splitName(String name) {
    final plusIndex = name.indexOf('+');
    if (plusIndex == -1) {
      return (base: name, segment: null);
    }
    final base = name.substring(0, plusIndex);
    final segmentValue = int.tryParse(name.substring(plusIndex + 1));
    return (base: base, segment: segmentValue);
  }

  Color _segmentColor(int value) {
    switch (value) {
      case 0:
        return Colors.deepPurple.shade300;
      case 5:
        return Colors.blue.shade300;
      case 10:
        return Colors.orange.shade300;
      case 15:
        return Colors.teal.shade300;
      default:
        return Colors.grey.shade400;
    }
  }

  Future<void> _editInstrumentHeight() async {
    final controller =
        TextEditingController(text: _instrumentHeight.toStringAsFixed(3));
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('IH 값 수정'),
          content: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d+\.?\d*'))
            ],
            decoration: const InputDecoration(
              labelText: 'IH',
              hintText: '예: 100.000',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = double.tryParse(controller.text);
                Navigator.pop(context, value);
              },
              child: const Text('적용'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      setState(() {
        _instrumentHeight = result;
      });
    }
  }

  Future<void> _saveResults() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final observed = <String, double>{};
      for (final point in _calculatedPoints) {
        if (point.observedReading != null) {
          observed[point.name] = point.observedReading!;
        }
      }
      final completed = <String>{
        for (int i = 0; i < _calculatedPoints.length; i++)
          if (_completed[i]) _calculatedPoints[i].name,
      };
      final session = SurveySession(
        id: widget.sessionId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _sessionTitle ?? '무제 작업',
        instrumentHeight: _instrumentHeight,
        startPointNum: widget.startPointNum,
        endPointNum: widget.endPointNum,
        offsetDirection: widget.offsetDirection,
        mainPoints: widget.mainPoints,
        phase: InputPhase.levels,
        currentIndex: widget.mainPoints.length - 1,
        observedReadings: observed,
        completedPoints: completed,
      );
      await widget.storageService.saveSession(session);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('결과가 저장되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];

    sheet.appendRow([
      TextCellValue('지점'),
      TextCellValue('거리'),
      TextCellValue('계획레벨'),
      TextCellValue('방향'),
      TextCellValue('오프셋'),
      TextCellValue('관측값'),
      TextCellValue('실측값'),
      TextCellValue('성토(m)'),
      TextCellValue('절토(cm)'),
    ]);

    for (final point in _calculatedPoints) {
      final difference = point.cutFill(_instrumentHeight);
      final targetReading = _instrumentHeight - point.calculatedExcavationLevel;
      String cutFillLabel = '-';
      if (difference != null) {
        final diffCm = difference * 100.0;
        if (difference > 0) {
          cutFillLabel = '성토 ${diffCm.toStringAsFixed(1)}';
        } else if (difference < 0) {
          cutFillLabel = '절토 ${(-diffCm).toStringAsFixed(1)}';
        } else {
          cutFillLabel = '0.0';
        }
      }

      sheet.appendRow([
        TextCellValue(point.name),
        DoubleCellValue(point.station),
        DoubleCellValue(point.calculatedExcavationLevel),
        TextCellValue(_directionLabel(point.offsetDirection)),
        DoubleCellValue(point.calculatedOffset),
        DoubleCellValue(targetReading),
        point.observedReading != null
            ? DoubleCellValue(point.observedReading!)
            : TextCellValue('-'),
        difference != null ? DoubleCellValue(difference) : TextCellValue('-'),
        TextCellValue(cutFillLabel),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('엑셀 파일 생성에 실패했습니다.')),
        );
      }
      return;
    }

    final now = DateTime.now();
    final formattedDate =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'survey_results_$formattedDate.xlsx';
    final bytes = Uint8List.fromList(fileBytes);

    try {
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: bytes,
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles(
          [
            XFile(
              file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          text: '레벨 측량 결과를 공유합니다.',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('엑셀 파일 저장 완료: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('엑셀 저장 중 오류: $e')),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    const double fold4CoverLogicalWidth = 380; // for 360dp cover width + padding.
    final bool useFold4Layout =
        LayoutPreferences.forceFold4Layout || mediaQuery.size.width <= fold4CoverLogicalWidth;

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actions: [
          TextButton.icon(
            onPressed: _editInstrumentHeight,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.edit, size: 18),
            label: Text('IH ${_instrumentHeight.toStringAsFixed(3)}'),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: '저장',
            onPressed: _saving ? null : _saveResults,
            icon: const Icon(Icons.save_outlined, size: 20),
          ),
          IconButton(
            tooltip: '엑셀 저장/공유',
            onPressed: _exportToExcel,
            icon: const Icon(Icons.grid_on, size: 20),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _calculatedPoints.length,
        itemBuilder: (context, index) {
          final point = _calculatedPoints[index];
          final difference = point.cutFill(_instrumentHeight);
          final targetReading = _instrumentHeight - point.calculatedExcavationLevel;
          final segmentParts = _splitName(point.name);

          IconData? arrow;
          Color arrowColor = Colors.grey;
          String cutFillLabel = '-';
          if (difference != null) {
            final diffCm = difference * 100.0;
            if (difference > 0) {
              arrow = Icons.arrow_upward;
              arrowColor = Colors.blue.shade700;
              cutFillLabel = '성토 ${diffCm.toStringAsFixed(1)}cm';
            } else if (difference < 0) {
              arrow = Icons.arrow_downward;
              arrowColor = Colors.red.shade700;
              cutFillLabel = '절토 ${(-diffCm).toStringAsFixed(1)}cm';
            } else {
              cutFillLabel = '0.0cm';
            }
          }

          final isDone = _completed[index];

          final observedInput = TextFormField(
            key: ValueKey('observed_${point.name}'),
            initialValue: point.observedReading?.toString() ?? '',
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d+\.?\d*'))
            ],
            onChanged: (value) {
              setState(() {
                point.observedReading = double.tryParse(value);
              });
            },
          );

          final Widget cutFillWidget = arrow != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(arrow, color: arrowColor, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      cutFillLabel,
                      style: TextStyle(color: arrowColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              : const Text('-');

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            color: isDone ? Colors.green.shade50 : null,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: isDone ? Colors.green.shade400 : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              segmentParts.base,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            if (segmentParts.segment != null)
                              Chip(
                                label: Text(
                                  '${segmentParts.segment}m',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor:
                                    _segmentColor(segmentParts.segment ?? 0),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: isDone,
                            onChanged: (value) {
                              setState(() => _completed[index] = value ?? false);
                            },
                          ),
                          const Text('완료'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${point.calculatedOffset.toStringAsFixed(3)}(${_directionLabel(point.offsetDirection)})',
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                      Text(
                        '계획 레벨: ${point.calculatedExcavationLevel.toStringAsFixed(3)}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (useFold4Layout)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '관측 ${targetReading.toStringAsFixed(3)}',
                          style: const TextStyle(
                              color: Colors.purple, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              '실측',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: observedInput),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: cutFillWidget,
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '관측 ${targetReading.toStringAsFixed(3)}',
                              style: const TextStyle(
                                  color: Colors.purple, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  const Text(
                                    '실측',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black54),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 120),
                                      child: observedInput,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: cutFillWidget,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}