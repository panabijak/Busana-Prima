import '../../models/measurement_confidence.dart';

/// Validation result for a single measurement.
class RangeValidationResult {
  final bool isValid;
  final String? reason;

  const RangeValidationResult({required this.isValid, this.reason});
}

/// Validates that measurement values fall within physiologically possible
/// ranges for adult humans.
///
/// Ranges are based on anthropometric surveys (ISO 8559, CAESAR database)
/// covering the 1st to 99th percentile of adult body dimensions.
class RangeValidator {
  /// Physiological ranges in cm: (min, max) for each measurement key.
  static const Map<String, (double, double)> ranges = {
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

  /// Validate a single measurement against its physiological range.
  RangeValidationResult validate(MeasurementWithConfidence measurement) {
    final range = ranges[measurement.key];
    if (range == null) {
      return const RangeValidationResult(isValid: true);
    }

    if (measurement.valueCm < range.$1) {
      return RangeValidationResult(
        isValid: false,
        reason: 'Terlalu kecil (minimum ${range.$1} cm)',
      );
    }
    if (measurement.valueCm > range.$2) {
      return RangeValidationResult(
        isValid: false,
        reason: 'Terlalu besar (maksimum ${range.$2} cm)',
      );
    }

    return const RangeValidationResult(isValid: true);
  }

  /// Validate all measurements in a list.
  Map<String, RangeValidationResult> validateAll(
    List<MeasurementWithConfidence> measurements,
  ) {
    return {for (final m in measurements) m.key: validate(m)};
  }
}
