enum OffsetDirection { Left, Right, Center }

class MainPoint {
  final String name;
  final double station; // 거리
  double offsetDistance;
  OffsetDirection offsetDirection;
  double excavationLevel; // 계획 레벨

  MainPoint({
    required this.name,
    required this.station,
    this.offsetDistance = 0.0,
    this.offsetDirection = OffsetDirection.Center,
    this.excavationLevel = 0.0,
  });

  MainPoint copy() {
    return MainPoint(
      name: name,
      station: station,
      offsetDistance: offsetDistance,
      offsetDirection: offsetDirection,
      excavationLevel: excavationLevel,
    );
  }

  factory MainPoint.fromJson(Map<String, dynamic> json) {
    return MainPoint(
      name: json['name'] as String,
      station: (json['station'] as num).toDouble(),
      offsetDistance: (json['offsetDistance'] as num).toDouble(),
      offsetDirection:
          OffsetDirection.values.firstWhere((d) => d.name == json['offsetDirection']),
      excavationLevel: (json['excavationLevel'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'station': station,
      'offsetDistance': offsetDistance,
      'offsetDirection': offsetDirection.name,
      'excavationLevel': excavationLevel,
    };
  }
}

class CalculatedPoint {
  final String name;
  final double station;
  final double calculatedOffset;
  final OffsetDirection offsetDirection;
  final double calculatedExcavationLevel;
  double? observedReading; // 실측 관측값 (레벨 미터 읽음)

  CalculatedPoint({
    required this.name,
    required this.station,
    required this.calculatedOffset,
    required this.offsetDirection,
    required this.calculatedExcavationLevel,
    this.observedReading,
  });

  /// 계획 레벨과 실측 관측값으로 실제 지반 레벨을 계산합니다.
  double? actualGroundLevel(double instrumentHeight) {
    if (observedReading == null) return null;
    return instrumentHeight - observedReading!;
  }

  /// 성토(+)/절토(-) 값 (단위: m).
  double? cutFill(double instrumentHeight) {
    final actual = actualGroundLevel(instrumentHeight);
    if (actual == null) return null;
    return calculatedExcavationLevel - actual;
  }
}
