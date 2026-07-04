import 'dart:math';

/// Shared ellipse circumference math for body measurement.
///
/// Uses Ramanujan's second approximation with semi-axes [a] and [b]
/// (half front width and half side depth — NOT full diameters).
class EllipseCircumference {
  EllipseCircumference._();

  /// Ramanujan II: C ≈ π(a+b)(1 + 3h/(10+√(4-3h))), h = ((a-b)/(a+b))²
  static double fromSemiAxes(double semiAxisAcm, double semiAxisBcm) {
    if (semiAxisAcm <= 0 || semiAxisBcm <= 0) return 0;
    final h = pow((semiAxisAcm - semiAxisBcm) / (semiAxisAcm + semiAxisBcm), 2)
        .toDouble();
    return pi *
        (semiAxisAcm + semiAxisBcm) *
        (1 + 3 * h / (10 + sqrt(4 - 3 * h)));
  }

  /// PRIMARY circumference estimator from FULL width & depth diameters.
  ///
  /// Converts to semi-axes (a = width/2, b = depth/2) and applies the accurate
  /// Ramanujan II approximation. This is dimensionally correct: for a circle
  /// (width == depth == D) it yields exactly π·D.
  ///
  /// STABILITY: Ramanujan is accurate but sensitive to noisy depth. Callers
  /// therefore FIRST pass the depth through [normalizeDepth] (clamped to the
  /// anatomical band 0.55–0.85 × width). With the depth bounded, the estimator
  /// is both accurate AND stable — no XL↔M flip. (An earlier linear π(0.65w +
  /// 0.35d) blend was tried but over-estimated girth by ~3 cm on real bodies.)
  static double fromFull({
    required double fullWidthCm,
    required double fullDepthCm,
  }) {
    if (fullWidthCm <= 0 || fullDepthCm <= 0) return 0;
    return fromSemiAxes(fullWidthCm / 2, fullDepthCm / 2);
  }

  /// Anatomical side-depth constraint relative to the front width.
  ///
  /// Human torso AP-depth is bounded: it is never a flat sheet nor as deep as
  /// it is wide. Enforcing 0.55–0.85× width prevents both depth COLLAPSE
  /// (→ under-measure → SIZE M) and depth BLOW-UP (→ over-measure → SIZE XL).
  /// The scan is NEVER rejected — out-of-range depth is clamped and the caller
  /// lowers confidence instead.
  static const double depthMinRatio = 0.55;
  static const double depthMaxRatio = 0.85;

  /// Returns the depth clamped to [minRatio, maxRatio] × frontWidth and whether
  /// clamping occurred (so callers can reduce confidence).
  static ({double depthCm, bool clamped}) normalizeDepth({
    required double depthCm,
    required double frontWidthCm,
    double minRatio = depthMinRatio,
    double maxRatio = depthMaxRatio,
  }) {
    if (frontWidthCm <= 0) return (depthCm: depthCm, clamped: false);
    final lo = frontWidthCm * minRatio;
    final hi = frontWidthCm * maxRatio;
    if (depthCm < lo) return (depthCm: lo, clamped: true);
    if (depthCm > hi) return (depthCm: hi, clamped: true);
    return (depthCm: depthCm, clamped: false);
  }

  /// Full front width / full linear width ratio for chest/waist/hip.
  ///
  /// Empirical tailoring range: circumference is ~2.4–3.0× the front
  /// linear width for adults. Values above 3.2 indicate arm-contaminated
  /// depth or width.
  static bool isPlausibleCircumferenceRatio({
    required double circumferenceCm,
    required double linearWidthCm,
    double minRatio = 2.15,
    double maxRatio = 3.15,
  }) {
    if (linearWidthCm <= 0) return false;
    final ratio = circumferenceCm / linearWidthCm;
    return ratio >= minRatio && ratio <= maxRatio;
  }

  /// Depth/width ratio using full diameters (not semi-axes).
  static bool isPlausibleDepthToWidth({
    required double depthCm,
    required double widthCm,
    required double minRatio,
    required double maxRatio,
  }) {
    if (widthCm <= 0 || depthCm <= 0) return false;
    final ratio = depthCm / widthCm;
    return ratio >= minRatio && ratio <= maxRatio;
  }

  static double round1(double value) => (value * 10).roundToDouble() / 10;
}
