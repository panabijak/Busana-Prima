import 'dart:math';

import 'body_landmarks.dart';

/// Processed and validated set of body landmarks ready for measurement.
///
/// This class normalizes the raw ML Kit output into a structured format
/// with computed helper properties (midpoints, distances, etc.)
class ProcessedLandmarks {
  // Head & Neck
  final LandmarkPoint2D nose;
  final LandmarkPoint2D leftEar;
  final LandmarkPoint2D rightEar;

  // Optional: eye landmarks improve head-crown estimation accuracy
  final LandmarkPoint2D? leftEye;
  final LandmarkPoint2D? rightEye;

  // Shoulders
  final LandmarkPoint2D leftShoulder;
  final LandmarkPoint2D rightShoulder;

  // Arms
  final LandmarkPoint2D leftElbow;
  final LandmarkPoint2D rightElbow;
  final LandmarkPoint2D leftWrist;
  final LandmarkPoint2D rightWrist;

  // Torso
  final LandmarkPoint2D leftHip;
  final LandmarkPoint2D rightHip;

  // Legs
  final LandmarkPoint2D leftKnee;
  final LandmarkPoint2D rightKnee;
  final LandmarkPoint2D leftAnkle;
  final LandmarkPoint2D rightAnkle;

  // Optional: foot landmarks improve foot-bottom estimation (~4-5% calibration gain)
  // Heel landmark is at posterior calcaneus — much closer to the floor than ankle joint.
  final LandmarkPoint2D? leftHeel;
  final LandmarkPoint2D? rightHeel;
  // Foot index is at the metatarsal-phalangeal joint (ball of foot).
  final LandmarkPoint2D? leftFootIndex;
  final LandmarkPoint2D? rightFootIndex;

  // Image dimensions for context
  final int imageWidth;
  final int imageHeight;

  const ProcessedLandmarks({
    required this.nose,
    required this.leftEar,
    required this.rightEar,
    this.leftEye,
    this.rightEye,
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftElbow,
    required this.rightElbow,
    required this.leftWrist,
    required this.rightWrist,
    required this.leftHip,
    required this.rightHip,
    required this.leftKnee,
    required this.rightKnee,
    required this.leftAnkle,
    required this.rightAnkle,
    this.leftHeel,
    this.rightHeel,
    this.leftFootIndex,
    this.rightFootIndex,
    required this.imageWidth,
    required this.imageHeight,
  });

  // ─── Computed Properties ──────────────────────────────────────────

  /// Midpoint between left and right shoulders (pixel coordinates)
  LandmarkPoint2D get shoulderMidpoint => LandmarkPoint2D(
    x: (leftShoulder.x + rightShoulder.x) / 2,
    y: (leftShoulder.y + rightShoulder.y) / 2,
    confidence: min(leftShoulder.confidence, rightShoulder.confidence),
  );

  /// Midpoint between left and right hips (pixel coordinates)
  LandmarkPoint2D get hipMidpoint => LandmarkPoint2D(
    x: (leftHip.x + rightHip.x) / 2,
    y: (leftHip.y + rightHip.y) / 2,
    confidence: min(leftHip.confidence, rightHip.confidence),
  );

  /// Midpoint between left and right knees
  LandmarkPoint2D get kneeMidpoint => LandmarkPoint2D(
    x: (leftKnee.x + rightKnee.x) / 2,
    y: (leftKnee.y + rightKnee.y) / 2,
    confidence: min(leftKnee.confidence, rightKnee.confidence),
  );

  /// Y-coordinate of the shoulder midpoint
  double get shoulderMidY => shoulderMidpoint.y;

  /// Y-coordinate of the hip midpoint
  double get hipMidY => hipMidpoint.y;

  /// Y-coordinate of the knee midpoint
  double get kneeMidY => kneeMidpoint.y;

  /// Shoulder width in pixels (left-to-right distance)
  double get shoulderWidth => _distance(leftShoulder, rightShoulder);

  /// Hip width in pixels
  double get hipWidth => _distance(leftHip, rightHip);

  /// Left arm length in pixels (shoulder → elbow → wrist)
  double get leftArmLength =>
      _distance(leftShoulder, leftElbow) + _distance(leftElbow, leftWrist);

  /// Right arm length in pixels
  double get rightArmLength =>
      _distance(rightShoulder, rightElbow) + _distance(rightElbow, rightWrist);

  /// Left leg length in pixels (hip → knee → ankle)
  double get leftLegLength =>
      _distance(leftHip, leftKnee) + _distance(leftKnee, leftAnkle);

  /// Right leg length in pixels
  double get rightLegLength =>
      _distance(rightHip, rightKnee) + _distance(rightKnee, rightAnkle);

  /// Approximate neck point (midpoint between shoulders, shifted up slightly)
  LandmarkPoint2D get neckPoint {
    final mid = shoulderMidpoint;
    // Neck base is approximately 10% of shoulder width above shoulder midpoint
    final offset = shoulderWidth * 0.10;
    return LandmarkPoint2D(
      x: mid.x,
      y: mid.y - offset,
      confidence: mid.confidence,
    );
  }

  // ─── Calibration-Critical Properties ─────────────────────────────

  /// Estimated head-top Y in image pixels (y-axis: 0 = top of image).
  ///
  /// Strategy (in priority order):
  /// 1. Eye landmarks: crown ≈ eyeMidY − (noseY − eyeMidY) × 0.85
  ///    Based on standard face proportions (crown-to-brow ≈ 85% of brow-to-nose).
  /// 2. Ear landmarks: crown ≈ earMidY − (noseY − earMidY) × 0.50
  ///    Ears sit roughly at nose level; crown is ~50% of that distance above ears.
  /// 3. Fallback: noseY − roughBodyHeight × 0.10
  ///    10% is more accurate than the old 12% for adults (nose is ~9% from crown).
  double get estimatedHeadTopY {
    // Preferred: use eye landmarks for a geometry-grounded estimate.
    if (_hasValidEyes) {
      final eyeMidY = (_validEye(leftEye)! + _validEye(rightEye)!) / 2;
      // Face proportion: eye center is at ~35% from crown; nose tip at ~65%.
      // Crown-to-eye ≈ 0.85 × eye-to-nose, so:
      // headTop ≈ eyeMidY − (noseY − eyeMidY) × 0.85
      final eyeToNose = (nose.y - eyeMidY).abs();
      return eyeMidY - eyeToNose * 0.85;
    }

    // Good fallback: use ear landmarks.
    if (leftEar.confidence > 0.4 && rightEar.confidence > 0.4) {
      final earMidY = (leftEar.y + rightEar.y) / 2;
      // Ear tragus is near nose level. Crown is ~50% of ear-nose distance above ear.
      final earToNose = (nose.y - earMidY).abs();
      return min(earMidY, nose.y) - earToNose * 0.50;
    }

    // Last resort: improved heuristic (10% vs old 12%).
    final ankleY = (leftAnkle.y + rightAnkle.y) / 2;
    final roughBodyHeight = (ankleY - nose.y).abs();
    return nose.y - roughBodyHeight * 0.10;
  }

  /// Estimated foot-bottom Y in image pixels.
  ///
  /// Strategy (in priority order):
  /// 1. Heel landmarks: posterior calcaneus is the actual floor contact point.
  /// 2. Foot-index landmarks: ball-of-foot, also very close to the floor.
  /// 3. Fallback: ankle midpoint (worst — ankle joint is 6–8 cm above floor).
  ///
  /// Using heels instead of ankles eliminates the ~4–5% systematic underestimation
  /// of body height that inflated every pixel-to-cm measurement.
  double get estimatedFootBottomY {
    // In image coordinates y increases downward, so a larger y value = lower in frame.
    double bottomY = (leftAnkle.y + rightAnkle.y) / 2;

    if (_hasValidHeel) {
      final heelY = _bestHeelY;
      if (heelY > bottomY) bottomY = heelY;
    }

    if (_hasValidFootIndex) {
      final footY = _bestFootIndexY;
      if (footY > bottomY) bottomY = footY;
    }

    return bottomY;
  }

  /// Estimated body height in pixels (head top → foot bottom).
  double get estimatedBodyHeightPx {
    return (estimatedFootBottomY - estimatedHeadTopY).abs();
  }

  /// Calibration-landmark quality score (0.0 – 1.0).
  ///
  /// Reflects how accurately we can estimate the two calibration anchors:
  /// - 0.50: only ankle + nose (worst — both are approximate)
  /// - 0.65: ankle + nose + heels (heel gives better foot-bottom)
  /// - 0.75: heels + foot-index + nose (best landmark-only case)
  /// - 0.90: heels + eyes (eyes enable accurate crown estimation)
  double get calibrationLandmarkQuality {
    double q = 0.50; // baseline: ankle + nose heuristic
    if (_hasValidHeel) q += 0.15; // heel gives better foot anchor
    if (_hasValidFootIndex) q += 0.05; // foot-index adds minor improvement
    if (_hasValidEyes) q += 0.20; // eyes dramatically improve head-top
    return q.clamp(0.0, 1.0);
  }

  // ─── Standard Properties ──────────────────────────────────────────

  /// Minimum confidence across all landmarks
  double get minConfidence =>
      allLandmarks.map((lm) => lm.confidence).reduce(min);

  /// Average confidence across all landmarks
  double get averageConfidence {
    final all = allLandmarks;
    return all.map((lm) => lm.confidence).reduce((a, b) => a + b) / all.length;
  }

  /// All required landmark points as a list
  List<LandmarkPoint2D> get allLandmarks => [
    nose,
    leftEar,
    rightEar,
    leftShoulder,
    rightShoulder,
    leftElbow,
    rightElbow,
    leftWrist,
    rightWrist,
    leftHip,
    rightHip,
    leftKnee,
    rightKnee,
    leftAnkle,
    rightAnkle,
  ];

  // ─── Private Helpers ──────────────────────────────────────────────

  bool get _hasValidEyes =>
      _validEye(leftEye) != null && _validEye(rightEye) != null;

  double? _validEye(LandmarkPoint2D? eye) =>
      (eye != null && eye.confidence > 0.5) ? eye.y : null;

  bool get _hasValidHeel =>
      (leftHeel != null && leftHeel!.confidence > 0.3) ||
      (rightHeel != null && rightHeel!.confidence > 0.3);

  double get _bestHeelY {
    double y = 0;
    if (leftHeel != null && leftHeel!.confidence > 0.3) {
      y = max(y, leftHeel!.y);
    }
    if (rightHeel != null && rightHeel!.confidence > 0.3) {
      y = max(y, rightHeel!.y);
    }
    return y;
  }

  bool get _hasValidFootIndex =>
      (leftFootIndex != null && leftFootIndex!.confidence > 0.3) ||
      (rightFootIndex != null && rightFootIndex!.confidence > 0.3);

  double get _bestFootIndexY {
    double y = 0;
    if (leftFootIndex != null && leftFootIndex!.confidence > 0.3) {
      y = max(y, leftFootIndex!.y);
    }
    if (rightFootIndex != null && rightFootIndex!.confidence > 0.3) {
      y = max(y, rightFootIndex!.y);
    }
    return y;
  }

  double _distance(LandmarkPoint2D a, LandmarkPoint2D b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }
}
