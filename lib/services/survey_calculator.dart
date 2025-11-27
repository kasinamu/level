import '../models/survey_point.dart';

class SurveyCalculator {
  double _interpolate(double start, double end, double factor) {
    return start + (end - start) * factor;
  }

  int? _parsePointNumber(String name) {
    final match = RegExp(r'No\.(\d+)').firstMatch(name);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  List<CalculatedPoint> calculate(List<MainPoint> mainPoints) {
    if (mainPoints.length < 2) {
      return mainPoints.map((p) => CalculatedPoint(
        name: '${p.name}+0',
        station: p.station,
        calculatedOffset: p.offsetDistance,
        offsetDirection: p.offsetDirection,
        calculatedExcavationLevel: p.excavationLevel
      )).toList();
    }

    final List<CalculatedPoint> result = [];

    for (int i = 0; i < mainPoints.length - 1; i++) {
      final startPoint = mainPoints[i];
      final endPoint = mainPoints[i + 1];
      final startNum = _parsePointNumber(startPoint.name);
      final endNum = _parsePointNumber(endPoint.name);
      final isDescending = startNum != null && endNum != null && startNum > endNum;

      // Add the starting main point for this segment
      if (i == 0) {
        result.add(CalculatedPoint(
          name: '${startPoint.name}+0',
          station: startPoint.station,
          calculatedOffset: startPoint.offsetDistance,
          offsetDirection: startPoint.offsetDirection,
          calculatedExcavationLevel: startPoint.excavationLevel,
        ));
      }

      const double segmentLength = 20.0;
      const int intervals = 4;
      const double intervalDistance = segmentLength / intervals;

      for (int j = 1; j < intervals; j++) {
        final double station = startPoint.station + j * intervalDistance;
        final double factor = (j * intervalDistance) / segmentLength;

        // A better way to handle offsets: treat Left as negative
        final startOffset = startPoint.offsetDirection == OffsetDirection.Left ? -startPoint.offsetDistance : startPoint.offsetDistance;
        final endOffset = endPoint.offsetDirection == OffsetDirection.Left ? -endPoint.offsetDistance : endPoint.offsetDistance;

        final interpOffsetValue = _interpolate(startOffset, endOffset, factor);
        final interpLevel = _interpolate(startPoint.excavationLevel, endPoint.excavationLevel, factor);
        final distanceFromStart = (j * intervalDistance).toInt();
        final distanceFromEnd = (segmentLength - j * intervalDistance).toInt();

        result.add(CalculatedPoint(
          name: isDescending
              ? '${endPoint.name}+$distanceFromEnd'
              : '${startPoint.name}+$distanceFromStart',
          station: station,
          calculatedOffset: interpOffsetValue.abs(),
          offsetDirection: interpOffsetValue < 0 ? OffsetDirection.Left : OffsetDirection.Right,
          calculatedExcavationLevel: interpLevel,
        ));
      }

      // Add the ending main point for this segment
      result.add(CalculatedPoint(
        name: '${endPoint.name}+0',
        station: endPoint.station,
        calculatedOffset: endPoint.offsetDistance,
        offsetDirection: endPoint.offsetDirection,
        calculatedExcavationLevel: endPoint.excavationLevel,
      ));
    }

    return result;
  }
}
