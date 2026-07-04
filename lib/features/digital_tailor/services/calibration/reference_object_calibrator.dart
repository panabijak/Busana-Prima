import 'dart:ui';

import '../../models/calibration_result.dart';
import 'calibration_engine.dart';

/// Calibration using a known-size reference object (e.g., A4 paper, credit card).
///
/// This is the highest-confidence calibration method because we know the
/// exact real-world dimensions of the object. The user holds it visible
/// in the frame, and we detect its edges to compute pixel-to-cm.
///
/// Current implementation: Placeholder that will integrate edge/rectangle
/// detection. For now, the user can manually confirm the object is visible
/// and we use the known dimensions.
class ReferenceObjectCalibrator extends CalibrationStrategy {
  /// Known object dimensions in centimeters (width × height).
  static const Map<ReferenceType, Size> knownSizes = {
    ReferenceType.a4Paper: Size(21.0, 29.7),
    ReferenceType.creditCard: Size(5.4, 8.56),
    ReferenceType.a5Paper: Size(14.8, 21.0),
  };

  @override
  int get priority => 1; // Highest priority

  @override
  String get methodName => 'reference_object';

  @override
  bool isAvailable(CalibrationInput input) {
    return input.referenceType != null && input.imageForObjectDetection != null;
  }

  @override
  Future<CalibrationResult?> calibrate(CalibrationInput input) async {
    if (input.referenceType == null) return null;

    final knownSize = knownSizes[input.referenceType!];
    if (knownSize == null) return null;

    // TODO: Implement rectangle detection using edge detection
    // For now, this strategy is available but will return null
    // until the rectangle detector is implemented.
    //
    // The implementation would:
    // 1. Convert image to grayscale
    // 2. Apply Canny edge detection
    // 3. Find contours
    // 4. Filter for rectangular contours with correct aspect ratio
    // 5. Measure the rectangle's pixel dimensions
    // 6. Compute pixelToCm = knownSize.height / detectedHeightPx

    // Placeholder: not yet implemented
    return null;
  }
}
