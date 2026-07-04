import '../../models/calibration_result.dart';
import 'calibration_engine.dart';

/// Calibration using user-provided height (landmark-based body height estimate).
///
/// This is the fallback strategy when segmentation is unavailable or fails.
/// It uses [ProcessedLandmarks.estimatedBodyHeightPx] which now uses:
///   - Heel/foot-index landmarks for the bottom anchor (more accurate than ankle)
///   - Eye landmarks for the head-crown estimate (more accurate than 12% heuristic)
///
/// The resulting confidence is dynamic: it reflects how accurately we can
/// estimate the two calibration anchors (crown and foot sole) from the available
/// landmark set, so the ConfidenceScorer can weight these measurements correctly.
class HeightCalibrator extends CalibrationStrategy {
  @override
  int get priority => 4; // Fallback (SegmentationCalibrator has priority 2)

  @override
  String get methodName => 'landmark_height';

  @override
  bool isAvailable(CalibrationInput input) {
    return input.userHeightCm != null &&
        input.userHeightCm! >= 80 &&
        input.userHeightCm! <= 230 &&
        input.detectedBodyHeightPx != null &&
        input.detectedBodyHeightPx! > 80;
  }

  @override
  Future<CalibrationResult?> calibrate(CalibrationInput input) async {
    final userHeight = input.userHeightCm!;
    final bodyHeightPx = input.detectedBodyHeightPx!;

    if (bodyHeightPx <= 0) return null;

    final pixelToCm = userHeight / bodyHeightPx;

    // Sanity check: pixel-to-cm should be physically reasonable.
    // 0.02 = very large body in a huge image; 0.5 = tiny body in a small image.
    if (pixelToCm < 0.02 || pixelToCm > 0.5) return null;

    // Dynamic confidence based on which landmarks contributed to the estimate.
    //   0.55 — only ankle + nose heuristic (worst case)
    //   0.65 — ankle + heels (better foot anchor)
    //   0.70 — ankle + heels + foot-index (best foot anchor)
    //   0.80 — heels + eyes (both anchors improved)
    final lmQuality = input.landmarkCalibrationQuality ?? 0.50;
    // Map lmQuality [0.5 → 1.0] to confidence [0.55 → 0.80]
    final confidence = (0.55 + (lmQuality - 0.50) * 0.50).clamp(0.55, 0.80);

    return CalibrationResult(
      pixelToCm: pixelToCm,
      method: methodName,
      confidence: confidence,
      sourceLengthCm: userHeight,
      detectedLengthPx: bodyHeightPx,
    );
  }
}
