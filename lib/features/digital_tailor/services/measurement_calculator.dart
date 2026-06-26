import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/measurement.dart';
import '../models/scan_result.dart';

/// Calculates anthropometric measurements from pose landmarks.
///
/// Uses the Ramanujan ellipse circumference approximation for circumferences
/// and Euclidean distance for linear measurements.
class MeasurementCalculator {
  /// Pixel-to-cm conversion factor
  double _pixelToCm = 1.0;

  /// Calculate all measurements from front and side pose landmarks.
  ///
  /// [frontPose] - Pose detected from the front photo
  /// [sidePose] - Pose detected from the side photo
  /// [userHeightCm] - User's actual height for calibration
  /// [frontImageHeight] - Height of the front image in pixels
  ScanResult calculate({
    required Pose frontPose,
    required Pose sidePose,
    required double userHeightCm,
    required int frontImageHeight,
  }) {
    // Calibrate pixel-to-cm ratio using user height
    _calibrateWithHeight(frontPose, userHeightCm);

    final measurements = <Measurement>[];
    final confidences = <double>[];

    // Collect confidence scores
    for (final landmark in frontPose.landmarks.values) {
      confidences.add(landmark.likelihood);
    }
    for (final landmark in sidePose.landmarks.values) {
      confidences.add(landmark.likelihood);
    }

    final avgConfidence = confidences.isNotEmpty
        ? confidences.reduce((a, b) => a + b) / confidences.length
        : 0.0;

    // Calculate each measurement
    final bahu = _calculateBahu(frontPose);
    if (bahu != null) measurements.add(bahu);

    final lingkarLeher = _calculateLingkarLeher(frontPose, sidePose);
    if (lingkarLeher != null) measurements.add(lingkarLeher);

    final dada = _calculateDada(frontPose, sidePose);
    if (dada != null) measurements.add(dada);

    final pinggang = _calculatePinggang(frontPose, sidePose);
    if (pinggang != null) measurements.add(pinggang);

    final pinggul = _calculatePinggul(frontPose, sidePose);
    if (pinggul != null) measurements.add(pinggul);

    final panjangLengan = _calculatePanjangLengan(frontPose);
    if (panjangLengan != null) measurements.add(panjangLengan);

    final panjangKaki = _calculatePanjangKaki(frontPose);
    if (panjangKaki != null) measurements.add(panjangKaki);

    return ScanResult(
      measurements: measurements,
      confidenceScore: avgConfidence,
      scannedAt: DateTime.now(),
    );
  }

  /// Calibrate using user-provided height
  void _calibrateWithHeight(Pose frontPose, double userHeightCm) {
    final nose = frontPose.landmarks[PoseLandmarkType.nose];
    final leftAnkle = frontPose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = frontPose.landmarks[PoseLandmarkType.rightAnkle];
    final leftHip = frontPose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = frontPose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = frontPose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = frontPose.landmarks[PoseLandmarkType.rightShoulder];

    // Primary method: nose to ankle midpoint
    if (nose != null && (leftAnkle != null || rightAnkle != null)) {
      final ankleY = leftAnkle != null && rightAnkle != null
          ? (leftAnkle.y + rightAnkle.y) / 2
          : (leftAnkle?.y ?? rightAnkle!.y);

      // Add ~10% above nose for top of head
      final headTopY = nose.y - (ankleY - nose.y) * 0.1;
      final bodyHeightPixels = ankleY - headTopY;

      if (bodyHeightPixels > 50) {
        _pixelToCm = userHeightCm / bodyHeightPixels;
        return;
      }
    }

    // Fallback method: use shoulder-to-hip distance (approx 35% of height)
    if ((leftShoulder != null || rightShoulder != null) &&
        (leftHip != null || rightHip != null)) {
      final shoulderY = leftShoulder != null && rightShoulder != null
          ? (leftShoulder.y + rightShoulder.y) / 2
          : (leftShoulder?.y ?? rightShoulder!.y);
      final hipY = leftHip != null && rightHip != null
          ? (leftHip.y + rightHip.y) / 2
          : (leftHip?.y ?? rightHip!.y);

      final torsoPixels = (hipY - shoulderY).abs();
      if (torsoPixels > 20) {
        // Torso is approximately 35% of total height
        final estimatedFullHeight = torsoPixels / 0.35;
        _pixelToCm = userHeightCm / estimatedFullHeight;
        return;
      }
    }

    // Last resort: use a reasonable default based on image height
    // Assume person occupies ~80% of image height
    _pixelToCm =
        userHeightCm / (frontPose.landmarks.values.isNotEmpty ? 1200 : 1.0);
  }

  /// Bahu (Shoulder Width) - Linear distance between shoulders
  Measurement? _calculateBahu(Pose frontPose) {
    final left = frontPose.landmarks[PoseLandmarkType.leftShoulder];
    final right = frontPose.landmarks[PoseLandmarkType.rightShoulder];

    if (left == null || right == null) return null;
    if (left.likelihood < 0.2 || right.likelihood < 0.2) return null;

    final distPx = _euclideanDistance(left, right);
    final cm = _roundTo1((distPx * _pixelToCm));
    final inch = _roundTo1(cm / 2.54);

    return Measurement(
      key: 'bahu',
      label: 'Bahu (Shoulder Width)',
      valueCm: cm,
      valueInch: inch,
      region: MeasurementRegion.atas,
    );
  }

  /// Lingkar Leher (Neck Circumference) - Ellipse approximation
  Measurement? _calculateLingkarLeher(Pose frontPose, Pose sidePose) {
    final leftShoulder = frontPose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = frontPose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) return null;

    // Approximate neck width as ~35% of shoulder width from front
    final shoulderWidthPx = _euclideanDistance(leftShoulder, rightShoulder);
    final neckFrontHalfWidth = shoulderWidthPx * 0.35 / 2;

    // Approximate neck depth as ~80% of neck width from side
    final neckSideHalfDepth = neckFrontHalfWidth * 0.8;

    final circumferencePx = _ellipseCircumference(
      neckFrontHalfWidth,
      neckSideHalfDepth,
    );
    final cm = _roundTo1(circumferencePx * _pixelToCm);
    final inch = _roundTo1(cm / 2.54);

    return Measurement(
      key: 'lingkar_leher',
      label: 'Lingkar Leher (Neck Circumference)',
      valueCm: cm,
      valueInch: inch,
      region: MeasurementRegion.atas,
    );
  }

  /// Dada (Chest Circumference) - Ellipse approximation
  /// Uses shoulder width from front as the primary measurement,
  /// with anthropometric ratios for depth estimation.
  Measurement? _calculateDada(Pose frontPose, Pose sidePose) {
    final frontLeft = frontPose.landmarks[PoseLandmarkType.leftShoulder];
    final frontRight = frontPose.landmarks[PoseLandmarkType.rightShoulder];
    final frontLeftHip = frontPose.landmarks[PoseLandmarkType.leftHip];
    final frontRightHip = frontPose.landmarks[PoseLandmarkType.rightHip];

    if (frontLeft == null ||
        frontRight == null ||
        frontLeftHip == null ||
        frontRightHip == null) {
      return null;
    }

    // Chest width from front view (full width, not half)
    final shoulderWidth = (frontLeft.x - frontRight.x).abs();
    final hipWidth = (frontLeftHip.x - frontRightHip.x).abs();
    // Chest is typically between shoulder and hip width
    final chestFullWidth = shoulderWidth * 0.85 + hipWidth * 0.15;
    final chestHalfWidth = chestFullWidth / 2;

    // Chest depth: use side pose if available, otherwise use ratio
    // Average chest depth-to-width ratio is approximately 0.65-0.75
    final sideLeftShoulder = sidePose.landmarks[PoseLandmarkType.leftShoulder];
    final sideLeftHip = sidePose.landmarks[PoseLandmarkType.leftHip];

    double chestHalfDepth;
    if (sideLeftShoulder != null && sideLeftHip != null) {
      // Side view: distance between front and back of torso
      final sideBodyDepth = (sideLeftShoulder.x - sideLeftHip.x).abs();
      chestHalfDepth = sideBodyDepth * _pixelToCm / 2;
    } else {
      // Fallback: use anthropometric ratio (depth ≈ 70% of width)
      chestHalfDepth = (chestHalfWidth * _pixelToCm) * 0.70;
    }

    // Convert front width to cm
    final chestHalfWidthCm = chestHalfWidth * _pixelToCm;

    // If side depth was calculated from pixels, it's already in cm above
    // If from ratio, it's already in cm
    final halfDepthCm = sideLeftShoulder != null && sideLeftHip != null
        ? chestHalfDepth
        : chestHalfDepth; // Already in cm from ratio calculation

    // Ramanujan ellipse circumference with semi-axes in cm
    final cm = _roundTo1(
      _ellipseCircumferenceCm(chestHalfWidthCm, halfDepthCm),
    );
    final inch = _roundTo1(cm / 2.54);

    // Sanity check: chest circumference typically 60-150 cm
    if (cm < 50 || cm > 180) {
      // Use anthropometric estimation: chest ≈ shoulder width × 2.5
      final estimatedCm = _roundTo1(shoulderWidth * _pixelToCm * 2.5);
      final estimatedInch = _roundTo1(estimatedCm / 2.54);
      return Measurement(
        key: 'dada',
        label: 'Dada (Chest Circumference)',
        valueCm: estimatedCm,
        valueInch: estimatedInch,
        region: MeasurementRegion.tengah,
      );
    }

    return Measurement(
      key: 'dada',
      label: 'Dada (Chest Circumference)',
      valueCm: cm,
      valueInch: inch,
      region: MeasurementRegion.tengah,
    );
  }

  /// Pinggang (Waist Circumference) - Ellipse approximation
  Measurement? _calculatePinggang(Pose frontPose, Pose sidePose) {
    final leftHip = frontPose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = frontPose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = frontPose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = frontPose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftHip == null ||
        rightHip == null ||
        leftShoulder == null ||
        rightShoulder == null) {
      return null;
    }

    // Waist width from front: between hip and shoulder, narrower
    final hipWidth = (leftHip.x - rightHip.x).abs();
    // Waist is typically narrower than hips (about 80-90% of hip width)
    final waistFullWidth = hipWidth * 0.85;
    final waistHalfWidthCm = (waistFullWidth / 2) * _pixelToCm;

    // Waist depth from side pose or ratio
    final sideLeftHip = sidePose.landmarks[PoseLandmarkType.leftHip];
    final sideRightHip = sidePose.landmarks[PoseLandmarkType.rightHip];

    double waistHalfDepthCm;
    if (sideLeftHip != null && sideRightHip != null) {
      final sideWidth = (sideLeftHip.x - sideRightHip.x).abs();
      waistHalfDepthCm = (sideWidth / 2) * _pixelToCm * 0.80;
    } else {
      // Anthropometric ratio: waist depth ≈ 65% of waist width
      waistHalfDepthCm = waistHalfWidthCm * 0.65;
    }

    final cm = _roundTo1(
      _ellipseCircumferenceCm(waistHalfWidthCm, waistHalfDepthCm),
    );
    final inch = _roundTo1(cm / 2.54);

    // Sanity check: waist typically 55-130 cm
    if (cm < 40 || cm > 200) {
      // Fallback: waist ≈ hip width × 2.2
      final estimatedCm = _roundTo1(hipWidth * _pixelToCm * 2.2);
      final estimatedInch = _roundTo1(estimatedCm / 2.54);
      return Measurement(
        key: 'pinggang',
        label: 'Pinggang (Waist Circumference)',
        valueCm: estimatedCm,
        valueInch: estimatedInch,
        region: MeasurementRegion.tengah,
      );
    }

    return Measurement(
      key: 'pinggang',
      label: 'Pinggang (Waist Circumference)',
      valueCm: cm,
      valueInch: inch,
      region: MeasurementRegion.tengah,
    );
  }

  /// Pinggul (Hip Circumference) - Ellipse approximation
  Measurement? _calculatePinggul(Pose frontPose, Pose sidePose) {
    final leftHip = frontPose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = frontPose.landmarks[PoseLandmarkType.rightHip];

    if (leftHip == null || rightHip == null) return null;
    if (leftHip.likelihood < 0.2 || rightHip.likelihood < 0.2) return null;

    final hipFullWidth = (leftHip.x - rightHip.x).abs();
    final hipHalfWidthCm = (hipFullWidth / 2) * _pixelToCm;

    // Hip depth from side
    final sideLeftHip = sidePose.landmarks[PoseLandmarkType.leftHip];
    final sideRightHip = sidePose.landmarks[PoseLandmarkType.rightHip];

    double hipHalfDepthCm;
    if (sideLeftHip != null && sideRightHip != null) {
      final sideDepth = (sideLeftHip.x - sideRightHip.x).abs();
      hipHalfDepthCm = (sideDepth / 2) * _pixelToCm;
    } else {
      // Anthropometric ratio: hip depth ≈ 75% of hip width
      hipHalfDepthCm = hipHalfWidthCm * 0.75;
    }

    final cm = _roundTo1(
      _ellipseCircumferenceCm(hipHalfWidthCm, hipHalfDepthCm),
    );
    final inch = _roundTo1(cm / 2.54);

    // Sanity check: hip circumference typically 70-150 cm
    if (cm < 50 || cm > 180) {
      final estimatedCm = _roundTo1(hipFullWidth * _pixelToCm * 2.4);
      final estimatedInch = _roundTo1(estimatedCm / 2.54);
      return Measurement(
        key: 'pinggul',
        label: 'Pinggul (Hip Circumference)',
        valueCm: estimatedCm,
        valueInch: estimatedInch,
        region: MeasurementRegion.tengah,
      );
    }

    return Measurement(
      key: 'pinggul',
      label: 'Pinggul (Hip Circumference)',
      valueCm: cm,
      valueInch: inch,
      region: MeasurementRegion.tengah,
    );
  }

  /// Panjang Lengan (Arm Length) - Linear distance
  Measurement? _calculatePanjangLengan(Pose frontPose) {
    final shoulder = frontPose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = frontPose.landmarks[PoseLandmarkType.leftElbow];
    final wrist = frontPose.landmarks[PoseLandmarkType.leftWrist];

    if (shoulder == null || elbow == null || wrist == null) return null;
    if (shoulder.likelihood < 0.2 ||
        elbow.likelihood < 0.2 ||
        wrist.likelihood < 0.2) {
      return null;
    }

    final upperArm = _euclideanDistance(shoulder, elbow);
    final forearm = _euclideanDistance(elbow, wrist);
    final totalPx = upperArm + forearm;

    final cm = _roundTo1(totalPx * _pixelToCm);
    final inch = _roundTo1(cm / 2.54);

    return Measurement(
      key: 'panjang_lengan',
      label: 'Panjang Lengan (Arm Length)',
      valueCm: cm,
      valueInch: inch,
      region: MeasurementRegion.tengah,
    );
  }

  /// Panjang Kaki (Leg Length) - Linear distance
  Measurement? _calculatePanjangKaki(Pose frontPose) {
    final hip = frontPose.landmarks[PoseLandmarkType.leftHip];
    final knee = frontPose.landmarks[PoseLandmarkType.leftKnee];
    final ankle = frontPose.landmarks[PoseLandmarkType.leftAnkle];

    if (hip == null || knee == null || ankle == null) return null;
    if (hip.likelihood < 0.2 ||
        knee.likelihood < 0.2 ||
        ankle.likelihood < 0.2) {
      return null;
    }

    final upperLeg = _euclideanDistance(hip, knee);
    final lowerLeg = _euclideanDistance(knee, ankle);
    final totalPx = upperLeg + lowerLeg;

    final cm = _roundTo1(totalPx * _pixelToCm);
    final inch = _roundTo1(cm / 2.54);

    return Measurement(
      key: 'panjang_kaki',
      label: 'Panjang Kaki (Leg Length)',
      valueCm: cm,
      valueInch: inch,
      region: MeasurementRegion.bawah,
    );
  }

  // ─── Helper Methods ──────────────────────────────────────────────────

  /// Euclidean distance between two pose landmarks
  double _euclideanDistance(PoseLandmark a, PoseLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Ramanujan's ellipse circumference approximation
  /// C ≈ π × (3(a+b) - √((3a+b)(a+3b)))
  double _ellipseCircumference(double a, double b) {
    final sum = 3 * (a + b);
    final product = (3 * a + b) * (a + 3 * b);
    return pi * (sum - sqrt(product));
  }

  /// Ramanujan's ellipse circumference with semi-axes already in cm
  /// Same formula but named clearly for when inputs are in real units
  double _ellipseCircumferenceCm(double halfWidthCm, double halfDepthCm) {
    if (halfWidthCm <= 0 || halfDepthCm <= 0) return 0;
    final a = halfWidthCm;
    final b = halfDepthCm;
    final sum = 3 * (a + b);
    final product = (3 * a + b) * (a + 3 * b);
    return pi * (sum - sqrt(product));
  }

  /// Round to 1 decimal place
  double _roundTo1(double value) {
    return (value * 10).roundToDouble() / 10;
  }
}
