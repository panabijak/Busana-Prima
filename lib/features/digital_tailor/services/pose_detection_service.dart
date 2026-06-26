import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Service for detecting pose landmarks from captured images.
///
/// IMPORTANT: ML Kit requires either a file path or properly formatted raw bytes.
/// Camera's takePicture() returns JPEG — we must use InputImage.fromFilePath()
/// or save to a temp file first.
class PoseDetectionService {
  PoseDetector? _poseDetector;

  /// Required landmarks for full measurement calculation
  static const List<PoseLandmarkType> requiredLandmarks = [
    PoseLandmarkType.nose,
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftElbow,
    PoseLandmarkType.rightElbow,
    PoseLandmarkType.leftWrist,
    PoseLandmarkType.rightWrist,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle,
  ];

  /// Minimum confidence threshold for a landmark to be considered valid
  static const double minConfidence = 0.3;

  /// Minimum number of required landmarks that must be detected
  /// to proceed with measurement (allow partial results)
  static const int minRequiredLandmarks = 8;

  /// Initialize the pose detector
  void initialize() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.accurate,
      ),
    );
  }

  /// Detect pose from image bytes (JPEG from camera).
  ///
  /// The key fix: Camera takePicture() returns JPEG data.
  /// ML Kit's fromBytes() expects raw pixel data (NV21/YUV420).
  /// We must save to a temp file and use InputImage.fromFilePath() instead.
  Future<PoseDetectionResult> detectPose(Uint8List imageBytes) async {
    if (_poseDetector == null) {
      return PoseDetectionResult.error(
        'Pose detector belum diinisialisasi. Silakan mulai ulang proses scanning.',
      );
    }

    try {
      // Save JPEG bytes to a temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/pose_scan_$timestamp.jpg');
      await tempFile.writeAsBytes(imageBytes);

      // Use InputImage.fromFilePath() which handles JPEG correctly
      final inputImage = InputImage.fromFilePath(tempFile.path);

      // Process the image
      final poses = await _poseDetector!.processImage(inputImage);

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (_) {
        // Ignore cleanup errors
      }

      if (poses.isEmpty) {
        return PoseDetectionResult.error(
          'Tidak ada pose terdeteksi. Pastikan:\n'
          '• Seluruh tubuh terlihat dalam foto\n'
          '• Pencahayaan cukup terang\n'
          '• Latar belakang tidak terlalu ramai',
        );
      }

      final pose = poses.first;

      // Get image dimensions using the image package
      final decodedImage = img.decodeImage(imageBytes);
      final imageWidth = decodedImage?.width ?? 1080;
      final imageHeight = decodedImage?.height ?? 1920;

      // Check which required landmarks are detected
      final missingLandmarks = <PoseLandmarkType>[];
      int detectedCount = 0;

      for (final type in requiredLandmarks) {
        final landmark = pose.landmarks[type];
        if (landmark == null || landmark.likelihood < minConfidence) {
          missingLandmarks.add(type);
        } else {
          detectedCount++;
        }
      }

      // If we have enough landmarks, consider it a success
      // (allow partial detection to proceed with available measurements)
      if (detectedCount >= minRequiredLandmarks) {
        return PoseDetectionResult.success(
          pose: pose,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          detectedLandmarkCount: detectedCount,
          totalRequiredLandmarks: requiredLandmarks.length,
        );
      }

      // Too few landmarks detected
      if (detectedCount > 0) {
        return PoseDetectionResult.partialDetection(
          pose: pose,
          missingLandmarks: missingLandmarks,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          detectedCount: detectedCount,
        );
      }

      return PoseDetectionResult.error(
        'Gagal mendeteksi titik tubuh. Pastikan:\n'
        '• Seluruh tubuh dari kepala hingga kaki terlihat\n'
        '• Berdiri tegak dengan tangan di samping\n'
        '• Pencahayaan cukup dan latar belakang polos',
      );
    } catch (e) {
      return PoseDetectionResult.error(
        'Gagal menganalisis pose: ${e.toString()}',
      );
    }
  }

  /// Detect pose from a file path directly (alternative method)
  Future<PoseDetectionResult> detectPoseFromFile(String filePath) async {
    if (_poseDetector == null) {
      return PoseDetectionResult.error('Pose detector belum diinisialisasi.');
    }

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isEmpty) {
        return PoseDetectionResult.error(
          'Tidak ada pose terdeteksi dari file.',
        );
      }

      final pose = poses.first;
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      final imageWidth = decodedImage?.width ?? 1080;
      final imageHeight = decodedImage?.height ?? 1920;

      int detectedCount = 0;
      final missingLandmarks = <PoseLandmarkType>[];

      for (final type in requiredLandmarks) {
        final landmark = pose.landmarks[type];
        if (landmark == null || landmark.likelihood < minConfidence) {
          missingLandmarks.add(type);
        } else {
          detectedCount++;
        }
      }

      if (detectedCount >= minRequiredLandmarks) {
        return PoseDetectionResult.success(
          pose: pose,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          detectedLandmarkCount: detectedCount,
          totalRequiredLandmarks: requiredLandmarks.length,
        );
      }

      return PoseDetectionResult.partialDetection(
        pose: pose,
        missingLandmarks: missingLandmarks,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        detectedCount: detectedCount,
      );
    } catch (e) {
      return PoseDetectionResult.error(
        'Gagal menganalisis pose dari file: ${e.toString()}',
      );
    }
  }

  /// Dispose the pose detector
  void dispose() {
    _poseDetector?.close();
    _poseDetector = null;
  }
}

/// Result of pose detection processing
class PoseDetectionResult {
  final bool isSuccess;
  final Pose? pose;
  final String? errorMessage;
  final List<PoseLandmarkType>? missingLandmarks;
  final int? imageWidth;
  final int? imageHeight;
  final int? detectedLandmarkCount;
  final int? totalRequiredLandmarks;

  const PoseDetectionResult._({
    required this.isSuccess,
    this.pose,
    this.errorMessage,
    this.missingLandmarks,
    this.imageWidth,
    this.imageHeight,
    this.detectedLandmarkCount,
    this.totalRequiredLandmarks,
  });

  factory PoseDetectionResult.success({
    required Pose pose,
    required int imageWidth,
    required int imageHeight,
    int? detectedLandmarkCount,
    int? totalRequiredLandmarks,
  }) {
    return PoseDetectionResult._(
      isSuccess: true,
      pose: pose,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      detectedLandmarkCount: detectedLandmarkCount,
      totalRequiredLandmarks: totalRequiredLandmarks,
    );
  }

  factory PoseDetectionResult.error(String message) {
    return PoseDetectionResult._(isSuccess: false, errorMessage: message);
  }

  factory PoseDetectionResult.partialDetection({
    required Pose pose,
    required List<PoseLandmarkType> missingLandmarks,
    required int imageWidth,
    required int imageHeight,
    required int detectedCount,
  }) {
    return PoseDetectionResult._(
      isSuccess: false,
      pose: pose,
      missingLandmarks: missingLandmarks,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      detectedLandmarkCount: detectedCount,
      totalRequiredLandmarks: PoseDetectionService.requiredLandmarks.length,
      errorMessage:
          'Hanya $detectedCount dari ${PoseDetectionService.requiredLandmarks.length} titik tubuh terdeteksi.\n'
          'Pastikan pencahayaan cukup dan seluruh tubuh terlihat jelas.',
    );
  }

  bool get hasPartialDetection => pose != null && missingLandmarks != null;
}
