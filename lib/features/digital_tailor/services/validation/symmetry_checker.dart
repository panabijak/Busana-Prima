import 'dart:math';

import '../../models/processed_landmarks.dart';

/// Result of a symmetry check.
class SymmetryResult {
  /// Whether the body is sufficiently symmetric.
  final bool isSymmetric;

  /// Maximum deviation found (0.0 = perfect symmetry, 1.0 = completely off).
  final double deviation;

  /// Human-readable explanation of the asymmetry.
  final String? details;

  const SymmetryResult({
    required this.isSymmetric,
    required this.deviation,
    this.details,
  });
}

/// Checks left-right body symmetry to detect tilted or rotated poses.
///
/// A well-positioned frontal scan should have:
/// - Equal arm lengths (left ≈ right)
/// - Equal leg lengths (left ≈ right)
/// - Level shoulders (minimal y-difference)
/// - Level hips
///
/// If significant asymmetry is detected, the pose is likely invalid
/// (user turned, leaning, or one limb occluded).
class SymmetryChecker {
  /// Maximum acceptable asymmetry as a fraction (10% = 0.10).
  static const double maxAsymmetry = 0.10;

  /// Check body symmetry from processed landmarks.
  SymmetryResult check(ProcessedLandmarks landmarks) {
    final deviations = <String, double>{};

    // 1. Arm length symmetry
    final leftArm = landmarks.leftArmLength;
    final rightArm = landmarks.rightArmLength;
    if (leftArm > 0 && rightArm > 0) {
      deviations['arms'] =
          (leftArm - rightArm).abs() / ((leftArm + rightArm) / 2);
    }

    // 2. Leg length symmetry
    final leftLeg = landmarks.leftLegLength;
    final rightLeg = landmarks.rightLegLength;
    if (leftLeg > 0 && rightLeg > 0) {
      deviations['legs'] =
          (leftLeg - rightLeg).abs() / ((leftLeg + rightLeg) / 2);
    }

    // 3. Shoulder level (y-difference relative to shoulder width)
    final shoulderYDiff = (landmarks.leftShoulder.y - landmarks.rightShoulder.y)
        .abs();
    if (landmarks.shoulderWidth > 0) {
      deviations['shoulders'] = shoulderYDiff / landmarks.shoulderWidth;
    }

    // 4. Hip level
    final hipYDiff = (landmarks.leftHip.y - landmarks.rightHip.y).abs();
    if (landmarks.hipWidth > 0) {
      deviations['hips'] = hipYDiff / landmarks.hipWidth;
    }

    if (deviations.isEmpty) {
      return const SymmetryResult(isSymmetric: true, deviation: 0);
    }

    final maxDev = deviations.values.reduce(max);
    final worstKey = deviations.entries
        .firstWhere((e) => e.value == maxDev)
        .key;

    String? details;
    if (maxDev > maxAsymmetry) {
      final pct = (maxDev * 100).toStringAsFixed(1);
      switch (worstKey) {
        case 'arms':
          details = 'Panjang lengan tidak seimbang ($pct% deviasi)';
          break;
        case 'legs':
          details = 'Panjang kaki tidak seimbang ($pct% deviasi)';
          break;
        case 'shoulders':
          details = 'Bahu tidak rata ($pct% deviasi)';
          break;
        case 'hips':
          details = 'Pinggul tidak rata ($pct% deviasi)';
          break;
      }
    }

    return SymmetryResult(
      isSymmetric: maxDev <= maxAsymmetry,
      deviation: maxDev,
      details: details,
    );
  }
}
