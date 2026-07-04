import '../../models/scan_workflow_state.dart';
import 'a_pose_validator.dart';
import 'scan_quality_evaluator.dart';

/// Result of one lock-engine update.
class PoseLockResult {
  final ScanWorkflowState state;
  final double confidence;
  final double jitter;
  final bool justLocked;
  final bool hardReset;
  final String? guidance;

  const PoseLockResult({
    required this.state,
    required this.confidence,
    required this.jitter,
    required this.justLocked,
    required this.hardReset,
    this.guidance,
  });
}

/// Converts noisy per-frame validation into stable scan states.
///
/// The engine uses confidence accumulation with hysteresis. Minor issues reduce
/// confidence gradually; only hard blockers reset the scan.
class PoseLockEngine {
  static const double lockThreshold = 1.0;
  static const double lockingThreshold = 0.45;
  static const double alignThreshold = 0.12;
  static const double hardResetQuality = 0.18;
  static const double hardResetVisibility = 0.15;
  static const double maxStableJitter = 18.0;

  double _confidence = 0.0;
  double _jitter = 0.0;
  ScanWorkflowState _state = ScanWorkflowState.searching;
  bool _wasLocked = false;

  double get confidence => _confidence;
  double get jitter => _jitter;
  ScanWorkflowState get state => _state;

  PoseLockResult update({
    required APoseValidationResult? validation,
    required ScanQualityMetrics quality,
    required double landmarkJitter,
    required bool hasLandmarks,
  }) {
    _jitter = landmarkJitter;

    final hardReset =
        !hasLandmarks ||
        quality.bodyVisibility <= hardResetVisibility ||
        quality.overall <= hardResetQuality;

    if (hardReset) {
      _confidence = 0.0;
      _state = ScanWorkflowState.searching;
      _wasLocked = false;
      return PoseLockResult(
        state: _state,
        confidence: _confidence,
        jitter: _jitter,
        justLocked: false,
        hardReset: true,
        guidance: 'Make sure your full body is visible',
      );
    }

    final poseScore = validation == null
        ? 0.0
        : validation.isValid
        ? 1.0
        : (1.0 - validation.failures.length * 0.18).clamp(0.0, 0.85);
    final jitterScore = landmarkJitter <= maxStableJitter
        ? 1.0
        : (1.0 - (landmarkJitter - maxStableJitter) / maxStableJitter)
              .clamp(0.0, 1.0);

    final frameScore =
        (quality.overall * 0.45 +
                poseScore * 0.35 +
                jitterScore * 0.20)
            .clamp(0.0, 1.0);

    if (frameScore >= 0.72) {
      _confidence += 0.075;
    } else if (frameScore >= 0.52) {
      _confidence += 0.025;
    } else if (frameScore >= 0.35) {
      _confidence -= 0.025;
    } else {
      _confidence -= 0.08;
    }

    _confidence = _confidence.clamp(0.0, lockThreshold);

    if (_confidence >= lockThreshold) {
      _state = ScanWorkflowState.locked;
    } else if (_confidence >= lockingThreshold) {
      _state = ScanWorkflowState.locking;
    } else if (_confidence >= alignThreshold || hasLandmarks) {
      _state = ScanWorkflowState.aligning;
    } else {
      _state = ScanWorkflowState.searching;
    }

    final justLocked = _state == ScanWorkflowState.locked && !_wasLocked;
    _wasLocked = _state == ScanWorkflowState.locked;

    return PoseLockResult(
      state: _state,
      confidence: _confidence,
      jitter: _jitter,
      justLocked: justLocked,
      hardReset: false,
      guidance: validation?.primaryFailure?.guidance,
    );
  }

  void forceState(ScanWorkflowState state) {
    _state = state;
    _wasLocked = state == ScanWorkflowState.locked;
  }

  void reset() {
    _confidence = 0.0;
    _jitter = 0.0;
    _state = ScanWorkflowState.searching;
    _wasLocked = false;
  }
}
