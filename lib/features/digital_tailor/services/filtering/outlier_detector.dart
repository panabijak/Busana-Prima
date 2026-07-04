import 'dart:math';

/// Statistical outlier detection utilities.
///
/// Used to identify and remove unreliable measurements
/// before final computation.
class OutlierDetector {
  /// Detect outliers in a list of values using the IQR method.
  ///
  /// Returns indices of outlier values (values beyond 1.5 × IQR from Q1/Q3).
  static List<int> detectIQR(List<double> values, {double factor = 1.5}) {
    if (values.length < 4) return [];

    final sorted = List<double>.from(values)..sort();
    final q1 = _percentile(sorted, 25);
    final q3 = _percentile(sorted, 75);
    final iqr = q3 - q1;

    final lower = q1 - factor * iqr;
    final upper = q3 + factor * iqr;

    final outliers = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (values[i] < lower || values[i] > upper) {
        outliers.add(i);
      }
    }
    return outliers;
  }

  /// Detect outliers using Z-score method.
  ///
  /// Values more than [threshold] standard deviations from the mean
  /// are considered outliers.
  static List<int> detectZScore(List<double> values, {double threshold = 2.0}) {
    if (values.length < 3) return [];

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
        values.length;
    final stdDev = sqrt(variance);

    if (stdDev == 0) return [];

    final outliers = <int>[];
    for (int i = 0; i < values.length; i++) {
      final zScore = (values[i] - mean).abs() / stdDev;
      if (zScore > threshold) {
        outliers.add(i);
      }
    }
    return outliers;
  }

  /// Remove outliers and return cleaned list.
  static List<double> removeOutliers(List<double> values) {
    final outlierIndices = detectIQR(values);
    if (outlierIndices.isEmpty) return values;

    return [
      for (int i = 0; i < values.length; i++)
        if (!outlierIndices.contains(i)) values[i],
    ];
  }

  /// Compute the median of a list.
  static double median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static double _percentile(List<double> sorted, int percentile) {
    final index = (percentile / 100 * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}
