/// Represents a single body measurement with dual-unit values.
class Measurement {
  final String key;
  final String label;
  final double valueCm;
  final double valueInch;
  final MeasurementRegion region;

  const Measurement({
    required this.key,
    required this.label,
    required this.valueCm,
    required this.valueInch,
    required this.region,
  });

  factory Measurement.fromMap(String key, Map<String, dynamic> data) {
    return Measurement(
      key: key,
      label: data['label'] as String? ?? key,
      valueCm: (data['value_cm'] as num?)?.toDouble() ?? 0.0,
      valueInch: (data['value_inch'] as num?)?.toDouble() ?? 0.0,
      region: MeasurementRegion.fromString(
        data['region'] as String? ?? 'tengah',
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'value_cm': valueCm,
      'value_inch': valueInch,
      'region': region.name,
    };
  }

  /// Check if value is within physiological range
  bool get isWithinRange {
    final range = _physiologicalRanges[key];
    if (range == null) return true;
    return valueCm >= range.$1 && valueCm <= range.$2;
  }

  /// Physiological ranges in cm for validation
  static const Map<String, (double, double)> _physiologicalRanges = {
    'bahu': (20.0, 70.0),
    'dada': (50.0, 180.0),
    'pinggang': (40.0, 200.0),
    'pinggul': (50.0, 180.0),
    'lingkar_leher': (20.0, 60.0),
    'panjang_lengan': (30.0, 100.0),
    'panjang_kaki': (50.0, 130.0),
  };
}

/// Body region grouping for display
enum MeasurementRegion {
  atas, // Upper: Bahu, Lingkar Leher
  tengah, // Middle: Dada, Pinggang, Pinggul, Panjang Lengan
  bawah; // Lower: Panjang Kaki

  String get displayName {
    switch (this) {
      case MeasurementRegion.atas:
        return 'Atas (Upper)';
      case MeasurementRegion.tengah:
        return 'Tengah (Middle)';
      case MeasurementRegion.bawah:
        return 'Bawah (Lower)';
    }
  }

  static MeasurementRegion fromString(String value) {
    switch (value) {
      case 'atas':
        return MeasurementRegion.atas;
      case 'bawah':
        return MeasurementRegion.bawah;
      default:
        return MeasurementRegion.tengah;
    }
  }
}
