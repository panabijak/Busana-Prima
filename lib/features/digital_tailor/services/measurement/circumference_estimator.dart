import '../../models/body_outline.dart';
import '../../models/measurement_confidence.dart';
import '../../models/measurement_debug.dart';
import '../../models/processed_landmarks.dart';
import 'ellipse_circumference.dart';

/// Result of a single circumference computation with debug trace.
class CircumferenceComputationResult {
  final MeasurementWithConfidence measurement;
  final MeasurementDebugTrace trace;

  const CircumferenceComputationResult({
    required this.measurement,
    required this.trace,
  });
}

/// Estimates circumference when [FrontSideFusion] rejects bad contour data.
class CircumferenceEstimator {
  final double pixelToCm;
  final double pixelToCmSide;
  final double? userHeightCm;

  const CircumferenceEstimator({
    required this.pixelToCm,
    double? pixelToCmSide,
    this.userHeightCm,
  }) : pixelToCmSide = pixelToCmSide ?? pixelToCm;

  CircumferenceComputationResult measureChest({
    required ProcessedLandmarks frontLandmarks,
    BodyOutline? frontOutline,
    BodyOutline? sideOutline,
    double? linearChestWidthCm,
  }) {
    return _measure(
      key: 'dada',
      label: 'Dada (Chest Circumference)',
      frontLandmarks: frontLandmarks,
      frontOutline: frontOutline,
      sideOutline: sideOutline,
      frontWidth: frontOutline?.chestWidth,
      sideDepth: sideOutline?.chestWidth,
      linearWidthCm: linearChestWidthCm,
      depthRatio: _chestDepthRatio,
    );
  }

  CircumferenceComputationResult measureWaist({
    required ProcessedLandmarks frontLandmarks,
    BodyOutline? frontOutline,
    BodyOutline? sideOutline,
    double? linearWaistWidthCm,
  }) {
    return _measure(
      key: 'pinggang',
      label: 'Pinggang (Waist Circumference)',
      frontLandmarks: frontLandmarks,
      frontOutline: frontOutline,
      sideOutline: sideOutline,
      frontWidth: frontOutline?.waistWidth,
      sideDepth: sideOutline?.waistWidth,
      linearWidthCm: linearWaistWidthCm,
      depthRatio: _waistDepthRatio,
    );
  }

  CircumferenceComputationResult measureHip({
    required ProcessedLandmarks frontLandmarks,
    BodyOutline? frontOutline,
    BodyOutline? sideOutline,
    double? linearHipWidthCm,
  }) {
    return _measure(
      key: 'pinggul',
      label: 'Pinggul (Hip Circumference)',
      frontLandmarks: frontLandmarks,
      frontOutline: frontOutline,
      sideOutline: sideOutline,
      frontWidth: frontOutline?.hipWidth,
      sideDepth: sideOutline?.hipWidth,
      linearWidthCm: linearHipWidthCm,
      depthRatio: _hipDepthRatio,
    );
  }

  CircumferenceComputationResult measureNeck({
    required ProcessedLandmarks frontLandmarks,
  }) {
    final neckWidthCm = frontLandmarks.shoulderWidth * pixelToCm * 0.35;
    final halfWidthCm = neckWidthCm / 2;
    final halfDepthCm = halfWidthCm * 0.80;
    final circumference =
        EllipseCircumference.fromSemiAxes(halfWidthCm, halfDepthCm);

    final measurement = MeasurementWithConfidence(
      key: 'lingkar_leher',
      label: 'Neck Circumference',
      valueCm: EllipseCircumference.round1(circumference),
      valueInch: EllipseCircumference.round1(circumference / 2.54),
      confidence: 0.50,
      source: MeasurementSource.estimation,
      region: 'atas',
    );

    return CircumferenceComputationResult(
      measurement: measurement,
      trace: MeasurementDebugTrace(
        key: 'lingkar_leher',
        label: 'Neck Circumference',
        widthPx: frontLandmarks.shoulderWidth * 0.35,
        pixelToCm: pixelToCm,
        contourWidthCm: neckWidthCm,
        semiAxisAcm: halfWidthCm,
        semiAxisBcm: halfDepthCm,
        finalCm: measurement.valueCm,
        confidence: 0.50,
        method: 'shoulderWidth × 0.35 estimate',
      ),
    );
  }

  CircumferenceComputationResult _measure({
    required String key,
    required String label,
    required ProcessedLandmarks frontLandmarks,
    BodyOutline? frontOutline,
    BodyOutline? sideOutline,
    BodyWidthResult? frontWidth,
    BodyWidthResult? sideDepth,
    double? linearWidthCm,
    required double Function(ProcessedLandmarks) depthRatio,
  }) {
    double fullWidthCm;
    double? widthPx;
    bool usedSegWidth = false;

    if (frontWidth != null && frontWidth.isValid) {
      fullWidthCm = frontWidth.widthPx * pixelToCm;
      widthPx = frontWidth.widthPx;
      usedSegWidth = true;
    } else {
      final approxWidth =
          frontLandmarks.shoulderWidth * 0.85 + frontLandmarks.hipWidth * 0.15;
      fullWidthCm = approxWidth * pixelToCm;
      widthPx = approxWidth;
    }

    if (linearWidthCm != null && linearWidthCm > 0) {
      fullWidthCm = linearWidthCm;
    }

    final halfWidthCm = fullWidthCm / 2;
    // Raw depth: measured side depth if present, else a build-adjusted estimate.
    double rawDepthCm;
    double? depthPx;
    String method;
    double baseConfidence;
    MeasurementSource source;

    if (sideDepth != null && sideDepth.isValid) {
      rawDepthCm = sideDepth.widthPx * pixelToCmSide;
      depthPx = sideDepth.widthPx;
      method = 'front width + side torso depth';
      baseConfidence = 0.78;
      source = MeasurementSource.frontSideFusion;
    } else {
      // No side reading: estimate depth from build ratio (× full width).
      rawDepthCm = fullWidthCm * depthRatio(frontLandmarks);
      method = 'build-adjusted depth ratio fallback';
      baseConfidence = usedSegWidth ? 0.62 : 0.48;
      source = usedSegWidth
          ? MeasurementSource.segmentation
          : MeasurementSource.estimation;
    }

    // TASK 1: anatomical depth normalization (clamp, never reject).
    final norm = EllipseCircumference.normalizeDepth(
      depthCm: rawDepthCm,
      frontWidthCm: fullWidthCm,
    );
    final fullDepthCm = norm.depthCm;
    final halfDepthCm = fullDepthCm / 2;
    double confidence = baseConfidence;
    if (norm.clamped) {
      method = '$method → depth clamped';
      confidence = (confidence * 0.80).clamp(0.40, 0.93);
    }

    // Accurate Ramanujan estimator — stabilised by the depth clamp above.
    final circumference = EllipseCircumference.fromFull(
      fullWidthCm: fullWidthCm,
      fullDepthCm: fullDepthCm,
    );

    final measurement = MeasurementWithConfidence(
      key: key,
      label: label,
      valueCm: EllipseCircumference.round1(circumference),
      valueInch: EllipseCircumference.round1(circumference / 2.54),
      confidence: confidence,
      source: source,
      region: 'tengah',
    );

    return CircumferenceComputationResult(
      measurement: measurement,
      trace: MeasurementDebugTrace(
        key: key,
        label: label,
        widthPx: widthPx,
        depthPx: depthPx,
        pixelToCm: pixelToCm,
        pixelToCmSide: pixelToCmSide,
        contourWidthCm: fullWidthCm,
        contourDepthCm: depthPx != null ? depthPx * pixelToCmSide : null,
        semiAxisAcm: halfWidthCm,
        semiAxisBcm: halfDepthCm,
        finalCm: measurement.valueCm,
        confidence: confidence,
        method: method,
      ),
    );
  }

  double _buildIndex(ProcessedLandmarks lm) {
    final shoulderCm = lm.shoulderWidth * pixelToCm;
    final heightCm = userHeightCm ?? (lm.estimatedBodyHeightPx * pixelToCm);
    if (heightCm <= 0) return 0.22;
    return (shoulderCm / heightCm).clamp(0.10, 0.40);
  }

  double _chestDepthRatio(ProcessedLandmarks lm) {
    final bi = _buildIndex(lm);
    return (0.67 + (bi - 0.15) / (0.30 - 0.15) * (0.80 - 0.67)).clamp(
      0.65,
      0.82,
    );
  }

  double _waistDepthRatio(ProcessedLandmarks lm) {
    final bi = _buildIndex(lm);
    return (0.64 + (bi - 0.15) / (0.30 - 0.15) * (0.76 - 0.64)).clamp(
      0.60,
      0.78,
    );
  }

  double _hipDepthRatio(ProcessedLandmarks lm) {
    final bi = _buildIndex(lm);
    return (0.76 + (bi - 0.15) / (0.30 - 0.15) * (0.84 - 0.76)).clamp(
      0.72,
      0.86,
    );
  }
}
