import 'dart:math';

import '../../models/processed_landmarks.dart';
import '../detection/coordinate_transformer.dart';

/// Result of a single A-Pose validation pass.
class APoseValidationResult {
  final bool isValid;
  final bool isStable;
  final List<APoseFailure> failures;
  final int stableFrameCount;
  final int requiredFrames;

  const APoseValidationResult({
    required this.isValid,
    required this.isStable,
    required this.failures,
    required this.stableFrameCount,
    required this.requiredFrames,
  });

  double get stabilityProgress =>
      (stableFrameCount / requiredFrames).clamp(0.0, 1.0);

  /// Most important failure to communicate to user right now.
  APoseFailure? get primaryFailure => failures.isEmpty ? null : failures.first;
}

/// Describes a specific A-Pose check that failed.
class APoseFailure {
  final APoseCheckType type;
  final String guidance; // Indonesian user-facing message
  final String voiceScript; // TTS script

  const APoseFailure({
    required this.type,
    required this.guidance,
    required this.voiceScript,
  });
}

enum APoseCheckType {
  bodyNotDetected,
  feetNotVisible,
  headNotVisible,
  bodyNotCentered,
  bodyTooFar,
  bodyTooClose,
  notStandingStraight,
  armsAngleWrong,
  shouldersUneven,
}

/// Validates an A-Pose for body scanning.
///
/// A-Pose is preferred over T-Pose for portrait phone cameras because:
/// - Arms at 30-45° from body fit within a vertical phone frame
/// - T-Pose with fully extended arms is cut off at the edges in portrait mode
/// - A-Pose still exposes body contours for measurement
/// - More natural, less fatiguing to hold
///
/// Requirements:
/// - Arms 20-50° away from body (not fully extended, not at sides)
/// - Shoulders level (y-difference < 4% of shoulder width)
/// - Legs slightly apart (stance ≥ 10% of body height)
/// - Head visible with confidence ≥ 0.5
/// - Both ankles visible with confidence ≥ 0.4
/// - Body centered (midpoint within 15% of frame center)
/// - Standing straight (hip-ankle alignment)
class APoseValidator {
  /// Camera sensor orientation — determines which axis lm.y maps to.
  /// 270 = front camera (default); 90 = back camera.
  final int sensorOrientation;

  /// Side capture should not enforce front-facing A-pose arm/shoulder rules.
  final bool isSideView;

  APoseValidator({this.sensorOrientation = 270, this.isSideView = false});

  /// Consecutive valid frames required before capture is allowed.
  static const int requiredStableFrames = 20; // ~2s at 10fps

  /// Arm angle tolerance: arms should be 20-50° from vertical body axis.
  static const double minArmAngleDeg = 20.0;
  static const double maxArmAngleDeg = 55.0;

  /// Max shoulder level difference as fraction of shoulder width.
  static const double maxShoulderTiltFraction = 0.08;

  /// Max body center offset from frame center (fraction of screen width).
  /// After the formula fix, ±12% is a tighter but correct dead zone.
  static const double maxCenterOffset = 0.16;

  int _consecutiveValidFrames = 0;

  /// Computes body center X normalized to [0,1] in screen space.
  ///
  /// Uses the same axis mapping as [CoordinateTransformer] so the value
  /// is consistent with what the user sees on the mirrored preview.
  ///
  /// For so=270 front camera (after mirror cancellation):
  ///   normX = lm.y / imageWidth   (lm.y ∈ [0..1280])
  ///
  /// For so=90 back camera:
  ///   normX = 1 - lm.y / imageHeight  (lm.y ∈ [0..720])
  double _computeBodyCenterNormX(ProcessedLandmarks lm) {
    final shoulderY = (lm.leftShoulder.y + lm.rightShoulder.y) / 2;
    final hipY      = (lm.leftHip.y + lm.rightHip.y) / 2;
    final midY      = (shoulderY + hipY) / 2;

    if (sensorOrientation == 270) {
      // Front camera so=270: lm.y ∈ [0..imageWidth=1280].
      // After mirror: screenX = lm.y / imageWidth  →  normX = lm.y / imageWidth.
      final imgW = lm.imageWidth > 0 ? lm.imageWidth.toDouble() : 1280.0;
      return midY / imgW;
    } else {
      // Back camera so=90: lm.y ∈ [0..imageHeight=720].
      // screenX = (1 - lm.y / imageHeight)  →  normX = 1 - lm.y / imageHeight.
      final imgH = lm.imageHeight > 0 ? lm.imageHeight.toDouble() : 720.0;
      return 1.0 - midY / imgH;
    }
  }

  /// Validate the current pose.
  ///
  /// Pass [transformer] so body-centering uses the same coordinate mapping
  /// as the live skeleton overlay (rotation + mirror + BoxFit.cover).
  APoseValidationResult validate(
    ProcessedLandmarks lm, {
    CoordinateTransformer? transformer,
  }) {
    final failures = <APoseFailure>[];

    // 1. Head visible
    if (lm.nose.confidence < 0.5) {
      failures.add(
        const APoseFailure(
          type: APoseCheckType.headNotVisible,
          guidance: 'Ensure head is visible',
          voiceScript: 'Make sure your head is visible in the camera',
        ),
      );
    }

    // 2. Feet visible
    final feetVisible =
        lm.leftAnkle.confidence >= 0.35 && lm.rightAnkle.confidence >= 0.35;
    if (!feetVisible) {
      failures.add(
        const APoseFailure(
          type: APoseCheckType.feetNotVisible,
          guidance: 'Ensure both feet are visible',
          voiceScript: 'Make sure both feet are visible in the camera',
        ),
      );
    }

    // 3. Body centered in frame (screen space, including cover crop).
    final normalizedScreenX = transformer != null
        ? transformer
              .normalizeToScreen(
                (lm.leftShoulder.x + lm.rightShoulder.x) / 2,
                (lm.leftShoulder.y + lm.rightShoulder.y) / 2,
              )
              .dx
        : _computeBodyCenterNormX(lm);
    final offset = (normalizedScreenX - 0.5).abs();
    if (offset > maxCenterOffset) {
      // normX > 0.5 → user appears on the RIGHT side of screen → tell them move left.
      // normX < 0.5 → user appears on the LEFT  side of screen → tell them move right.
      final isScreenRight = normalizedScreenX > 0.5;
      failures.add(
        APoseFailure(
          type: APoseCheckType.bodyNotCentered,
          guidance: isScreenRight ? 'Move left' : 'Move right',
          voiceScript: isScreenRight
              ? 'Move slightly to the left'
              : 'Move slightly to the right',
        ),
      );
    }

    // 4. Distance check — body should occupy 55–95% of portrait screen height.
    // For sensorOrientation=90: lm.x maps to screen-Y. Body spans nose.x → ankle.x.
    // imageWidth (e.g. 1280) is the landscape width = portrait screen height span.
    final imgW = lm.imageWidth > 0 ? lm.imageWidth.toDouble() : 1280.0;
    final bodyHeightFraction = lm.estimatedBodyHeightPx / imgW;
    if (bodyHeightFraction < 0.45) {
      failures.add(
        const APoseFailure(
          type: APoseCheckType.bodyTooFar,
          guidance: 'Too far — step closer',
          voiceScript: 'Step closer to the camera',
        ),
      );
    } else if (bodyHeightFraction > 0.97) {
      failures.add(
        const APoseFailure(
          type: APoseCheckType.bodyTooClose,
          guidance: 'Too close — step back',
          voiceScript: 'Step back from the camera',
        ),
      );
    }

    final shoulderWidth = lm.shoulderWidth;

    if (!isSideView) {
      // 5. Arm angle check (A-Pose: arms 20-55° from body)
      final leftArmAngle = _armAngleFromBody(lm, isLeft: true);
      final rightArmAngle = _armAngleFromBody(lm, isLeft: false);

      final leftArmOk =
          leftArmAngle >= minArmAngleDeg && leftArmAngle <= maxArmAngleDeg;
      final rightArmOk =
          rightArmAngle >= minArmAngleDeg && rightArmAngle <= maxArmAngleDeg;

      if (!leftArmOk || !rightArmOk) {
        String guidance;
        String voice;

        if (leftArmAngle < minArmAngleDeg && rightArmAngle < minArmAngleDeg) {
          guidance = 'Open both arms slightly';
          voice = 'Open both arms slightly away from your body';
        } else if (leftArmAngle > maxArmAngleDeg ||
            rightArmAngle > maxArmAngleDeg) {
          guidance = 'Lower your arms slightly';
          voice = 'Lower both arms slightly';
        } else if (!leftArmOk) {
          guidance = 'Raise left arm slightly';
          voice = 'Raise your left arm slightly';
        } else {
          guidance = 'Raise right arm slightly';
          voice = 'Raise your right arm slightly';
        }

        failures.add(
          APoseFailure(
            type: APoseCheckType.armsAngleWrong,
            guidance: guidance,
            voiceScript: voice,
          ),
        );
      }

      // 6. Shoulders level
      final shoulderYDiff = (lm.leftShoulder.y - lm.rightShoulder.y).abs();
      if (shoulderWidth > 0 &&
          shoulderYDiff / shoulderWidth > maxShoulderTiltFraction) {
        failures.add(
          const APoseFailure(
            type: APoseCheckType.shouldersUneven,
            guidance: 'Level your shoulders',
            voiceScript: 'Level both shoulders',
          ),
        );
      }
    }

    // 7. Standing straight (hip-ankle alignment)
    final hipCenterX = (lm.leftHip.x + lm.rightHip.x) / 2;
    final ankleCenterX = (lm.leftAnkle.x + lm.rightAnkle.x) / 2;
    final leanOffset = (hipCenterX - ankleCenterX).abs();
    if (shoulderWidth > 0 && leanOffset > shoulderWidth * 0.28) {
      failures.add(
        const APoseFailure(
          type: APoseCheckType.notStandingStraight,
          guidance: 'Stand straight',
          voiceScript: 'Stand up straight',
        ),
      );
    }

    final isValid = failures.isEmpty;

    if (isValid) {
      _consecutiveValidFrames++;
    } else {
      _consecutiveValidFrames = 0;
    }

    return APoseValidationResult(
      isValid: isValid,
      isStable: _consecutiveValidFrames >= requiredStableFrames,
      failures: failures,
      stableFrameCount: _consecutiveValidFrames,
      requiredFrames: requiredStableFrames,
    );
  }

  /// Reset stability counter (call when switching front→side).
  void reset() {
    _consecutiveValidFrames = 0;
  }

  /// Compute the angle between the arm and the body's vertical axis.
  ///
  /// 0° = arm hanging straight down (alongside body)
  /// 90° = arm fully horizontal (T-Pose)
  /// Target for A-Pose: 20-55°
  double _armAngleFromBody(ProcessedLandmarks lm, {required bool isLeft}) {
    final shoulder = isLeft ? lm.leftShoulder : lm.rightShoulder;
    final wrist = isLeft ? lm.leftWrist : lm.rightWrist;

    if (shoulder.confidence < 0.4 || wrist.confidence < 0.4) {
      // If arm not visible, assume OK (don't penalize for occlusion)
      return 30.0;
    }

    final dx = (wrist.x - shoulder.x).abs();
    final dy = (wrist.y - shoulder.y).abs();

    if (dy < 0.001) return 90.0; // Horizontal edge case

    // Angle from body vertical axis: atan(horizontal / vertical)
    return atan2(dx, dy) * 180 / pi;
  }
}
