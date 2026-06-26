import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Service that monitors device orientation using the accelerometer
/// to ensure the phone is held at exactly 90° (vertical).
class LevelingService {
  StreamSubscription<AccelerometerEvent>? _subscription;
  final StreamController<LevelingState> _stateController =
      StreamController<LevelingState>.broadcast();

  /// Acceptable tilt deviation in degrees from vertical
  static const double maxDeviationDegrees = 5.0;

  /// Minimum time the device must be stable before enabling capture
  static const Duration stabilityDuration = Duration(milliseconds: 300);

  DateTime? _stableStartTime;
  bool _isLevel = false;

  /// Stream of leveling state updates
  Stream<LevelingState> get stateStream => _stateController.stream;

  /// Whether the device is currently level
  bool get isLevel => _isLevel;

  /// Start monitoring device orientation
  void start() {
    _subscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 33), // ~30 Hz
    ).listen(_onAccelerometerEvent);
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Calculate tilt angle from vertical
    // When phone is perfectly vertical: x ≈ 0, y ≈ ±9.8, z ≈ 0
    // Gravity vector magnitude
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude == 0) return;

    // Angle from vertical (y-axis should be dominant when vertical)
    // cos(angle) = |y| / magnitude
    final cosAngle = event.y.abs() / magnitude;
    final angleDegrees = acos(cosAngle.clamp(-1.0, 1.0)) * 180 / pi;

    // Determine tilt direction for user guidance
    String? hint;
    if (angleDegrees > maxDeviationDegrees) {
      if (event.x.abs() > 1.5) {
        hint = event.x > 0 ? 'Miringkan ke kiri' : 'Miringkan ke kanan';
      } else if (event.z.abs() > 1.5) {
        hint = event.z > 0 ? 'Miringkan ke depan' : 'Miringkan ke belakang';
      } else {
        hint = 'Tegakkan perangkat';
      }
    }

    final withinRange = angleDegrees <= maxDeviationDegrees;

    if (withinRange) {
      _stableStartTime ??= DateTime.now();

      final stableDuration = DateTime.now().difference(_stableStartTime!);
      final isStable = stableDuration >= stabilityDuration;

      if (isStable && !_isLevel) {
        _isLevel = true;
        _stateController.add(
          LevelingState(
            isLevel: true,
            angleDegrees: angleDegrees,
            justBecameLevel: true,
          ),
        );
      } else if (isStable) {
        _stateController.add(
          LevelingState(isLevel: true, angleDegrees: angleDegrees),
        );
      }
    } else {
      _stableStartTime = null;
      if (_isLevel) {
        _isLevel = false;
      }
      _stateController.add(
        LevelingState(isLevel: false, angleDegrees: angleDegrees, hint: hint),
      );
    }
  }

  /// Stop monitoring
  void dispose() {
    _subscription?.cancel();
    _stateController.close();
  }
}

/// Represents the current leveling state of the device
class LevelingState {
  final bool isLevel;
  final double angleDegrees;
  final String? hint;
  final bool justBecameLevel;

  const LevelingState({
    required this.isLevel,
    required this.angleDegrees,
    this.hint,
    this.justBecameLevel = false,
  });
}
