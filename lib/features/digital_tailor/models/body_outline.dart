/// Result of measuring body width at a specific y-coordinate
/// from the segmentation mask.
class BodyWidthResult {
  /// Width of the body in image pixels at this y-coordinate.
  final double widthPx;

  /// Left edge x-coordinate in image pixels.
  final double leftEdgePx;

  /// Right edge x-coordinate in image pixels.
  final double rightEdgePx;

  /// Confidence of this width measurement (0.0 to 1.0).
  final double confidence;

  /// Whether this measurement was found in the segmentation mask.
  final bool isValid;

  const BodyWidthResult({
    required this.widthPx,
    required this.leftEdgePx,
    required this.rightEdgePx,
    required this.confidence,
    this.isValid = true,
  });

  factory BodyWidthResult.notFound() => const BodyWidthResult(
    widthPx: 0,
    leftEdgePx: 0,
    rightEdgePx: 0,
    confidence: 0,
    isValid: false,
  );
}

/// Complete body outline with widths at all measurement-critical y-positions.
///
/// Derived from the segmentation mask rather than pose landmarks alone.
/// This gives the ACTUAL body surface width including soft tissue,
/// not just skeletal joint positions.
class BodyOutline {
  /// Body width at shoulder level
  final BodyWidthResult shoulderWidth;

  /// Body width at chest level (25% between shoulder and hip)
  final BodyWidthResult chestWidth;

  /// Body width at waist level (narrowest between chest and hip, ~60%)
  final BodyWidthResult waistWidth;

  /// Body width at hip level (widest point at/below hip landmarks)
  final BodyWidthResult hipWidth;

  /// Body width at upper arm (optional, for arm circumference)
  final BodyWidthResult? upperArmWidth;

  /// Body width at thigh (optional, for thigh circumference)
  final BodyWidthResult? thighWidth;

  const BodyOutline({
    required this.shoulderWidth,
    required this.chestWidth,
    required this.waistWidth,
    required this.hipWidth,
    this.upperArmWidth,
    this.thighWidth,
  });

  /// Whether all primary measurements are valid
  bool get isComplete =>
      shoulderWidth.isValid &&
      chestWidth.isValid &&
      waistWidth.isValid &&
      hipWidth.isValid;

  /// Average confidence across all valid measurements
  double get averageConfidence {
    final valid = [
      shoulderWidth,
      chestWidth,
      waistWidth,
      hipWidth,
    ].where((w) => w.isValid).toList();
    if (valid.isEmpty) return 0;
    return valid.map((w) => w.confidence).reduce((a, b) => a + b) /
        valid.length;
  }
}
