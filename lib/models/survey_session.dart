import 'dart:convert';

import 'survey_point.dart';

enum InputPhase { offsets, levels }

class SurveySession {
  final String id;
  final String title;
  final double instrumentHeight;
  final int startPointNum;
  final int endPointNum;
  final OffsetDirection offsetDirection;
  final List<MainPoint> mainPoints;
  final InputPhase phase;
  final int currentIndex;
  final Map<String, double> observedReadings;
  final Set<String> completedPoints;
  final DateTime updatedAt;

  SurveySession({
    required this.id,
    required this.title,
    required this.instrumentHeight,
    required this.startPointNum,
    required this.endPointNum,
    required this.offsetDirection,
    required this.mainPoints,
    this.phase = InputPhase.offsets,
    this.currentIndex = 0,
    Map<String, double>? observedReadings,
    Set<String>? completedPoints,
    DateTime? updatedAt,
  })  : observedReadings = observedReadings ?? {},
        completedPoints = completedPoints ?? {},
        updatedAt = updatedAt ?? DateTime.now();

  SurveySession copyWith({
    String? id,
    String? title,
    double? instrumentHeight,
    int? startPointNum,
    int? endPointNum,
    OffsetDirection? offsetDirection,
    List<MainPoint>? mainPoints,
    InputPhase? phase,
    int? currentIndex,
    Map<String, double>? observedReadings,
    Set<String>? completedPoints,
    DateTime? updatedAt,
  }) {
    return SurveySession(
      id: id ?? this.id,
      title: title ?? this.title,
      instrumentHeight: instrumentHeight ?? this.instrumentHeight,
      startPointNum: startPointNum ?? this.startPointNum,
      endPointNum: endPointNum ?? this.endPointNum,
      offsetDirection: offsetDirection ?? this.offsetDirection,
      mainPoints: mainPoints ?? this.mainPoints.map((p) => p.copy()).toList(),
      phase: phase ?? this.phase,
      currentIndex: currentIndex ?? this.currentIndex,
      observedReadings: observedReadings ?? Map<String, double>.from(this.observedReadings),
      completedPoints: completedPoints ?? Set<String>.from(this.completedPoints),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'instrumentHeight': instrumentHeight,
      'startPointNum': startPointNum,
      'endPointNum': endPointNum,
      'offsetDirection': offsetDirection.name,
      'mainPoints': mainPoints.map((p) => p.toJson()).toList(),
      'phase': phase.name,
      'currentIndex': currentIndex,
      'observedReadings': observedReadings,
      'completedPoints': completedPoints.toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SurveySession.fromJson(Map<String, dynamic> json) {
    return SurveySession(
      id: json['id'] as String,
      title: json['title'] as String,
      instrumentHeight: (json['instrumentHeight'] as num).toDouble(),
      startPointNum: json['startPointNum'] as int,
      endPointNum: json['endPointNum'] as int,
      offsetDirection:
          OffsetDirection.values.firstWhere((d) => d.name == json['offsetDirection']),
      mainPoints: (json['mainPoints'] as List<dynamic>)
          .map((e) => MainPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      phase: InputPhase.values.firstWhere((p) => p.name == json['phase']),
      currentIndex: json['currentIndex'] as int,
      observedReadings: (json['observedReadings'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, (value as num).toDouble())) ??
          {},
      completedPoints: (json['completedPoints'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          {},
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static String encodeList(List<SurveySession> sessions) =>
      jsonEncode(sessions.map((s) => s.toJson()).toList());

  static List<SurveySession> decodeList(String source) {
    final data = jsonDecode(source) as List<dynamic>;
    return data.map((e) => SurveySession.fromJson(e as Map<String, dynamic>)).toList();
  }
}
