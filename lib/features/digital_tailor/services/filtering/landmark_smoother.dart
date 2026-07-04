import '../../models/body_landmarks.dart';
import '../../models/processed_landmarks.dart';
import 'one_euro_filter.dart';

/// Applies adaptive One Euro filtering to live body landmarks.
class LandmarkSmoother {
  final Map<String, OneEuroFilter2D> _filters = {};
  ProcessedLandmarks? _previous;

  double _lastJitter = 0.0;

  double get lastJitter => _lastJitter;

  ProcessedLandmarks smooth(ProcessedLandmarks landmarks, double timestamp) {
    LandmarkPoint2D smoothPoint(String key, LandmarkPoint2D point) {
      if (point.confidence <= 0) return point;
      final filter = _filters.putIfAbsent(
        key,
        () => OneEuroFilter2D(minCutoff: 1.1, beta: 0.015),
      );
      final filtered = filter.filter(point.x, point.y, timestamp);
      return LandmarkPoint2D(
        x: filtered.x,
        y: filtered.y,
        confidence: point.confidence,
      );
    }

    final smoothed = ProcessedLandmarks(
      nose: smoothPoint('nose', landmarks.nose),
      leftEar: smoothPoint('leftEar', landmarks.leftEar),
      rightEar: smoothPoint('rightEar', landmarks.rightEar),
      leftShoulder: smoothPoint('leftShoulder', landmarks.leftShoulder),
      rightShoulder: smoothPoint('rightShoulder', landmarks.rightShoulder),
      leftElbow: smoothPoint('leftElbow', landmarks.leftElbow),
      rightElbow: smoothPoint('rightElbow', landmarks.rightElbow),
      leftWrist: smoothPoint('leftWrist', landmarks.leftWrist),
      rightWrist: smoothPoint('rightWrist', landmarks.rightWrist),
      leftHip: smoothPoint('leftHip', landmarks.leftHip),
      rightHip: smoothPoint('rightHip', landmarks.rightHip),
      leftKnee: smoothPoint('leftKnee', landmarks.leftKnee),
      rightKnee: smoothPoint('rightKnee', landmarks.rightKnee),
      leftAnkle: smoothPoint('leftAnkle', landmarks.leftAnkle),
      rightAnkle: smoothPoint('rightAnkle', landmarks.rightAnkle),
      imageWidth: landmarks.imageWidth,
      imageHeight: landmarks.imageHeight,
    );

    _lastJitter = _computeJitter(smoothed, _previous);
    _previous = smoothed;
    return smoothed;
  }

  void reset() {
    for (final filter in _filters.values) {
      filter.reset();
    }
    _previous = null;
    _lastJitter = 0.0;
  }

  double _computeJitter(ProcessedLandmarks current, ProcessedLandmarks? prev) {
    if (prev == null) return 0.0;

    final currentPoints = current.allLandmarks;
    final previousPoints = prev.allLandmarks;
    var total = 0.0;
    var count = 0;

    for (var i = 0; i < currentPoints.length; i++) {
      final a = currentPoints[i];
      final b = previousPoints[i];
      if (a.confidence <= 0 || b.confidence <= 0) continue;
      final dx = a.x - b.x;
      final dy = a.y - b.y;
      total += dx.abs() + dy.abs();
      count++;
    }

    return count == 0 ? 0.0 : total / count;
  }
}
