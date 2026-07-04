/// Result of calibration: the conversion factor from pixels to centimeters.
class CalibrationResult {
  /// Pixels-to-centimeters conversion factor.
  /// Multiply any pixel distance by this to get centimeters.
  final double pixelToCm;

  /// Name of the calibration method that produced this result.
  final String method;

  /// Confidence in this calibration (0.0 to 1.0).
  /// Reference object = 0.95, camera distance = 0.85,
  /// existing profile = 0.80, user height = 0.70
  final double confidence;

  /// Debug/trace values used to verify scale correctness.
  final double? sourceLengthCm;
  final double? detectedLengthPx;

  const CalibrationResult({
    required this.pixelToCm,
    required this.method,
    required this.confidence,
    this.sourceLengthCm,
    this.detectedLengthPx,
  });

  /// Whether this calibration result is usable.
  bool get isValid => pixelToCm > 0 && pixelToCm < 1.0;

  @override
  String toString() =>
      'CalibrationResult(pixelToCm: $pixelToCm, method: $method, '
      'confidence: $confidence, sourceLengthCm: $sourceLengthCm, '
      'detectedLengthPx: $detectedLengthPx)';
}

/// Input data provided to the calibration engine.
class CalibrationInput {
  /// User-provided height in centimeters (may be null).
  final double? userHeightCm;

  /// Type of reference object used (may be null if not selected).
  final ReferenceType? referenceType;

  /// Known camera distance in centimeters (may be null).
  final double? cameraDistanceCm;

  /// Existing measurements from a previous scan (may be null).
  final Map<String, double>? existingMeasurementsCm;

  /// Detected body height in pixels from pose landmarks (improved with foot
  /// and eye landmarks when available).
  final double? detectedBodyHeightPx;

  /// Detected shoulder width in pixels from pose landmarks.
  final double? detectedShoulderWidthPx;

  /// Image used for reference object detection.
  final dynamic imageForObjectDetection;

  /// Body height in pixels derived from segmentation mask bounds.
  ///
  /// This is the most accurate body-height estimate: the distance from the
  /// topmost body pixel (actual crown) to the bottommost body pixel (actual
  /// foot sole), with no landmark heuristics involved.
  /// Provided by [SegmentationResult.getBodyBounds()].
  final double? segmentationBodyHeightPx;

  /// Segmentation mask body-coverage quality (0.0–1.0).
  final double? segmentationCoverage;

  /// Quality score for the landmark set used for body-height estimation
  /// (from [ProcessedLandmarks.calibrationLandmarkQuality]).
  final double? landmarkCalibrationQuality;

  const CalibrationInput({
    this.userHeightCm,
    this.referenceType,
    this.cameraDistanceCm,
    this.existingMeasurementsCm,
    this.detectedBodyHeightPx,
    this.detectedShoulderWidthPx,
    this.imageForObjectDetection,
    this.segmentationBodyHeightPx,
    this.segmentationCoverage,
    this.landmarkCalibrationQuality,
  });

  CalibrationInput copyWith({
    double? userHeightCm,
    ReferenceType? referenceType,
    double? cameraDistanceCm,
    Map<String, double>? existingMeasurementsCm,
    double? detectedBodyHeightPx,
    double? detectedShoulderWidthPx,
    dynamic imageForObjectDetection,
    double? segmentationBodyHeightPx,
    double? segmentationCoverage,
    double? landmarkCalibrationQuality,
  }) {
    return CalibrationInput(
      userHeightCm: userHeightCm ?? this.userHeightCm,
      referenceType: referenceType ?? this.referenceType,
      cameraDistanceCm: cameraDistanceCm ?? this.cameraDistanceCm,
      existingMeasurementsCm:
          existingMeasurementsCm ?? this.existingMeasurementsCm,
      detectedBodyHeightPx:
          detectedBodyHeightPx ?? this.detectedBodyHeightPx,
      detectedShoulderWidthPx:
          detectedShoulderWidthPx ?? this.detectedShoulderWidthPx,
      imageForObjectDetection:
          imageForObjectDetection ?? this.imageForObjectDetection,
      segmentationBodyHeightPx:
          segmentationBodyHeightPx ?? this.segmentationBodyHeightPx,
      segmentationCoverage:
          segmentationCoverage ?? this.segmentationCoverage,
      landmarkCalibrationQuality:
          landmarkCalibrationQuality ?? this.landmarkCalibrationQuality,
    );
  }
}

/// Types of known reference objects for calibration.
enum ReferenceType {
  /// A4 paper: 21.0 × 29.7 cm
  a4Paper,

  /// Standard credit/bank card: 5.4 × 8.56 cm (ISO/IEC 7810 ID-1)
  creditCard,

  /// A5 paper: 14.8 × 21.0 cm
  a5Paper,
}

/// Exception thrown when calibration fails completely.
class CalibrationException implements Exception {
  final String message;
  const CalibrationException(this.message);

  @override
  String toString() => 'CalibrationException: $message';
}
