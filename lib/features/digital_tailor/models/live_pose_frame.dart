import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../services/detection/coordinate_transformer.dart';
import '../services/pipeline/a_pose_validator.dart';
import '../services/pipeline/scan_quality_evaluator.dart';
import 'processed_landmarks.dart';

/// Fully processed live pose frame used by the scan workflow.
class LivePoseFrame {
  final List<PoseLandmark> rawLandmarks;
  final ProcessedLandmarks? landmarks;
  final APoseValidationResult? validation;
  final ScanQualityMetrics quality;
  final CoordinateTransformer transformer;
  final double landmarkJitter;
  final double? shoulderCenterNormX;

  const LivePoseFrame({
    required this.rawLandmarks,
    required this.landmarks,
    required this.validation,
    required this.quality,
    required this.transformer,
    required this.landmarkJitter,
    required this.shoulderCenterNormX,
  });

  bool get hasLandmarks => landmarks != null;
}
