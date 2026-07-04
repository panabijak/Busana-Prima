import '../../models/body_outline.dart';
import 'ellipse_circumference.dart';

/// Fuses front width + side torso depth into a circumference.
///
/// STABILITY DESIGN (fixes the XL↔M size flip):
///   1. Side depth is CLAMPED to an anatomical band (0.55–0.85 × front width)
///      instead of rejecting the scan. This bounds the only volatile input and
///      is what actually removes the instability.
///   2. Circumference uses the accurate Ramanujan II ellipse approximation on
///      semi-axes (width/2, depth/2). Accurate because the depth is already
///      bounded by step 1.
///   3. Fusion NEVER returns null for plausible width input; clamping only
///      lowers confidence. This removes the "fusion rejects → estimator
///      fallback → different value → flip" path.
class FrontSideFusion {
  final double pixelToCmFront;
  final double pixelToCmSide;

  const FrontSideFusion({
    required this.pixelToCmFront,
    required this.pixelToCmSide,
  });

  FusedCircumferences? fuse({
    required BodyOutline frontOutline,
    required BodyOutline sideOutline,
    double? chestLinearWidthCm,
    double? waistLinearWidthCm,
    double? hipLinearWidthCm,
  }) {
    if (!frontOutline.chestWidth.isValid && !frontOutline.waistWidth.isValid) {
      return null;
    }

    return FusedCircumferences(
      chestCircumference: _fuseAtLevel(
        frontWidth: frontOutline.chestWidth,
        sideDepth: sideOutline.chestWidth,
        linearWidthCm: chestLinearWidthCm,
      ),
      waistCircumference: _fuseAtLevel(
        frontWidth: frontOutline.waistWidth,
        sideDepth: sideOutline.waistWidth,
        linearWidthCm: waistLinearWidthCm,
      ),
      hipCircumference: _fuseAtLevel(
        frontWidth: frontOutline.hipWidth,
        sideDepth: sideOutline.hipWidth,
        linearWidthCm: hipLinearWidthCm,
      ),
    );
  }

  FusedMeasurement? _fuseAtLevel({
    required BodyWidthResult frontWidth,
    required BodyWidthResult sideDepth,
    double? linearWidthCm,
  }) {
    if (!frontWidth.isValid || !sideDepth.isValid) return null;

    // Must match lebar_* linear width shown in results (LinearMeasurer output).
    final fullWidthCm = linearWidthCm ?? (frontWidth.widthPx * pixelToCmFront);
    final rawDepthCm = sideDepth.widthPx * pixelToCmSide;

    if (fullWidthCm <= 0 || rawDepthCm <= 0) return null;

    // TASK 1: anatomical depth normalization (clamp, never reject).
    final norm = EllipseCircumference.normalizeDepth(
      depthCm: rawDepthCm,
      frontWidthCm: fullWidthCm,
    );
    final fullDepthCm = norm.depthCm;

    // Accurate Ramanujan estimator — stabilised by the depth clamp above.
    final circumference = EllipseCircumference.fromFull(
      fullWidthCm: fullWidthCm,
      fullDepthCm: fullDepthCm,
    );
    if (circumference <= 0) return null;

    // Confidence: segmentation quality, reduced when the depth had to be
    // clamped (a sign the raw side reading was noisy).
    final segConf = (frontWidth.confidence + sideDepth.confidence) / 2;
    var confidence = (segConf * 0.85 + 0.10).clamp(0.55, 0.93);
    if (norm.clamped) confidence = (confidence * 0.80).clamp(0.45, 0.93);

    return FusedMeasurement(
      valueCm: EllipseCircumference.round1(circumference),
      valueInch: EllipseCircumference.round1(circumference / 2.54),
      halfWidthCm: fullWidthCm / 2,
      halfDepthCm: fullDepthCm / 2,
      fullWidthCm: fullWidthCm,
      fullDepthCm: fullDepthCm,
      widthPx: linearWidthCm != null
          ? linearWidthCm / pixelToCmFront
          : frontWidth.widthPx,
      depthPx: sideDepth.widthPx,
      confidence: confidence,
      depthClamped: norm.clamped,
    );
  }
}

class FusedCircumferences {
  final FusedMeasurement? chestCircumference;
  final FusedMeasurement? waistCircumference;
  final FusedMeasurement? hipCircumference;

  const FusedCircumferences({
    this.chestCircumference,
    this.waistCircumference,
    this.hipCircumference,
  });
}

class FusedMeasurement {
  final double valueCm;
  final double valueInch;
  final double halfWidthCm;
  final double halfDepthCm;
  final double fullWidthCm;
  final double fullDepthCm;
  final double widthPx;
  final double depthPx;
  final double confidence;

  /// True when the raw side depth was outside the anatomical band and clamped.
  final bool depthClamped;

  const FusedMeasurement({
    required this.valueCm,
    required this.valueInch,
    required this.halfWidthCm,
    required this.halfDepthCm,
    required this.fullWidthCm,
    required this.fullDepthCm,
    required this.widthPx,
    required this.depthPx,
    required this.confidence,
    this.depthClamped = false,
  });
}
