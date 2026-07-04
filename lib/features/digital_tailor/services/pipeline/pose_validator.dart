import 'dart:math';

import '../../models/processed_landmarks.dart';

/// Result of T-Pose validation.
class PoseValidationResult {
  /// Whether all pose checks pass.
  final bool isValid;

  /// Whether the pose has been stable for enough consecutive frames.
  final bool isStable;

  /// Which checks failed (for UI guidance).
  final List<String> failedChecks;

  /// Number of consecutive frames that passed all checks.
  final int stableFrameCount;

  /// Required frames for stability.
  final int requiredFrames;

  const PoseValidationResult({
    required this.isValid,
    required this.isStable,
    required this.failedChecks,
    required this.stableFrameCount,
    required this.requiredFrames,
  });

  /// Progress toward stability (0.0 to 1.0).
  double get stabilityProgress =>
      (stableFrameCount / requiredFrames).clamp(0.0, 1.0);

  /// User-facing guidance based on failed checks.
  String? get guidance {
    if (failedChecks.isEmpty) return null;
    if (failedChecks.contains('arms_horizontal')) {
      return 'Rentangkan kedua tangan secara horizontal';
    }
    if (failedChecks.contains('shoulders_level')) {
      return 'Luruskan kedua bahu';
    }
    if (failedChecks.contains('legs_visible')) {
      return 'Pastikan kedua kaki terlihat';
    }
    if (failedChecks.contains('body_centered')) {
      return 'Posisikan tubuh di tengah layar';
    }
    if (failedChecks.contains('standing_straight')) {
      return 'Berdiri tegak lurus';
    }
    return 'Perbaiki posisi berdiri';
  }
}

/// Validates that the user is in a correct T-Pose for measurement.
///
/// T-Pose requirements:
/// - Both arms extended horizontally (within ±15° of horizontal)
/// - Shoulders level (y-difference < 3% of shoulder width)
/// - Both legs visible and roughly vertical
/// - Body centered in frame
/// - Standing straight (hip-ankle alignment)
///
/// Requires [requiredStableFrames] consecutive valid frames before
/// allowing capture. This eliminates transient noise.
class PoseValidator {
  /// Tolerance for arm angle from horizontal (degrees).
  static const double armAngleTolerance = 15.0;

  /// Maximum shoulder level difference as fraction of shoulder width.
  static const double shoulderLevelTolerance = 0.03;

  /// Maximum body center offset from frame center (fraction of frame width).
  static const double centerTolerance = 0.15;

  /// Consecutive valid frames required before capture is allowed.
  static const int requiredStableFrames = 15;

  int _consecutiveValidFrames = 0;

  /// Validate the current pose.
  PoseValidationResult validate(ProcessedLandmarks landmarks) {
    final checks = <String, bool>{
      'arms_horizontal': _checkArmsHorizontal(landmarks),
      'shoulders_level': _checkShouldersLevel(landmarks),
      'legs_visible': _checkLegsVisible(landmarks),
      'body_centered': _checkBodyCentered(landmarks),
      'standing_straight': _checkStandingStraight(landmarks),
    };

    final allValid = checks.values.every((v) => v);

    if (allValid) {
      _consecutiveValidFrames++;
    } else {
      _consecutiveValidFrames = 0;
    }

    return PoseValidationResult(
      isValid: allValid,
      isStable: _consecutiveValidFrames >= requiredStableFrames,
      failedChecks: checks.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList(),
      stableFrameCount: _consecutiveValidFrames,
      requiredFrames: requiredStableFrames,
    );
  }

  /// Reset the stability counter (e.g., when switching front→side).
  void reset() {
    _consecutiveValidFrames = 0;
  }

  /// Check both arms are approximately horizontal.
  bool _checkArmsHorizontal(ProcessedLandmarks landmarks) {
    // Left arm angle: angle of line from shoulder to wrist relative to horizontal
    final leftAngle = _angleDegFromHorizontal(
      landmarks.leftShoulder.x,
      landmarks.leftShoulder.y,
      landmarks.leftWrist.x,
      landmarks.leftWrist.y,
    );

    final rightAngle = _angleDegFromHorizontal(
      landmarks.rightShoulder.x,
      landmarks.rightShoulder.y,
      landmarks.rightWrist.x,
      landmarks.rightWrist.y,
    );

    return leftAngle.abs() < armAngleTolerance &&
        rightAngle.abs() < armAngleTolerance;
  }

  /// Check shoulders are level.
  bool _checkShouldersLevel(ProcessedLandmarks landmarks) {
    final yDiff = (landmarks.leftShoulder.y - landmarks.rightShoulder.y).abs();
    return yDiff < landmarks.shoulderWidth * shoulderLevelTolerance;
  }

  /// Check both legs (knees and ankles) are detected with reasonable confidence.
  bool _checkLegsVisible(ProcessedLandmarks landmarks) {
    return landmarks.leftKnee.confidence >= 0.4 &&
        landmarks.rightKnee.confidence >= 0.4 &&
        landmarks.leftAnkle.confidence >= 0.4 &&
        landmarks.rightAnkle.confidence >= 0.4;
  }

  /// Check body is centered in frame.
  bool _checkBodyCentered(ProcessedLandmarks landmarks) {
    final bodyCenter = landmarks.shoulderMidpoint.x;
    final frameCenter = landmarks.imageWidth / 2;
    final offset = (bodyCenter - frameCenter).abs() / landmarks.imageWidth;
    return offset < centerTolerance;
  }

  /// Check user is standing straight (hips above ankles).
  bool _checkStandingStraight(ProcessedLandmarks landmarks) {
    // Hip midpoint x should be close to ankle midpoint x
    final hipCenterX = (landmarks.leftHip.x + landmarks.rightHip.x) / 2;
    final ankleCenterX = (landmarks.leftAnkle.x + landmarks.rightAnkle.x) / 2;
    final offset = (hipCenterX - ankleCenterX).abs();
    // Allow some tolerance relative to body width
    return offset < landmarks.shoulderWidth * 0.15;
  }

  /// Compute angle from horizontal in degrees.
  /// 0° = perfectly horizontal, positive = pointing down.
  double _angleDegFromHorizontal(double x1, double y1, double x2, double y2) {
    final dy = y2 - y1;
    final dx = x2 - x1;
    if (dx.abs() < 1) return 90; // Vertical
    return atan(dy / dx) * 180 / pi;
  }
}
