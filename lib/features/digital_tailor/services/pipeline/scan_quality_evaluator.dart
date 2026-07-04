import 'package:camera/camera.dart';

import '../../models/processed_landmarks.dart';
import '../pipeline/a_pose_validator.dart';

/// Real-time quality metrics shown to the user during scanning.
class ScanQualityMetrics {
  /// Lighting quality (0.0–1.0)
  final double lighting;

  /// Body visibility — fraction of required landmarks detected
  final double bodyVisibility;

  /// Pose accuracy — how well the A-Pose requirements are met
  final double poseAccuracy;

  /// Camera distance — how well the user fits in frame
  final double cameraDistance;

  /// Overall confidence (weighted average of all metrics)
  final double overall;

  const ScanQualityMetrics({
    required this.lighting,
    required this.bodyVisibility,
    required this.poseAccuracy,
    required this.cameraDistance,
    required this.overall,
  });

  factory ScanQualityMetrics.zero() => const ScanQualityMetrics(
    lighting: 0,
    bodyVisibility: 0,
    poseAccuracy: 0,
    cameraDistance: 0,
    overall: 0,
  );

  /// Whether overall quality is sufficient to allow scanning.
  bool get isSufficientForCapture => overall >= 0.65;
}

/// Evaluates real-time scan quality from camera frames and pose data.
class ScanQualityEvaluator {
  ScanQualityMetrics _last = ScanQualityMetrics.zero();

  ScanQualityMetrics get current => _last;

  /// Evaluate quality from the current frame and pose result.
  ScanQualityMetrics evaluate({
    required CameraImage frame,
    required ProcessedLandmarks? landmarks,
    required APoseValidationResult? poseValidation,
  }) {
    final lighting = _evaluateLighting(frame);
    final bodyVisibility = _evaluateBodyVisibility(landmarks);
    final poseAccuracy = _evaluatePoseAccuracy(poseValidation);
    final cameraDistance = _evaluateCameraDistance(landmarks);

    final overall =
        (lighting * 0.20 +
                bodyVisibility * 0.30 +
                poseAccuracy * 0.30 +
                cameraDistance * 0.20)
            .clamp(0.0, 1.0);

    _last = ScanQualityMetrics(
      lighting: lighting,
      bodyVisibility: bodyVisibility,
      poseAccuracy: poseAccuracy,
      cameraDistance: cameraDistance,
      overall: overall,
    );

    return _last;
  }

  /// Estimate lighting quality from YUV luma plane.
  double _evaluateLighting(CameraImage frame) {
    try {
      final yPlane = frame.planes[0].bytes;
      final sampleStep = (yPlane.length / 400).ceil().clamp(1, 9999);

      int sum = 0;
      int count = 0;
      for (int i = 0; i < yPlane.length; i += sampleStep) {
        sum += yPlane[i];
        count++;
      }

      if (count == 0) return 0.5;

      final mean = sum / count;

      // Good lighting: mean 80-200, bad: too dark (<60) or too bright (>220)
      if (mean < 40) return 0.1;
      if (mean < 70) return (mean - 40) / 30 * 0.5;
      if (mean <= 200) return 0.8 + (mean - 70) / 130 * 0.2;
      if (mean <= 230) return 1.0 - (mean - 200) / 30 * 0.4;
      return 0.4;
    } catch (_) {
      return 0.5;
    }
  }

  /// Evaluate body visibility from landmark confidence scores.
  double _evaluateBodyVisibility(ProcessedLandmarks? landmarks) {
    if (landmarks == null) return 0.0;

    final confidences = landmarks.allLandmarks.map((l) => l.confidence);
    final visible = confidences.where((c) => c >= 0.5).length;
    return (visible / landmarks.allLandmarks.length).clamp(0.0, 1.0);
  }

  /// Evaluate how well the pose matches A-Pose requirements.
  double _evaluatePoseAccuracy(APoseValidationResult? validation) {
    if (validation == null) return 0.0;
    if (validation.isValid) return 1.0;

    // Penalize based on number of failures
    final failCount = validation.failures.length;
    return (1.0 - failCount * 0.25).clamp(0.0, 0.9);
  }

  /// Evaluate whether the user is at the right distance.
  double _evaluateCameraDistance(ProcessedLandmarks? landmarks) {
    if (landmarks == null || landmarks.imageWidth <= 0) return 0.5;

    // Live stream frames arrive in landscape sensor space on portrait phones.
    // The long sensor axis maps to portrait screen height.
    final fraction = landmarks.estimatedBodyHeightPx / landmarks.imageWidth;

    if (fraction < 0.45) return (fraction / 0.45 * 0.5).clamp(0.0, 0.5);
    if (fraction <= 0.85) return 1.0;
    if (fraction <= 0.95) return 1.0 - (fraction - 0.85) / 0.10 * 0.4;
    return 0.4;
  }
}
