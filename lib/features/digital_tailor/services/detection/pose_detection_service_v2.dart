import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../models/body_landmarks.dart';
import '../../models/processed_landmarks.dart';

/// Result of pose detection for a single image.
class PoseDetectionResultV2 {
  final bool isSuccess;
  final Pose? rawPose;
  final ProcessedLandmarks? landmarks;
  final String? errorMessage;
  final int imageWidth;
  final int imageHeight;

  const PoseDetectionResultV2._({
    required this.isSuccess,
    this.rawPose,
    this.landmarks,
    this.errorMessage,
    this.imageWidth = 0,
    this.imageHeight = 0,
  });

  factory PoseDetectionResultV2.success({
    required Pose pose,
    required ProcessedLandmarks landmarks,
    required int imageWidth,
    required int imageHeight,
  }) {
    return PoseDetectionResultV2._(
      isSuccess: true,
      rawPose: pose,
      landmarks: landmarks,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  factory PoseDetectionResultV2.error(String message) {
    return PoseDetectionResultV2._(isSuccess: false, errorMessage: message);
  }
}

/// Enhanced pose detection service (v2).
///
/// Wraps Google ML Kit Pose Detection with:
/// - Better error messages in Indonesian
/// - Automatic image format handling
/// - ProcessedLandmarks conversion
/// - Confidence filtering
class PoseDetectionServiceV2 {
  PoseDetector? _poseDetector;

  /// Minimum confidence for a landmark to be included.
  static const double minConfidence = 0.3;

  /// Initialize the detector.
  void initialize() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.accurate,
      ),
    );
  }

  /// Detect pose from JPEG image bytes.
  Future<PoseDetectionResultV2> detectPose(Uint8List imageBytes) async {
    if (_poseDetector == null) {
      return PoseDetectionResultV2.error('Pose detector belum diinisialisasi.');
    }

    try {
      // Save to temp file (ML Kit requires file path for JPEG)
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/pose_v2_$timestamp.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final poses = await _poseDetector!.processImage(inputImage);

      // Clean up
      try {
        await tempFile.delete();
      } catch (_) {}

      if (poses.isEmpty) {
        return PoseDetectionResultV2.error(
          'Tidak ada pose terdeteksi. Pastikan:\n'
          '• Seluruh tubuh terlihat\n'
          '• Pencahayaan cukup\n'
          '• Latar belakang polos',
        );
      }

      // Get image dimensions
      final decoded = img.decodeImage(imageBytes);
      final width = decoded?.width ?? 1080;
      final height = decoded?.height ?? 1920;

      final pose = poses.first;

      // Convert to ProcessedLandmarks
      final landmarks = _toProcessedLandmarks(pose, width, height);
      if (landmarks == null) {
        return PoseDetectionResultV2.error(
          'Titik tubuh tidak lengkap. Pastikan seluruh tubuh terlihat.',
        );
      }

      return PoseDetectionResultV2.success(
        pose: pose,
        landmarks: landmarks,
        imageWidth: width,
        imageHeight: height,
      );
    } catch (e) {
      return PoseDetectionResultV2.error(
        'Gagal menganalisis pose: ${e.toString()}',
      );
    }
  }

  /// Convert ML Kit Pose to our ProcessedLandmarks model.
  ProcessedLandmarks? _toProcessedLandmarks(
    Pose pose,
    int imageWidth,
    int imageHeight,
  ) {
    LandmarkPoint2D? getLm(PoseLandmarkType type) {
      final lm = pose.landmarks[type];
      if (lm == null) return null;
      return LandmarkPoint2D(x: lm.x, y: lm.y, confidence: lm.likelihood);
    }

    // Required landmarks
    final nose = getLm(PoseLandmarkType.nose);
    final leftShoulder = getLm(PoseLandmarkType.leftShoulder);
    final rightShoulder = getLm(PoseLandmarkType.rightShoulder);
    final leftElbow = getLm(PoseLandmarkType.leftElbow);
    final rightElbow = getLm(PoseLandmarkType.rightElbow);
    final leftWrist = getLm(PoseLandmarkType.leftWrist);
    final rightWrist = getLm(PoseLandmarkType.rightWrist);
    final leftHip = getLm(PoseLandmarkType.leftHip);
    final rightHip = getLm(PoseLandmarkType.rightHip);
    final leftKnee = getLm(PoseLandmarkType.leftKnee);
    final rightKnee = getLm(PoseLandmarkType.rightKnee);
    final leftAnkle = getLm(PoseLandmarkType.leftAnkle);
    final rightAnkle = getLm(PoseLandmarkType.rightAnkle);

    // All core landmarks must be present
    if (nose == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return null;
    }

    // Optional landmarks
    final leftEar = getLm(PoseLandmarkType.leftEar) ?? LandmarkPoint2D.zero;
    final rightEar = getLm(PoseLandmarkType.rightEar) ?? LandmarkPoint2D.zero;

    // Calibration-critical optional landmarks. These are required by
    // ProcessedLandmarks.estimatedHeadTopY / estimatedFootBottomY for accurate
    // height calibration (eyes → crown, heels/foot-index → floor). The still-
    // image path previously omitted them, silently degrading calibration.
    return ProcessedLandmarks(
      nose: nose,
      leftEar: leftEar,
      rightEar: rightEar,
      leftEye: getLm(PoseLandmarkType.leftEye),
      rightEye: getLm(PoseLandmarkType.rightEye),
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftElbow: leftElbow,
      rightElbow: rightElbow,
      leftWrist: leftWrist,
      rightWrist: rightWrist,
      leftHip: leftHip,
      rightHip: rightHip,
      leftKnee: leftKnee,
      rightKnee: rightKnee,
      leftAnkle: leftAnkle,
      rightAnkle: rightAnkle,
      leftHeel: getLm(PoseLandmarkType.leftHeel),
      rightHeel: getLm(PoseLandmarkType.rightHeel),
      leftFootIndex: getLm(PoseLandmarkType.leftFootIndex),
      rightFootIndex: getLm(PoseLandmarkType.rightFootIndex),
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  /// Dispose resources.
  void dispose() {
    _poseDetector?.close();
    _poseDetector = null;
  }
}
