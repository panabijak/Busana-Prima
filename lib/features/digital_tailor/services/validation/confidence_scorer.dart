import 'dart:math';

import '../../models/calibration_result.dart';
import '../../models/measurement_confidence.dart';
import '../../models/processed_landmarks.dart';
import 'quality_controller.dart';

/// Computes overall and per-measurement confidence scores.
///
/// Factors:
/// 1. Landmark detection confidence (from ML Kit)
/// 2. Calibration method confidence (reference object > height)
/// 3. Whether side data was available (fusion > front-only)
/// 4. Quality validation results
class ConfidenceScorer {
  /// Calculate confidence report.
  ConfidenceReport score({
    required List<MeasurementWithConfidence> measurements,
    required ProcessedLandmarks frontLandmarks,
    required ProcessedLandmarks? sideLandmarks,
    required CalibrationResult calibration,
    required QualityReport quality,
  }) {
    final perMeasurement = <String, double>{};

    for (final m in measurements) {
      double confidence = m.confidence;

      // Factor in calibration confidence
      confidence *= calibration.confidence;

      // Bonus if side data was used (fusion measurements are more accurate)
      if (m.source == MeasurementSource.frontSideFusion) {
        confidence = min(1.0, confidence * 1.05);
      }

      // Penalty for quality issues flagged against THIS measurement.
      // Plausibility warnings never block the scan (see QualityController) —
      // instead they collapse the measurement's confidence so it surfaces as
      // LOW CONFIDENCE in the UI. Out-of-range values are penalised hardest.
      final issuesForKey =
          quality.issues.where((i) => i.measurementKey == m.key);
      for (final issue in issuesForKey) {
        switch (issue.type) {
          case QualityIssueType.outOfRange:
            confidence *= 0.40;
            break;
          case QualityIssueType.inconsistentRatio:
            confidence *= 0.55;
            break;
          default:
            confidence *= 0.75;
        }
      }

      // Factor in average landmark confidence
      confidence *= (frontLandmarks.averageConfidence * 0.6 + 0.4);

      perMeasurement[m.key] = confidence.clamp(0.0, 1.0);
    }

    // Overall: geometric mean of per-measurement scores
    double overall = 0.0;
    if (perMeasurement.isNotEmpty) {
      final product = perMeasurement.values.reduce((a, b) => a * b);
      overall = pow(product, 1.0 / perMeasurement.length).toDouble();
    }

    return ConfidenceReport(
      overall: overall.clamp(0.0, 1.0),
      perMeasurement: perMeasurement,
      label: ConfidenceReport.labelFor(overall),
    );
  }
}
