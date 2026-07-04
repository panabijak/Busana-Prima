import '../models/measurement.dart';

/// Automatically detects clothing size category from body measurements.
///
/// TASK 5 — Distance-based classification (NOT single-measurement thresholds).
///
/// A direct cm→size threshold on one measurement (chest) is unstable: a 1 cm
/// change at a boundary flips the size tier. Instead each size is represented
/// by a CENTROID over (chest, waist, hip, height) and we pick the nearest
/// centroid under a WEIGHTED normalized distance:
///
///   d(size)² = Σ wᵢ · ((valueᵢ − centroidᵢ) / scaleᵢ)²   (over available dims)
///
///   weights: chest 0.35, waist 0.25, hip 0.25, height 0.15
///
/// Multi-dimensional consensus means one noisy measurement cannot flip the
/// class on its own, and the smooth distance metric makes the prediction
/// stable across repeated scans.
///
/// This service NEVER blocks on ratios. Trustworthiness is signalled via the
/// confidence report (low-confidence measurements are shown as such).
class SizeDetectionService {
  static const List<String> _sizes = [
    'XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL',
  ];

  // Malaysian/Southeast Asian centroids (band midpoints, cm). Western charts
  // run ~6–8 cm larger per tier; these follow Padini/Nichii sizing guides.
  static const List<double> _chestC = [76, 84, 92, 100, 108, 116, 124];
  static const List<double> _waistC = [60, 68, 76, 84, 92, 100, 108];
  static const List<double> _hipC = [82, 90, 98, 106, 114, 122, 130];
  static const List<double> _heightC = [150, 158, 164, 169, 173, 177, 181];

  /// Detect size category. Returns XS…XXXL, or '-' when no plausible primary
  /// measurement is available. [userHeightCm] contributes 15% when provided.
  String detectSize(List<Measurement> measurements, {double? userHeightCm}) {
    if (measurements.isEmpty) return '-';

    double? inRange(String key) {
      try {
        final m = measurements.firstWhere((m) => m.key == key);
        return m.isWithinRange ? m.valueCm : null;
      } catch (_) {
        return null;
      }
    }

    final dims = <_SizeDim>[];
    final chest = inRange('dada');
    if (chest != null) dims.add(_SizeDim(chest, _chestC, 8, 0.35));
    final waist = inRange('pinggang');
    if (waist != null) dims.add(_SizeDim(waist, _waistC, 8, 0.25));
    final hip = inRange('pinggul');
    if (hip != null) dims.add(_SizeDim(hip, _hipC, 8, 0.25));
    if (userHeightCm != null && userHeightCm >= 80 && userHeightCm <= 230) {
      dims.add(_SizeDim(userHeightCm, _heightC, 6, 0.15));
    }

    if (dims.isEmpty) return '-';

    final totalWeight = dims.fold<double>(0, (a, d) => a + d.weight);

    var bestSize = '-';
    var bestDist = double.infinity;
    for (var i = 0; i < _sizes.length; i++) {
      var dist = 0.0;
      for (final d in dims) {
        final diff = (d.value - d.centroids[i]) / d.scale;
        dist += d.weight * diff * diff;
      }
      dist /= totalWeight;
      if (dist < bestDist) {
        bestDist = dist;
        bestSize = _sizes[i];
      }
    }
    return bestSize;
  }
}

/// One dimension of the weighted size-distance calculation.
class _SizeDim {
  final double value;
  final List<double> centroids;
  final double scale;
  final double weight;

  const _SizeDim(this.value, this.centroids, this.scale, this.weight);
}
