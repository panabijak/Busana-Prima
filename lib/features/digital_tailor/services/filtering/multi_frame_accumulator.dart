import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../models/body_landmarks.dart';
import '../../models/processed_landmarks.dart';

/// Accumulates multiple pose detection frames and produces stable,
/// noise-reduced landmarks using median filtering with outlier rejection.
///
/// Instead of relying on a single frame (which may contain noise/jitter),
/// this collects [targetFrames] valid frames and computes the statistical
/// median for each landmark coordinate.
class MultiFrameAccumulator {
  /// Number of consecutive valid frames to collect before computing.
  static const int targetFrames = 15;

  /// Minimum percentage of frames that must contain a landmark
  /// for it to be included in the result.
  static const double minFramePresence = 0.70; // 70%

  final List<Map<PoseLandmarkType, LandmarkPoint2D>> _frames = [];
  final List<double> _timestamps = [];

  /// Add a frame from pose detection.
  /// Only adds landmarks with confidence >= [minConfidence].
  void addFrame(Pose pose, {double minConfidence = 0.5}) {
    final landmarks = <PoseLandmarkType, LandmarkPoint2D>{};

    for (final entry in pose.landmarks.entries) {
      if (entry.value.likelihood >= minConfidence) {
        landmarks[entry.key] = LandmarkPoint2D(
          x: entry.value.x,
          y: entry.value.y,
          confidence: entry.value.likelihood,
        );
      }
    }

    if (landmarks.length >= 8) {
      // Only accept frames with enough landmarks
      _frames.add(landmarks);
      _timestamps.add(DateTime.now().millisecondsSinceEpoch / 1000.0);
    }
  }

  /// Whether enough frames have been accumulated.
  bool get isComplete => _frames.length >= targetFrames;

  /// Current frame count.
  int get frameCount => _frames.length;

  /// Progress as a fraction (0.0 to 1.0).
  double get progress => (_frames.length / targetFrames).clamp(0.0, 1.0);

  /// Compute stable landmarks from accumulated frames using median
  /// with IQR-based outlier rejection.
  ///
  /// Returns null if insufficient frames have been accumulated.
  ProcessedLandmarks? computeStableLandmarks({
    required int imageWidth,
    required int imageHeight,
  }) {
    if (_frames.length < targetFrames * 0.5) return null;

    final stableLandmarks = <PoseLandmarkType, LandmarkPoint2D>{};

    // Compute median for each landmark type
    for (final type in PoseLandmarkType.values) {
      final points = _frames
          .where((f) => f.containsKey(type))
          .map((f) => f[type]!)
          .toList();

      // Skip if landmark isn't present in enough frames
      if (points.length < _frames.length * minFramePresence) continue;

      // Remove outliers and compute median
      final cleanedX = _removeOutliersAndMedian(
        points.map((p) => p.x).toList(),
      );
      final cleanedY = _removeOutliersAndMedian(
        points.map((p) => p.y).toList(),
      );
      final avgConfidence =
          points.map((p) => p.confidence).reduce((a, b) => a + b) /
          points.length;

      if (cleanedX != null && cleanedY != null) {
        stableLandmarks[type] = LandmarkPoint2D(
          x: cleanedX,
          y: cleanedY,
          confidence: avgConfidence,
        );
      }
    }

    // Check we have all required landmarks
    const required = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    for (final type in required) {
      if (!stableLandmarks.containsKey(type)) return null;
    }

    return ProcessedLandmarks(
      nose: stableLandmarks[PoseLandmarkType.nose]!,
      leftEar:
          stableLandmarks[PoseLandmarkType.leftEar] ?? LandmarkPoint2D.zero,
      rightEar:
          stableLandmarks[PoseLandmarkType.rightEar] ?? LandmarkPoint2D.zero,
      leftShoulder: stableLandmarks[PoseLandmarkType.leftShoulder]!,
      rightShoulder: stableLandmarks[PoseLandmarkType.rightShoulder]!,
      leftElbow: stableLandmarks[PoseLandmarkType.leftElbow]!,
      rightElbow: stableLandmarks[PoseLandmarkType.rightElbow]!,
      leftWrist: stableLandmarks[PoseLandmarkType.leftWrist]!,
      rightWrist: stableLandmarks[PoseLandmarkType.rightWrist]!,
      leftHip: stableLandmarks[PoseLandmarkType.leftHip]!,
      rightHip: stableLandmarks[PoseLandmarkType.rightHip]!,
      leftKnee: stableLandmarks[PoseLandmarkType.leftKnee]!,
      rightKnee: stableLandmarks[PoseLandmarkType.rightKnee]!,
      leftAnkle: stableLandmarks[PoseLandmarkType.leftAnkle]!,
      rightAnkle: stableLandmarks[PoseLandmarkType.rightAnkle]!,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  /// Reset the accumulator for a new capture session.
  void reset() {
    _frames.clear();
    _timestamps.clear();
  }

  /// Remove statistical outliers using IQR method, then return median.
  double? _removeOutliersAndMedian(List<double> values) {
    if (values.isEmpty) return null;
    if (values.length == 1) return values.first;

    final sorted = List<double>.from(values)..sort();

    // Compute IQR
    final q1Index = (sorted.length * 0.25).floor();
    final q3Index = (sorted.length * 0.75).floor();
    final q1 = sorted[q1Index];
    final q3 = sorted[q3Index];
    final iqr = q3 - q1;

    // Remove outliers (beyond 1.5 × IQR)
    final lowerBound = q1 - 1.5 * iqr;
    final upperBound = q3 + 1.5 * iqr;
    final cleaned = sorted
        .where((v) => v >= lowerBound && v <= upperBound)
        .toList();

    if (cleaned.isEmpty) return sorted[sorted.length ~/ 2]; // Fallback median

    // Return median of cleaned data
    return cleaned[cleaned.length ~/ 2];
  }
}
