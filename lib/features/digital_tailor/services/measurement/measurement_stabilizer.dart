import '../../models/measurement_confidence.dart';

/// TASK 3 — Segmentation-noise compensation via temporal smoothing.
///
/// The final measurement is computed from a single still capture, so there is
/// no frame stream to smooth at that instant (live-stream landmark jitter is
/// already handled upstream by the OneEuroFilter in `LandmarkSmoother`). The
/// remaining instability is POSE-TO-POSE: two consecutive scans of the same
/// person can land on different size tiers because segmentation noise shifts a
/// width/depth by a few centimetres.
///
/// This stabilizer keeps an exponential moving average (EMA) of the
/// size-driving measurements ACROSS scans within one session:
///
///   ema_new = α · ema_prev + (1 − α) · value_current
///
/// with α = history weight (0.6–0.8). A higher α smooths harder. The EMA is
/// reset whenever a new scan session starts (new user / restart), so it never
/// blends measurements from different people.
class MeasurementStabilizer {
  /// History weight (0.6–0.8). 0.6 = moderate smoothing, 0.8 = strong.
  final double alpha;

  MeasurementStabilizer({this.alpha = 0.6});

  /// Measurements whose fluctuation directly affects the predicted size.
  static const Set<String> _smoothedKeys = {
    'dada',
    'pinggang',
    'pinggul',
    'bahu',
    'lebar_dada',
    'lebar_pinggang',
    'lebar_pinggul',
  };

  final Map<String, double> _ema = {};
  int _scanCount = 0;

  /// Number of scans blended so far in this session.
  int get scanCount => _scanCount;

  /// Clear all history — call at the start of a new scan session.
  void reset() {
    _ema.clear();
    _scanCount = 0;
  }

  /// Apply the EMA to the size-driving measurements and return a new list.
  ///
  /// The first scan of a session passes through unchanged (seeds the EMA).
  /// Confidence is left untouched here; the confidence scorer handles that.
  List<MeasurementWithConfidence> stabilize(
    List<MeasurementWithConfidence> measurements,
  ) {
    _scanCount++;
    return measurements.map((m) {
      if (!_smoothedKeys.contains(m.key)) return m;

      final prev = _ema[m.key];
      final smoothed =
          prev == null ? m.valueCm : alpha * prev + (1 - alpha) * m.valueCm;
      _ema[m.key] = smoothed;

      if (prev == null) return m; // first observation: no change
      return m.copyWith(
        valueCm: (smoothed * 10).roundToDouble() / 10,
        valueInch: (smoothed / 2.54 * 10).roundToDouble() / 10,
      );
    }).toList();
  }
}
