import '../../models/calibration_result.dart';
import 'height_calibrator.dart';
import 'segmentation_calibrator.dart';

/// Abstract calibration strategy.
///
/// Each strategy has a priority (lower = tried first) and an implementation
/// that attempts to derive a pixel-to-cm conversion factor.
abstract class CalibrationStrategy {
  /// Priority order (lower = higher priority, tried first).
  int get priority;

  /// Human-readable name for logging/display.
  String get methodName;

  /// Whether this strategy has the required input data to attempt calibration.
  bool isAvailable(CalibrationInput input);

  /// Attempt calibration. Returns null if this strategy fails.
  Future<CalibrationResult?> calibrate(CalibrationInput input);
}

/// The calibration engine tries strategies in priority order
/// until one succeeds. This makes it easy to add new calibration methods
/// without modifying existing code (Open/Closed Principle).
class CalibrationEngine {
  final List<CalibrationStrategy> _strategies;

  CalibrationEngine({List<CalibrationStrategy>? strategies})
    : _strategies =
          (strategies ??
                [
                  SegmentationCalibrator(), // priority 2 — preferred when mask is available
                  HeightCalibrator(), // priority 4 — fallback to landmark-based
                  // ReferenceObjectCalibrator and CameraDistanceCalibrator
                  // can be added here as they are implemented.
                ])
            ..sort((a, b) => a.priority.compareTo(b.priority));

  /// Run calibration using the best available method.
  ///
  /// Tries strategies in priority order. Throws [CalibrationException]
  /// if all strategies fail.
  Future<CalibrationResult> calibrate(CalibrationInput input) async {
    for (final strategy in _strategies) {
      if (!strategy.isAvailable(input)) continue;

      final result = await strategy.calibrate(input);
      if (result != null && result.isValid) {
        return result;
      }
    }

    throw const CalibrationException(
      'Kalibrasi gagal. Tidak ada metode yang berhasil. '
      'Pastikan tinggi badan telah dimasukkan dengan benar.',
    );
  }

  /// Get list of available strategies for the given input.
  List<String> availableMethods(CalibrationInput input) {
    return _strategies
        .where((s) => s.isAvailable(input))
        .map((s) => s.methodName)
        .toList();
  }
}
