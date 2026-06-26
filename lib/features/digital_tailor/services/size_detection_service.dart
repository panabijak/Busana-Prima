import '../models/measurement.dart';

/// Automatically detects clothing size category based on body measurements.
/// Uses chest circumference as primary indicator, waist as secondary.
class SizeDetectionService {
  /// Detect size category from a list of measurements.
  /// Returns size string: XS, S, M, L, XL, XXL, XXXL
  String detectSize(List<Measurement> measurements) {
    double? chestCm;
    double? waistCm;
    double? shoulderCm;

    for (final m in measurements) {
      switch (m.key) {
        case 'dada':
          chestCm = m.valueCm;
          break;
        case 'pinggang':
          waistCm = m.valueCm;
          break;
        case 'bahu':
          shoulderCm = m.valueCm;
          break;
      }
    }

    // Priority: Chest > Waist > Shoulder
    if (chestCm != null) {
      return _sizeFromChest(chestCm);
    }
    if (waistCm != null) {
      return _sizeFromWaist(waistCm);
    }
    if (shoulderCm != null) {
      return _sizeFromShoulder(shoulderCm);
    }

    return '-'; // Cannot determine
  }

  /// Size from chest circumference (primary)
  String _sizeFromChest(double cm) {
    if (cm < 88) return 'XS';
    if (cm < 94) return 'S';
    if (cm < 102) return 'M';
    if (cm < 110) return 'L';
    if (cm < 118) return 'XL';
    if (cm < 126) return 'XXL';
    return 'XXXL';
  }

  /// Size from waist circumference (secondary)
  String _sizeFromWaist(double cm) {
    if (cm < 74) return 'XS';
    if (cm < 80) return 'S';
    if (cm < 88) return 'M';
    if (cm < 96) return 'L';
    if (cm < 104) return 'XL';
    if (cm < 112) return 'XXL';
    return 'XXXL';
  }

  /// Size from shoulder width (tertiary fallback)
  String _sizeFromShoulder(double cm) {
    if (cm < 40) return 'XS';
    if (cm < 43) return 'S';
    if (cm < 46) return 'M';
    if (cm < 49) return 'L';
    if (cm < 52) return 'XL';
    if (cm < 55) return 'XXL';
    return 'XXXL';
  }
}
