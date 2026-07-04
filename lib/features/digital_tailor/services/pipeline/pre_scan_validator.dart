import '../../models/processed_landmarks.dart';

/// Result of a single pre-scan check.
class ValidationCheckResult {
  final bool passed;
  final String label;
  final String? guidance;

  const ValidationCheckResult({
    required this.passed,
    required this.label,
    this.guidance,
  });
}

/// Complete pre-scan validation report.
class PreScanReport {
  final List<ValidationCheckResult> checks;

  const PreScanReport(this.checks);

  /// Whether all checks pass and scanning can proceed.
  bool get isReady => checks.every((c) => c.passed);

  /// Checks that failed (for user guidance).
  List<ValidationCheckResult> get failed =>
      checks.where((c) => !c.passed).toList();

  /// Number of passed checks out of total.
  String get summary =>
      '${checks.where((c) => c.passed).length}/${checks.length}';
}

/// Validates pre-scan conditions using a quick pose detection result.
///
/// Checks:
/// - Full body visible (all major joints detected)
/// - Correct distance (body occupies 60-85% of frame height)
/// - Standing posture (body is roughly vertical)
///
/// Note: Lighting and background checks would require raw camera frame
/// analysis. For now, we validate what we can from pose detection results.
class PreScanValidator {
  /// Minimum body height as fraction of frame (too far away).
  static const double minBodyFraction = 0.55;

  /// Maximum body height as fraction of frame (too close).
  static const double maxBodyFraction = 0.90;

  /// Minimum landmarks that must be detected for "full body visible".
  static const int minLandmarkCount = 11;

  /// Run all pre-scan checks using a quick pose detection result.
  ///
  /// [landmarks] - Result of a quick pose detection on the preview frame.
  /// If null, all checks fail (no pose detected).
  PreScanReport validate({
    ProcessedLandmarks? landmarks,
    int frameWidth = 1080,
    int frameHeight = 1920,
  }) {
    if (landmarks == null) {
      return PreScanReport([
        const ValidationCheckResult(
          passed: false,
          label: 'Deteksi Tubuh',
          guidance:
              'Tidak ada tubuh terdeteksi. Pastikan seluruh tubuh terlihat.',
        ),
        const ValidationCheckResult(
          passed: false,
          label: 'Jarak',
          guidance: 'Posisikan diri anda dalam jangkauan kamera.',
        ),
        const ValidationCheckResult(
          passed: false,
          label: 'Posisi Berdiri',
          guidance: 'Berdiri tegak menghadap kamera.',
        ),
      ]);
    }

    return PreScanReport([
      _checkFullBody(landmarks),
      _checkDistance(landmarks, frameHeight),
      _checkStanding(landmarks),
    ]);
  }

  /// Check that the full body is visible (enough landmarks detected).
  ValidationCheckResult _checkFullBody(ProcessedLandmarks landmarks) {
    final visibleCount = landmarks.allLandmarks
        .where((lm) => lm.confidence >= 0.3)
        .length;

    return ValidationCheckResult(
      passed: visibleCount >= minLandmarkCount,
      label: 'Seluruh Tubuh Terlihat',
      guidance: visibleCount < minLandmarkCount
          ? 'Pastikan seluruh tubuh dari kepala hingga kaki terlihat'
          : null,
    );
  }

  /// Check that the user is at the correct distance from camera.
  ValidationCheckResult _checkDistance(
    ProcessedLandmarks landmarks,
    int frameHeight,
  ) {
    final bodyHeight = landmarks.estimatedBodyHeightPx;
    final fraction = bodyHeight / frameHeight;

    String? guidance;
    if (fraction < minBodyFraction) {
      guidance = 'Terlalu jauh — maju mendekati kamera';
    } else if (fraction > maxBodyFraction) {
      guidance = 'Terlalu dekat — mundur dari kamera';
    }

    return ValidationCheckResult(
      passed: fraction >= minBodyFraction && fraction <= maxBodyFraction,
      label: 'Jarak Kamera',
      guidance: guidance,
    );
  }

  /// Check that the user is standing (roughly vertical body axis).
  ValidationCheckResult _checkStanding(ProcessedLandmarks landmarks) {
    // Hip center should be approximately above ankle center
    final hipCenterX = (landmarks.leftHip.x + landmarks.rightHip.x) / 2;
    final ankleCenterX = (landmarks.leftAnkle.x + landmarks.rightAnkle.x) / 2;
    final offset = (hipCenterX - ankleCenterX).abs();
    final tolerance = landmarks.shoulderWidth * 0.2;

    return ValidationCheckResult(
      passed: offset < tolerance,
      label: 'Posisi Berdiri',
      guidance: offset >= tolerance
          ? 'Berdiri tegak lurus menghadap kamera'
          : null,
    );
  }
}
