/// Per-measurement confidence with metadata about how it was derived.
class MeasurementWithConfidence {
  /// Measurement key identifier (e.g., 'dada', 'pinggang')
  final String key;

  /// Display label
  final String label;

  /// Value in centimeters
  final double valueCm;

  /// Value in inches
  final double valueInch;

  /// Confidence score for this specific measurement (0.0 to 1.0)
  final double confidence;

  /// How this measurement was derived
  final MeasurementSource source;

  /// Body region for grouping
  final String region;

  const MeasurementWithConfidence({
    required this.key,
    required this.label,
    required this.valueCm,
    required this.valueInch,
    required this.confidence,
    required this.source,
    required this.region,
  });

  MeasurementWithConfidence copyWith({
    double? valueCm,
    double? valueInch,
    double? confidence,
    MeasurementSource? source,
  }) {
    return MeasurementWithConfidence(
      key: key,
      label: label,
      valueCm: valueCm ?? this.valueCm,
      valueInch: valueInch ?? this.valueInch,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      region: region,
    );
  }

  /// Whether value falls within physiological range
  bool get isWithinRange {
    final range = _physiologicalRanges[key];
    if (range == null) return true;
    return valueCm >= range.$1 && valueCm <= range.$2;
  }

  /// Convert to Firestore map format
  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'value_cm': valueCm,
      'value_inch': valueInch,
      'confidence': confidence,
      'source': source.name,
      'region': region,
    };
  }

  static const Map<String, (double, double)> _physiologicalRanges = {
    'bahu': (20.0, 60.0),
    'dada': (40.0, 150.0),
    'pinggang': (35.0, 150.0),
    'pinggul': (40.0, 170.0),
    'lingkar_leher': (18.0, 55.0),
    'panjang_lengan': (20.0, 95.0),
    'panjang_kaki': (30.0, 125.0),
    'tinggi_torso': (20.0, 70.0),
    'panjang_punggung': (20.0, 65.0),
    'lebar_dada': (15.0, 60.0),
    'lebar_pinggang': (14.0, 60.0),
    'lebar_pinggul': (16.0, 65.0),
  };
}

/// How a measurement was derived.
enum MeasurementSource {
  /// From body segmentation contour analysis
  segmentation,

  /// From front + side photo fusion with actual depth
  frontSideFusion,

  /// From Euclidean distance between landmarks
  landmarkLinear,

  /// From anthropometric ratio estimation (lower confidence)
  estimation,
}

/// Overall confidence report for a scan session.
class ConfidenceReport {
  /// Overall confidence score (0.0 to 1.0)
  final double overall;

  /// Per-measurement confidence mapping
  final Map<String, double> perMeasurement;

  /// Human-readable label
  final String label;

  const ConfidenceReport({
    required this.overall,
    required this.perMeasurement,
    required this.label,
  });

  /// Get the label for a given confidence value.
  static String labelFor(double confidence) {
    if (confidence >= 0.85) return 'Very High';
    if (confidence >= 0.70) return 'High';
    if (confidence >= 0.55) return 'Medium';
    return 'Low';
  }
}
