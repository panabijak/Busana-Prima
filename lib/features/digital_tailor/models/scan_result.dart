import 'measurement.dart';

/// Result of a completed scan session with all calculated measurements.
class ScanResult {
  final List<Measurement> measurements;
  final double confidenceScore;
  final DateTime scannedAt;
  final String scanVersion;

  const ScanResult({
    required this.measurements,
    required this.confidenceScore,
    required this.scannedAt,
    this.scanVersion = '1.0.0',
  });

  /// Confidence level label
  String get confidenceLabel {
    if (confidenceScore >= 0.8) return 'Tinggi';
    if (confidenceScore >= 0.6) return 'Sedang';
    return 'Rendah';
  }

  /// Group measurements by body region
  Map<MeasurementRegion, List<Measurement>> get groupedMeasurements {
    final grouped = <MeasurementRegion, List<Measurement>>{};
    for (final m in measurements) {
      grouped.putIfAbsent(m.region, () => []).add(m);
    }
    return grouped;
  }

  /// Measurements that fall outside physiological ranges
  List<Measurement> get flaggedMeasurements {
    return measurements.where((m) => !m.isWithinRange).toList();
  }

  /// Convert to Firestore map format
  Map<String, dynamic> toFirestoreMap() {
    final map = <String, dynamic>{
      'scanned_at': scannedAt,
      'confidence_score': confidenceScore,
      'scan_version': scanVersion,
    };

    for (final m in measurements) {
      map[m.key] = m.toMap();
    }

    return map;
  }
}
