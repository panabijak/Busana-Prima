import '../../models/body_outline.dart';
import '../../models/measurement_confidence.dart';
import '../../models/measurement_debug.dart';
import '../../models/processed_landmarks.dart';
import 'circumference_estimator.dart';
import 'ellipse_circumference.dart';
import 'front_side_fusion.dart';
import 'linear_measurer.dart';

/// Output of [MeasurementEngine.computeAll] including developer traces.
class MeasurementComputationResult {
  final List<MeasurementWithConfidence> measurements;
  final List<MeasurementDebugTrace> debugTraces;

  const MeasurementComputationResult({
    required this.measurements,
    required this.debugTraces,
  });
}

/// Orchestrates linear + circumference body measurements.
class MeasurementEngine {
  MeasurementComputationResult computeAll({
    required ProcessedLandmarks frontLandmarks,
    ProcessedLandmarks? sideLandmarks,
    BodyOutline? frontOutline,
    BodyOutline? sideOutline,
    required double pixelToCm,
    double? pixelToCmSide,
    double? userHeightCm,
  }) {
    final sideScale = pixelToCmSide ?? pixelToCm;
    final linear = LinearMeasurer(pixelToCm: pixelToCm);
    final circumference = CircumferenceEstimator(
      pixelToCm: pixelToCm,
      pixelToCmSide: sideScale,
      userHeightCm: userHeightCm,
    );
    final measurements = <MeasurementWithConfidence>[];
    final traces = <MeasurementDebugTrace>[];

    void addLinear(
      MeasurementWithConfidence m, {
      double? widthPx,
      String? method,
    }) {
      measurements.add(m);
      traces.add(
        MeasurementDebugTrace(
          key: m.key,
          label: m.label,
          widthPx: widthPx,
          pixelToCm: pixelToCm,
          contourWidthCm: widthPx != null ? widthPx * pixelToCm : m.valueCm,
          finalCm: m.valueCm,
          confidence: m.confidence,
          method: method ?? m.source.name,
        ),
      );
    }

    final shoulder = linear.measureShoulderWidth(
      landmarks: frontLandmarks,
      outline: frontOutline,
    );
    addLinear(
      shoulder,
      widthPx: frontOutline?.shoulderWidth.isValid == true
          ? frontOutline!.shoulderWidth.widthPx
          : frontLandmarks.shoulderWidth,
      method: shoulder.source.name,
    );

    final sleeve = linear.measureSleeveLength(
      landmarks: frontLandmarks,
      userHeightCm: userHeightCm,
    );
    addLinear(
      sleeve,
      widthPx: frontLandmarks.leftArmLength,
      method: sleeve.source == MeasurementSource.estimation
          ? 'arm foreshortened → 0.32 × height'
          : 'landmark arm length px',
    );
    addLinear(
      linear.measureTorsoHeight(landmarks: frontLandmarks),
      widthPx: null,
      method: 'shoulderMid → hipMid',
    );
    addLinear(
      linear.measureBackLength(landmarks: frontLandmarks),
      widthPx: null,
      method: 'neckPoint → waist level',
    );
    addLinear(
      linear.measureLegLength(landmarks: frontLandmarks),
      widthPx: (frontLandmarks.leftLegLength + frontLandmarks.rightLegLength) / 2,
      method: 'hip → knee → ankle',
    );

    final chestW = linear.measureChestWidth(
      landmarks: frontLandmarks,
      outline: frontOutline,
      shoulderWidthCm: shoulder.valueCm,
    );
    addLinear(
      chestW,
      widthPx: frontOutline?.chestWidth.isValid == true
          ? frontOutline!.chestWidth.widthPx
          : null,
      method: chestW.source.name,
    );

    final waistW = linear.measureWaistWidth(
      landmarks: frontLandmarks,
      outline: frontOutline,
      shoulderWidthCm: shoulder.valueCm,
    );
    addLinear(
      waistW,
      widthPx: frontOutline?.waistWidth.isValid == true
          ? frontOutline!.waistWidth.widthPx
          : null,
      method: waistW.source.name,
    );

    final hipW = linear.measureHipWidth(
      landmarks: frontLandmarks,
      outline: frontOutline,
      shoulderWidthCm: shoulder.valueCm,
    );
    addLinear(
      hipW,
      widthPx: frontOutline?.hipWidth.isValid == true
          ? frontOutline!.hipWidth.widthPx
          : null,
      method: hipW.source.name,
    );

    // ─── Circumference (front width + side torso depth) ───────────
    if (frontOutline != null && sideOutline != null) {
      final fusion = FrontSideFusion(
        pixelToCmFront: pixelToCm,
        pixelToCmSide: sideScale,
      );
      final fused = fusion.fuse(
        frontOutline: frontOutline,
        sideOutline: sideOutline,
        chestLinearWidthCm: chestW.valueCm,
        waistLinearWidthCm: waistW.valueCm,
        hipLinearWidthCm: hipW.valueCm,
      );

      if (fused != null) {
        void addFused(String key, String label, FusedMeasurement? fm) {
          if (fm == null) return;
          measurements.add(
            MeasurementWithConfidence(
              key: key,
              label: label,
              valueCm: fm.valueCm,
              valueInch: fm.valueInch,
              confidence: fm.confidence,
              source: MeasurementSource.frontSideFusion,
              region: 'tengah',
            ),
          );
          traces.add(
            MeasurementDebugTrace(
              key: key,
              label: label,
              widthPx: fm.widthPx,
              depthPx: fm.depthPx,
              pixelToCm: pixelToCm,
              pixelToCmSide: sideScale,
              contourWidthCm: fm.fullWidthCm,
              contourDepthCm: fm.fullDepthCm,
              semiAxisAcm: fm.halfWidthCm,
              semiAxisBcm: fm.halfDepthCm,
              finalCm: fm.valueCm,
              confidence: fm.confidence,
              method: fm.depthClamped
                  ? 'frontSideFusion (Ramanujan II, depth clamped)'
                  : 'frontSideFusion (Ramanujan II)',
            ),
          );
        }

        addFused('dada', 'Dada (Chest Circumference)', fused.chestCircumference);
        addFused(
          'pinggang',
          'Pinggang (Waist Circumference)',
          fused.waistCircumference,
        );
        addFused(
          'pinggul',
          'Pinggul (Hip Circumference)',
          fused.hipCircumference,
        );
      }
    }

    final hasChest = measurements.any((m) => m.key == 'dada');
    final hasWaist = measurements.any((m) => m.key == 'pinggang');
    final hasHip = measurements.any((m) => m.key == 'pinggul');

    void addCirc(MeasurementWithConfidence m, MeasurementDebugTrace t) {
      measurements.add(m);
      traces.add(t);
    }

    if (!hasChest) {
      final r = circumference.measureChest(
        frontLandmarks: frontLandmarks,
        frontOutline: frontOutline,
        sideOutline: sideOutline,
        linearChestWidthCm: chestW.valueCm,
      );
      addCirc(r.measurement, r.trace);
    }
    if (!hasWaist) {
      final r = circumference.measureWaist(
        frontLandmarks: frontLandmarks,
        frontOutline: frontOutline,
        sideOutline: sideOutline,
        linearWaistWidthCm: waistW.valueCm,
      );
      addCirc(r.measurement, r.trace);
    }
    if (!hasHip) {
      final r = circumference.measureHip(
        frontLandmarks: frontLandmarks,
        frontOutline: frontOutline,
        sideOutline: sideOutline,
        linearHipWidthCm: hipW.valueCm,
      );
      addCirc(r.measurement, r.trace);
    }

    final neck = circumference.measureNeck(frontLandmarks: frontLandmarks);
    addCirc(
      neck.measurement,
      neck.trace,
    );

    // ─── TASK 6: bias detection (front-only vs fused circumference) ─────
    // Front-only reference assumes a TYPICAL depth (0.70 × width). Comparing
    // it to the fused value reveals whether the side depth is systematically
    // inflating (XL bias) or collapsing (M bias) the estimate.
    _appendBiasTrace(
      traces: traces,
      measurements: measurements,
      widths: {
        'dada': chestW.valueCm,
        'pinggang': waistW.valueCm,
        'pinggul': hipW.valueCm,
      },
    );

    return MeasurementComputationResult(
      measurements: measurements,
      debugTraces: traces,
    );
  }

  void _appendBiasTrace({
    required List<MeasurementDebugTrace> traces,
    required List<MeasurementWithConfidence> measurements,
    required Map<String, double> widths,
  }) {
    double? finalOf(String key) {
      try {
        return measurements.firstWhere((m) => m.key == key).valueCm;
      } catch (_) {
        return null;
      }
    }

    const typicalDepthRatio = 0.70;
    final samples = <double>[];
    widths.forEach((key, widthCm) {
      final fused = finalOf(key);
      if (fused == null || widthCm <= 0) return;
      final frontOnly = EllipseCircumference.fromFull(
        fullWidthCm: widthCm,
        fullDepthCm: widthCm * typicalDepthRatio,
      );
      if (frontOnly <= 0) return;
      samples.add((fused - frontOnly) / frontOnly);
    });

    if (samples.isEmpty) return;
    final meanBias =
        samples.reduce((a, b) => a + b) / samples.length * 100;
    final direction = meanBias > 5
        ? 'OVERESTIMATE (XL bias)'
        : meanBias < -5
            ? 'UNDERESTIMATE (M bias)'
            : 'balanced';
    traces.add(
      MeasurementDebugTrace(
        key: '_bias',
        label: 'Bias (front vs fusion)',
        finalCm: (meanBias * 10).roundToDouble() / 10,
        confidence: 1.0,
        method: 'mean Δ ${meanBias.toStringAsFixed(1)}% → $direction',
      ),
    );
  }
}
