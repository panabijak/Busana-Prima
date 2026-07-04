import 'dart:math';

import '../../models/body_outline.dart';
import '../../models/processed_landmarks.dart';
import '../detection/segmentation_service.dart';

/// Extracts torso-only body widths from segmentation masks.
///
/// ── FRONT VIEW ─────────────────────────────────────────────────────
/// Horizontal scans are clipped using shoulder landmarks + elbow exclusion.
/// Arms in A-pose extend beyond the shoulder joint; wide margins (e.g. ±45%)
/// re-include the arm blob and inflate hip width → inflated circumference.
///
/// ── SIDE VIEW ──────────────────────────────────────────────────────
/// Full-row scans measure [torso + hanging arm] as one silhouette.
/// Side depth must be torso thickness only. We scan a **central vertical strip**
/// (±12% of image width around torso midline) at each y-level — the arm hangs
/// outside this strip in a correct side profile.
class BodyOutlineAnalyzer {
  static const double bodyThreshold = 0.50;
  static const double minWidthFraction = 0.04;
  static const int _topK = 3;

  /// Central strip half-width as fraction of image width (side depth only).
  static const double _sideTorsoStripFraction = 0.12;

  BodyOutline analyzeFullOutline({
    required SegmentationResult mask,
    required ProcessedLandmarks landmarks,
    required int imageWidth,
    required int imageHeight,
    bool isSideView = false,
  }) {
    final torsoHeight = (landmarks.hipMidY - landmarks.shoulderMidY).abs();
    if (torsoHeight < 20) {
      return _emptyOutline();
    }

    final shoulderY = landmarks.shoulderMidY;
    final chestY = landmarks.shoulderMidY + torsoHeight * 0.35;
    // Natural waist (narrowest point) sits ABOVE the mid shoulder-hip span.
    // 0.60 landed too low (toward the rounder hip), inflating waist width and
    // depth. 0.55 targets the true narrowest level.
    final waistY = landmarks.shoulderMidY + torsoHeight * 0.55;
    final hipY =
        landmarks.hipMidY + (landmarks.kneeMidY - landmarks.hipMidY) * 0.06;

    if (isSideView) {
      final torsoCenterX = (landmarks.shoulderMidpoint.x + landmarks.hipMidpoint.x) / 2;
      return BodyOutline(
        shoulderWidth: _getSideTorsoDepth(
          mask: mask,
          yImage: shoulderY,
          torsoCenterX: torsoCenterX,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          scanRows: 5,
        ),
        chestWidth: _getSideTorsoDepth(
          mask: mask,
          yImage: chestY,
          torsoCenterX: torsoCenterX,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          scanRows: 10,
        ),
        waistWidth: _getSideTorsoDepth(
          mask: mask,
          yImage: waistY,
          torsoCenterX: torsoCenterX,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          scanRows: 12,
        ),
        hipWidth: _getSideTorsoDepth(
          mask: mask,
          yImage: hipY,
          torsoCenterX: torsoCenterX,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          scanRows: 8,
          // Median of a normal-width strip. `pickMinimum` under-measured the
          // buttock AP depth (it picked the thigh-gap row).
        ),
      );
    }

    final bounds = _frontTorsoBounds(landmarks);

    return BodyOutline(
      shoulderWidth: _getWidthAveraged(
        mask: mask,
        yImage: shoulderY,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        scanRows: 5,
        findWidest: true,
        leftBoundImage: bounds.shoulderLeft,
        rightBoundImage: bounds.shoulderRight,
      ),
      chestWidth: _getWidthAveraged(
        mask: mask,
        yImage: chestY,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        scanRows: 10,
        findWidest: true,
        leftBoundImage: bounds.chestLeft,
        rightBoundImage: bounds.chestRight,
      ),
      waistWidth: _getWidthAveraged(
        mask: mask,
        yImage: waistY,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        scanRows: 12,
        findWidest: false,
        leftBoundImage: bounds.waistLeft,
        rightBoundImage: bounds.waistRight,
      ),
      hipWidth: _getWidthAveraged(
        mask: mask,
        yImage: hipY,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        scanRows: 8,
        findWidest: true,
        leftBoundImage: bounds.hipLeft,
        rightBoundImage: bounds.hipRight,
      ),
    );
  }

  // ─── Front torso x-bounds ─────────────────────────────────────────

  _FrontBounds _frontTorsoBounds(ProcessedLandmarks lm) {
    final shoulderMinX = min(lm.leftShoulder.x, lm.rightShoulder.x);
    final shoulderMaxX = max(lm.leftShoulder.x, lm.rightShoulder.x);
    final shoulderSpan = (shoulderMaxX - shoulderMinX).abs().clamp(1.0, 9999.0);

    final hipMinX = min(lm.leftHip.x, lm.rightHip.x);
    final hipMaxX = max(lm.leftHip.x, lm.rightHip.x);

    // Elbow exclusion: in A-pose elbows sit outside the shoulder line.
    // Clamp bounds inward so the scan cannot include the upper arm.
    double clampLeft(double bound) {
      var b = bound;
      if (lm.leftElbow.confidence >= 0.4 && lm.leftElbow.x < lm.leftShoulder.x) {
        b = max(b, lm.leftElbow.x + shoulderSpan * 0.03);
      }
      return b;
    }

    double clampRight(double bound) {
      var b = bound;
      if (lm.rightElbow.confidence >= 0.4 && lm.rightElbow.x > lm.rightShoulder.x) {
        b = min(b, lm.rightElbow.x - shoulderSpan * 0.03);
      }
      return b;
    }

    // Shoulder surface: ±18% of shoulder span.
    final shoulderLeft = clampLeft(shoulderMinX - shoulderSpan * 0.18);
    final shoulderRight = clampRight(shoulderMaxX + shoulderSpan * 0.18);

    // Chest: ±12% — narrower than shoulder; excludes A-pose upper arm.
    final chestLeft = clampLeft(shoulderMinX - shoulderSpan * 0.12);
    final chestRight = clampRight(shoulderMaxX + shoulderSpan * 0.12);

    // Waist: ±15% with elbow clamp.
    final waistLeft = clampLeft(shoulderMinX - shoulderSpan * 0.15);
    final waistRight = clampRight(shoulderMaxX + shoulderSpan * 0.15);

    // Hip: the buttock/hip surface is WIDER than the hip-JOINT landmark span
    // (ML Kit hip landmark = acetabulum, ~10-15 cm narrower than outer hip).
    // Basing margins on the narrow hip-joint span clipped the true hip and
    // made hip < waist. Use shoulder span (stable) for outward reach instead.
    final hipCenterX = (hipMinX + hipMaxX) / 2;
    final hipHalf = shoulderSpan * 0.70; // up to ~1.40× shoulder total
    var hipLeft = hipCenterX - hipHalf;
    var hipRight = hipCenterX + hipHalf;

    // Exclude A-pose hands: at hip Y-level the wrists may be out to the sides.
    // Clamp to just inside a wrist ONLY when that wrist sits clearly beyond the
    // hip-joint edge (so hands-on-hip poses are not over-clipped).
    final wristLeftX = min(lm.leftWrist.x, lm.rightWrist.x);
    final wristRightX = max(lm.leftWrist.x, lm.rightWrist.x);
    final leftWristOk =
        lm.leftWrist.confidence >= 0.4 || lm.rightWrist.confidence >= 0.4;
    if (leftWristOk && wristLeftX < hipMinX) {
      hipLeft = max(hipLeft, wristLeftX + shoulderSpan * 0.06);
    }
    if (leftWristOk && wristRightX > hipMaxX) {
      hipRight = min(hipRight, wristRightX - shoulderSpan * 0.06);
    }

    // Safety floor: hip band must never be narrower than the hip-joint span
    // (a hip can never be narrower than the pelvis bone).
    if (hipLeft > hipMinX) hipLeft = hipMinX;
    if (hipRight < hipMaxX) hipRight = hipMaxX;

    return _FrontBounds(
      shoulderLeft: shoulderLeft,
      shoulderRight: shoulderRight,
      chestLeft: chestLeft,
      chestRight: chestRight,
      waistLeft: waistLeft,
      waistRight: waistRight,
      hipLeft: hipLeft,
      hipRight: hipRight,
    );
  }

  // ─── Side torso depth (central strip) ─────────────────────────────

  /// Measures anterior-posterior torso depth at [yImage] using only the
  /// central vertical strip around [torsoCenterX].
  BodyWidthResult _getSideTorsoDepth({
    required SegmentationResult mask,
    required double yImage,
    required double torsoCenterX,
    required int imageWidth,
    required int imageHeight,
    int scanRows = 5,
    double? stripHalfFraction,
    bool pickMinimum = false,
  }) {
    final stripHalfPx = imageWidth * (stripHalfFraction ?? _sideTorsoStripFraction);
    final leftBound = torsoCenterX - stripHalfPx;
    final rightBound = torsoCenterX + stripHalfPx;

    final rowStep = imageHeight / mask.height;
    final valid = <BodyWidthResult>[];

    for (int offset = -scanRows; offset <= scanRows; offset++) {
      final y = yImage + offset * rowStep;
      if (y < 0 || y >= imageHeight) continue;

      final result = _getWidthAtY(
        mask: mask,
        yImage: y,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        leftBoundImage: leftBound,
        rightBoundImage: rightBound,
      );

      final minWidthPx = imageWidth * minWidthFraction;
      if (result.isValid && result.widthPx >= minWidthPx) {
        valid.add(result);
      }
    }

    if (valid.isEmpty) return BodyWidthResult.notFound();

    valid.sort((a, b) => a.widthPx.compareTo(b.widthPx));
    // Chest/waist: median resists one spurious row.
    // Hip (pickMinimum): narrowest row ≈ pelvis without thigh forward bulge.
    final picked = pickMinimum
        ? valid.first
        : valid[valid.length ~/ 2];

    return BodyWidthResult(
      widthPx: picked.widthPx,
      leftEdgePx: picked.leftEdgePx,
      rightEdgePx: picked.rightEdgePx,
      confidence: pickMinimum ? 0.78 : 0.82,
    );
  }

  // ─── Front width extraction ───────────────────────────────────────

  BodyWidthResult _getWidthAveraged({
    required SegmentationResult mask,
    required double yImage,
    required int imageWidth,
    required int imageHeight,
    int scanRows = 5,
    bool findWidest = true,
    double? leftBoundImage,
    double? rightBoundImage,
  }) {
    final minWidthPx = imageWidth * minWidthFraction;
    final rowStep = imageHeight / mask.height;
    final validWidths = <BodyWidthResult>[];

    for (int offset = -scanRows; offset <= scanRows; offset++) {
      final y = yImage + offset * rowStep;
      if (y < 0 || y >= imageHeight) continue;

      final result = _getWidthAtY(
        mask: mask,
        yImage: y,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        leftBoundImage: leftBoundImage,
        rightBoundImage: rightBoundImage,
      );

      if (result.isValid && result.widthPx >= minWidthPx) {
        validWidths.add(result);
      }
    }

    if (validWidths.isEmpty) return BodyWidthResult.notFound();

    validWidths.sort(
      (a, b) => findWidest
          ? b.widthPx.compareTo(a.widthPx)
          : a.widthPx.compareTo(b.widthPx),
    );

    final k = min(_topK, validWidths.length);
    final candidates = validWidths.take(k).toList();

    final avgWidth =
        candidates.map((r) => r.widthPx).reduce((a, b) => a + b) / k;
    final avgLeft =
        candidates.map((r) => r.leftEdgePx).reduce((a, b) => a + b) / k;
    final avgRight =
        candidates.map((r) => r.rightEdgePx).reduce((a, b) => a + b) / k;

    final stdDev = _stdDev(candidates.map((r) => r.widthPx).toList());
    final normalizedStd = (stdDev / max(avgWidth, 1.0)).clamp(0.0, 1.0);
    final consistency = 1.0 - normalizedStd;
    final confidence = (0.70 + consistency * 0.22).clamp(0.70, 0.92);

    return BodyWidthResult(
      widthPx: avgWidth,
      leftEdgePx: avgLeft,
      rightEdgePx: avgRight,
      confidence: confidence,
    );
  }

  BodyWidthResult _getWidthAtY({
    required SegmentationResult mask,
    required double yImage,
    required int imageWidth,
    required int imageHeight,
    double? leftBoundImage,
    double? rightBoundImage,
  }) {
    final maskRow = (yImage * mask.height / imageHeight).round().clamp(
      0,
      mask.height - 1,
    );

    final leftMaskBound = leftBoundImage != null
        ? (leftBoundImage * mask.width / imageWidth).round().clamp(
            0,
            mask.width - 1,
          )
        : null;
    final rightMaskBound = rightBoundImage != null
        ? (rightBoundImage * mask.width / imageWidth).round().clamp(
            0,
            mask.width - 1,
          )
        : null;

    final edges = mask.scanRow(
      maskRow,
      threshold: bodyThreshold,
      leftBound: leftMaskBound,
      rightBound: rightMaskBound,
    );

    if (edges.left == null || edges.right == null) {
      return BodyWidthResult.notFound();
    }

    final leftEdgeImage = edges.left! * imageWidth / mask.width;
    final rightEdgeImage = edges.right! * imageWidth / mask.width;
    final widthImage = rightEdgeImage - leftEdgeImage;

    if (widthImage <= 0) return BodyWidthResult.notFound();

    return BodyWidthResult(
      widthPx: widthImage,
      leftEdgePx: leftEdgeImage,
      rightEdgePx: rightEdgeImage,
      confidence: 0.90,
    );
  }

  BodyOutline _emptyOutline() => BodyOutline(
    shoulderWidth: BodyWidthResult.notFound(),
    chestWidth: BodyWidthResult.notFound(),
    waistWidth: BodyWidthResult.notFound(),
    hipWidth: BodyWidthResult.notFound(),
  );

  double _stdDev(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
        values.length;
    return sqrt(variance);
  }
}

class _FrontBounds {
  final double shoulderLeft;
  final double shoulderRight;
  final double chestLeft;
  final double chestRight;
  final double waistLeft;
  final double waistRight;
  final double hipLeft;
  final double hipRight;

  const _FrontBounds({
    required this.shoulderLeft,
    required this.shoulderRight,
    required this.chestLeft,
    required this.chestRight,
    required this.waistLeft,
    required this.waistRight,
    required this.hipLeft,
    required this.hipRight,
  });
}
