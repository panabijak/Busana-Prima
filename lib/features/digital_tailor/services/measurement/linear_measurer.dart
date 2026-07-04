import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/body_landmarks.dart';
import '../../models/body_outline.dart';
import '../../models/measurement_confidence.dart';
import '../../models/processed_landmarks.dart';

/// Computes linear (straight-line) body measurements.
///
/// Uses segmentation-derived widths where available (more accurate for surface
/// measurements like shoulder width), and landmark Euclidean distances for
/// length measurements (arm, leg, torso).
class LinearMeasurer {
  final double pixelToCm;

  const LinearMeasurer({required this.pixelToCm});

  /// Shoulder width.
  /// Prefers segmentation outline (actual body surface) over landmarks.
  ///
  /// ── Plausibility guard ───────────────────────────────────────────
  /// Segmentation quality at the exact shoulder-landmark Y-level can be
  /// poor (lighting, clothing edge, low-contrast deltoid against background).
  /// If the segmentation result is outside the physiological range [20, 60 cm],
  /// it is an artefact — we fall back to landmarks rather than propagating
  /// a bad value that will trigger a false range-validation rejection.
  MeasurementWithConfidence measureShoulderWidth({
    required ProcessedLandmarks landmarks,
    BodyOutline? outline,
  }) {
    // Landmark shoulders are GLENOHUMERAL joints (narrower than the biacromial
    // clothing shoulder). Add ~4 cm for the acromion + deltoid soft tissue.
    // This is the anatomical FLOOR: real shoulder width can never be less.
    final landmarkCm = landmarks.shoulderWidth * pixelToCm + 4.0;

    double widthCm = landmarkCm;
    double confidence = 0.70;
    MeasurementSource source = MeasurementSource.landmarkLinear;

    // Segmentation captures the true deltoid surface — prefer it ONLY when it
    // is wider than the landmark floor. A segmentation value below the floor
    // means the mask clipped the shoulder edge, so we keep the floor instead.
    if (outline != null && outline.shoulderWidth.isValid) {
      final seg = outline.shoulderWidth.widthPx * pixelToCm;
      if (seg >= 20.0 && seg <= 60.0 && seg >= landmarkCm) {
        widthCm = seg;
        confidence = 0.90;
        source = MeasurementSource.segmentation;
      }

      if (kDebugMode) {
        debugPrint(
          '[shoulder] seg=${seg.toStringAsFixed(1)}cm '
          'landmarkFloor=${landmarkCm.toStringAsFixed(1)}cm '
          'chosen=${widthCm.toStringAsFixed(1)}cm '
          '(landmarkPx=${landmarks.shoulderWidth.toStringAsFixed(1)}, '
          'segPx=${outline.shoulderWidth.widthPx.toStringAsFixed(1)})',
        );
      }
    } else if (kDebugMode) {
      debugPrint(
        '[shoulder] no segmentation → landmarkFloor='
        '${landmarkCm.toStringAsFixed(1)}cm '
        '(landmarkPx=${landmarks.shoulderWidth.toStringAsFixed(1)})',
      );
    }

    return MeasurementWithConfidence(
      key: 'bahu',
      label: 'Shoulder Width',
      valueCm: _round(widthCm),
      valueInch: _round(widthCm / 2.54),
      confidence: confidence,
      source: source,
      region: 'atas',
    );
  }

  /// Sleeve length: shoulder point → elbow → wrist.
  ///
  /// [userHeightCm], when provided, enables an anthropometric guard: a 2D front
  /// A-pose can foreshorten the arm (arm angled toward the camera, slightly bent
  /// elbow, or a mis-placed wrist landmark), yielding an impossibly short value.
  /// Shoulder-to-wrist length is ~0.32 × stature; if the landmark estimate falls
  /// below 0.28 × height it is replaced by the 0.32 × height estimate and marked
  /// LOW confidence rather than reporting a wrong short value.
  MeasurementWithConfidence measureSleeveLength({
    required ProcessedLandmarks landmarks,
    double? userHeightCm,
  }) {
    final leftLength = landmarks.leftArmLength * pixelToCm;
    final rightLength = landmarks.rightArmLength * pixelToCm;

    final leftConf = min(
      landmarks.leftShoulder.confidence,
      min(landmarks.leftElbow.confidence, landmarks.leftWrist.confidence),
    );
    final rightConf = min(
      landmarks.rightShoulder.confidence,
      min(landmarks.rightElbow.confidence, landmarks.rightWrist.confidence),
    );

    double valueCm;
    double confidence;

    if (leftConf >= 0.5 && rightConf >= 0.5) {
      valueCm = (leftLength + rightLength) / 2;
      confidence = (leftConf + rightConf) / 2;
    } else if (leftConf >= 0.5) {
      valueCm = leftLength;
      confidence = leftConf;
    } else {
      valueCm = rightLength;
      confidence = rightConf;
    }

    var source = MeasurementSource.landmarkLinear;

    if (kDebugMode) {
      debugPrint(
        '[arm] leftPx=${landmarks.leftArmLength.toStringAsFixed(1)} '
        'rightPx=${landmarks.rightArmLength.toStringAsFixed(1)} '
        'pixelToCm=${pixelToCm.toStringAsFixed(5)} '
        '→ ${valueCm.toStringAsFixed(1)}cm '
        '| shoulder(${landmarks.leftShoulder.x.toStringAsFixed(0)},'
        '${landmarks.leftShoulder.y.toStringAsFixed(0)}) '
        'elbow(${landmarks.leftElbow.x.toStringAsFixed(0)},'
        '${landmarks.leftElbow.y.toStringAsFixed(0)}) '
        'wrist(${landmarks.leftWrist.x.toStringAsFixed(0)},'
        '${landmarks.leftWrist.y.toStringAsFixed(0)}) '
        'img=${landmarks.imageWidth}x${landmarks.imageHeight}',
      );
    }

    // Anthropometric guard against foreshortened / mis-detected arms.
    if (userHeightCm != null && userHeightCm >= 80 && userHeightCm <= 230) {
      final ratio = valueCm / userHeightCm;
      if (ratio < 0.28) {
        final estimate = userHeightCm * 0.32;
        if (kDebugMode) {
          debugPrint(
            '[arm] implausibly short (ratio=${ratio.toStringAsFixed(2)}) → '
            'anthropometric estimate ${estimate.toStringAsFixed(1)}cm',
          );
        }
        valueCm = estimate;
        confidence = 0.40;
        source = MeasurementSource.estimation;
      }
    }

    return MeasurementWithConfidence(
      key: 'panjang_lengan',
      label: 'Arm Length',
      valueCm: _round(valueCm),
      valueInch: _round(valueCm / 2.54),
      confidence: confidence,
      source: source,
      region: 'tengah',
    );
  }

  /// Torso height: shoulder midpoint to hip midpoint.
  MeasurementWithConfidence measureTorsoHeight({
    required ProcessedLandmarks landmarks,
  }) {
    final shoulderMid = landmarks.shoulderMidpoint;
    final hipMid = landmarks.hipMidpoint;
    final distPx = _distance(shoulderMid, hipMid);
    final valueCm = distPx * pixelToCm;

    return MeasurementWithConfidence(
      key: 'tinggi_torso',
      label: 'Torso Height',
      valueCm: _round(valueCm),
      valueInch: _round(valueCm / 2.54),
      confidence: min(shoulderMid.confidence, hipMid.confidence),
      source: MeasurementSource.landmarkLinear,
      region: 'tengah',
    );
  }

  /// Back length: neck base (C7 approximation) to waist level.
  MeasurementWithConfidence measureBackLength({
    required ProcessedLandmarks landmarks,
  }) {
    // C7 vertebra approximation: midpoint of shoulders, slightly above
    final neckBase = landmarks.neckPoint;

    // Waist: 60% between shoulder and hip
    final waistY =
        landmarks.shoulderMidY +
        (landmarks.hipMidY - landmarks.shoulderMidY) * 0.60;
    final waistPoint = LandmarkPoint2D(
      x: (landmarks.leftHip.x + landmarks.rightHip.x) / 2,
      y: waistY,
      confidence: landmarks.hipMidpoint.confidence,
    );

    final distPx = _distance(neckBase, waistPoint);
    final valueCm = distPx * pixelToCm;

    return MeasurementWithConfidence(
      key: 'panjang_punggung',
      label: 'Back Length',
      valueCm: _round(valueCm),
      valueInch: _round(valueCm / 2.54),
      confidence: min(neckBase.confidence, waistPoint.confidence) * 0.9,
      source: MeasurementSource.landmarkLinear,
      region: 'tengah',
    );
  }

  /// Leg length (inseam): hip → knee → ankle.
  MeasurementWithConfidence measureLegLength({
    required ProcessedLandmarks landmarks,
  }) {
    final leftLength = landmarks.leftLegLength * pixelToCm;
    final rightLength = landmarks.rightLegLength * pixelToCm;

    final leftConf = min(
      landmarks.leftHip.confidence,
      min(landmarks.leftKnee.confidence, landmarks.leftAnkle.confidence),
    );
    final rightConf = min(
      landmarks.rightHip.confidence,
      min(landmarks.rightKnee.confidence, landmarks.rightAnkle.confidence),
    );

    double valueCm;
    double confidence;

    if (leftConf >= 0.5 && rightConf >= 0.5) {
      valueCm = (leftLength + rightLength) / 2;
      confidence = (leftConf + rightConf) / 2;
    } else if (leftConf >= 0.5) {
      valueCm = leftLength;
      confidence = leftConf;
    } else {
      valueCm = rightLength;
      confidence = rightConf;
    }

    return MeasurementWithConfidence(
      key: 'panjang_kaki',
      label: 'Leg Length',
      valueCm: _round(valueCm),
      valueInch: _round(valueCm / 2.54),
      confidence: confidence,
      source: MeasurementSource.landmarkLinear,
      region: 'bawah',
    );
  }

  /// Chest width (linear, not circumference).
  ///
  /// Torso chest width must be ≤ shoulder width (arms excluded).
  MeasurementWithConfidence measureChestWidth({
    required ProcessedLandmarks landmarks,
    BodyOutline? outline,
    required double shoulderWidthCm,
  }) {
    if (outline != null && outline.chestWidth.isValid) {
      final candidate = outline.chestWidth.widthPx * pixelToCm;
      if (_isPlausibleChestWidth(candidate, shoulderWidthCm)) {
        return _widthResult(
          key: 'lebar_dada',
          label: 'Chest Width',
          widthCm: candidate,
          confidence: 0.88,
          source: MeasurementSource.segmentation,
        );
      }
    }

    final approx =
        landmarks.shoulderWidth * 0.85 + landmarks.hipWidth * 0.15;
    return _widthResult(
      key: 'lebar_dada',
      label: 'Chest Width',
      widthCm: approx * pixelToCm,
      confidence: 0.60,
      source: MeasurementSource.estimation,
    );
  }

  /// Waist width (linear). Must be ≤ chest/shoulder envelope.
  MeasurementWithConfidence measureWaistWidth({
    required ProcessedLandmarks landmarks,
    BodyOutline? outline,
    required double shoulderWidthCm,
  }) {
    if (outline != null && outline.waistWidth.isValid) {
      final candidate = outline.waistWidth.widthPx * pixelToCm;
      if (_isPlausibleWaistWidth(candidate, shoulderWidthCm)) {
        return _widthResult(
          key: 'lebar_pinggang',
          label: 'Waist Width',
          widthCm: candidate,
          confidence: 0.88,
          source: MeasurementSource.segmentation,
        );
      }
    }

    return _widthResult(
      key: 'lebar_pinggang',
      label: 'Waist Width',
      widthCm: landmarks.hipWidth * pixelToCm * 0.82,
      confidence: 0.55,
      source: MeasurementSource.estimation,
    );
  }

  /// Hip width (linear). Capped at 1.30× shoulder to reject arm blobs.
  MeasurementWithConfidence measureHipWidth({
    required ProcessedLandmarks landmarks,
    BodyOutline? outline,
    required double shoulderWidthCm,
  }) {
    if (outline != null && outline.hipWidth.isValid) {
      final candidate = outline.hipWidth.widthPx * pixelToCm;
      if (_isPlausibleHipWidth(candidate, shoulderWidthCm)) {
        return _widthResult(
          key: 'lebar_pinggul',
          label: 'Hip Width',
          widthCm: candidate,
          confidence: 0.88,
          source: MeasurementSource.segmentation,
        );
      }
    }

    return _widthResult(
      key: 'lebar_pinggul',
      label: 'Hip Width',
      widthCm: landmarks.hipWidth * pixelToCm + 3.0,
      confidence: 0.60,
      source: MeasurementSource.landmarkLinear,
    );
  }

  bool _isPlausibleChestWidth(double cm, double shoulderCm) =>
      cm >= shoulderCm * 0.55 && cm <= shoulderCm * 1.05;

  bool _isPlausibleWaistWidth(double cm, double shoulderCm) =>
      cm >= shoulderCm * 0.50 && cm <= shoulderCm * 1.02;

  bool _isPlausibleHipWidth(double cm, double shoulderCm) =>
      cm >= shoulderCm * 0.70 && cm <= shoulderCm * 1.30;

  MeasurementWithConfidence _widthResult({
    required String key,
    required String label,
    required double widthCm,
    required double confidence,
    required MeasurementSource source,
  }) {
    return MeasurementWithConfidence(
      key: key,
      label: label,
      valueCm: _round(widthCm),
      valueInch: _round(widthCm / 2.54),
      confidence: confidence,
      source: source,
      region: 'tengah',
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  double _distance(LandmarkPoint2D a, LandmarkPoint2D b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  double _round(double value) => (value * 10).roundToDouble() / 10;
}
