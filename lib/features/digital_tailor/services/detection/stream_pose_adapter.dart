import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/body_landmarks.dart';
import '../../models/processed_landmarks.dart';

/// Result of a single frame pose detection.
class StreamPoseResult {
  final bool hasLandmarks;
  final ProcessedLandmarks? landmarks;
  final List<PoseLandmark> rawLandmarks;

  const StreamPoseResult({
    required this.hasLandmarks,
    this.landmarks,
    this.rawLandmarks = const [],
  });

  factory StreamPoseResult.empty() =>
      const StreamPoseResult(hasLandmarks: false);
}

/// Adapts the camera image stream to ML Kit pose detection.
///
/// THIS IS THE CRITICAL ARCHITECTURAL FIX.
///
/// The previous implementation called takePicture() inside a Timer loop.
/// takePicture() is a still-image capture that takes 200-600ms per frame
/// and blocks the camera controller. Calling it faster than it completes
/// causes: "CameraException: Previous capture has not returned yet."
///
/// The correct approach:
/// 1. Use camera.startImageStream() — provides YUV420 frames continuously
///    without stalling the camera controller.
/// 2. Process one frame at a time (drop frames if ML Kit is busy).
/// 3. For final measurement capture, stop the stream and call takePicture()
///    ONCE at full resolution.
///
/// Rate limiting: ML Kit processes at ~5-10fps on mid-range devices.
/// We skip frames when the detector is busy to avoid memory buildup.
class StreamPoseAdapter {
  PoseDetector? _detector;
  bool _isProcessing = false;
  DateTime? _lastProcessTime;

  /// Minimum time between processed frames (100ms = max 10fps for detection).
  static const Duration _minFrameInterval = Duration(milliseconds: 100);

  /// Initialize the pose detector in stream mode with the base model
  /// (faster, lower memory — suitable for live preview).
  void initialize() {
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  /// Process a single [CameraImage] frame from the image stream.
  ///
  /// Returns null when the frame should be skipped (detector busy or
  /// rate limit not reached). Returns [StreamPoseResult.empty()] when
  /// no pose is detected. Returns a result with landmarks on success.
  Future<StreamPoseResult?> processFrame(
    CameraImage frame,
    CameraDescription camera,
  ) async {
    if (_detector == null) return null;
    if (_isProcessing) return null; // Drop frame — detector busy

    final now = DateTime.now();
    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!) < _minFrameInterval) {
      return null; // Rate limit
    }

    _isProcessing = true;
    _lastProcessTime = now;

    try {
      final inputImage = _toInputImage(frame, camera);
      if (inputImage == null) return StreamPoseResult.empty();

      final poses = await _detector!.processImage(inputImage);

      if (poses.isEmpty) return StreamPoseResult.empty();

      final pose = poses.first;
      final landmarks = _toProcessedLandmarks(pose, frame.width, frame.height);

      return StreamPoseResult(
        hasLandmarks: landmarks != null,
        landmarks: landmarks,
        rawLandmarks: pose.landmarks.values.toList(),
      );
    } catch (_) {
      return StreamPoseResult.empty();
    } finally {
      _isProcessing = false;
    }
  }

  /// Process a full-resolution JPEG for final measurement.
  /// Uses the accurate model for better precision.
  Future<StreamPoseResult> processCapture(Uint8List jpegBytes) async {
    // Use accurate model for final measurement
    final accurateDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.accurate,
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/scan_cap_$ts.jpg');
      await file.writeAsBytes(jpegBytes);

      final inputImage = InputImage.fromFilePath(file.path);
      final poses = await accurateDetector.processImage(inputImage);

      try {
        await file.delete();
      } catch (_) {}

      if (poses.isEmpty) return StreamPoseResult.empty();

      final pose = poses.first;

      // Decode dimensions
      int w = 1080, h = 1920;
      try {
        // Try to parse from JPEG header
        final bd = ByteData.sublistView(Uint8List.fromList(jpegBytes));
        // Quick SOF0 marker scan for JPEG dimensions
        for (int i = 0; i < jpegBytes.length - 9; i++) {
          if (jpegBytes[i] == 0xFF &&
              (jpegBytes[i + 1] == 0xC0 || jpegBytes[i + 1] == 0xC2)) {
            h = bd.getUint16(i + 5);
            w = bd.getUint16(i + 7);
            break;
          }
        }
      } catch (_) {}

      final landmarks = _toProcessedLandmarks(pose, w, h);
      return StreamPoseResult(
        hasLandmarks: landmarks != null,
        landmarks: landmarks,
        rawLandmarks: pose.landmarks.values.toList(),
      );
    } finally {
      accurateDetector.close();
    }
  }

  /// Convert CameraImage (YUV420) to ML Kit InputImage.
  ///
  /// ML Kit accepts YUV_420_888 format directly via InputImageData,
  /// bypassing the need to save to disk for live stream frames.
  InputImage? _toInputImage(CameraImage frame, CameraDescription camera) {
    try {
      final format = InputImageFormatValue.fromRawValue(frame.format.raw);
      if (format == null) return null;

      final rotation = _getRotation(camera.sensorOrientation);

      // For single-plane formats (BGRA8888 on iOS)
      if (frame.planes.length == 1) {
        return InputImage.fromBytes(
          bytes: frame.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(frame.width.toDouble(), frame.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: frame.planes[0].bytesPerRow,
          ),
        );
      }

      // For multi-plane YUV420 (Android)
      final allBytes = _mergeYuvPlanes(frame);
      return InputImage.fromBytes(
        bytes: allBytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: frame.planes[0].bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Merge YUV420 planes into a single byte array for ML Kit.
  Uint8List _mergeYuvPlanes(CameraImage frame) {
    final totalBytes = frame.planes.fold<int>(
      0,
      (sum, plane) => sum + plane.bytes.length,
    );
    final merged = Uint8List(totalBytes);
    int offset = 0;
    for (final plane in frame.planes) {
      merged.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return merged;
  }

  InputImageRotation _getRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation90deg;
    }
  }

  ProcessedLandmarks? _toProcessedLandmarks(Pose pose, int width, int height) {
    LandmarkPoint2D? get(PoseLandmarkType t) {
      final lm = pose.landmarks[t];
      if (lm == null || lm.likelihood < 0.25) return null;
      return LandmarkPoint2D(x: lm.x, y: lm.y, confidence: lm.likelihood);
    }

    final nose = get(PoseLandmarkType.nose);
    final ls = get(PoseLandmarkType.leftShoulder);
    final rs = get(PoseLandmarkType.rightShoulder);
    final le = get(PoseLandmarkType.leftElbow);
    final re = get(PoseLandmarkType.rightElbow);
    final lw = get(PoseLandmarkType.leftWrist);
    final rw = get(PoseLandmarkType.rightWrist);
    final lh = get(PoseLandmarkType.leftHip);
    final rh = get(PoseLandmarkType.rightHip);
    final lk = get(PoseLandmarkType.leftKnee);
    final rk = get(PoseLandmarkType.rightKnee);
    final la = get(PoseLandmarkType.leftAnkle);
    final ra = get(PoseLandmarkType.rightAnkle);

    if (nose == null ||
        ls == null ||
        rs == null ||
        le == null ||
        re == null ||
        lw == null ||
        rw == null ||
        lh == null ||
        rh == null ||
        lk == null ||
        rk == null) {
      return null;
    }

    return ProcessedLandmarks(
      nose: nose,
      leftEar: get(PoseLandmarkType.leftEar) ?? LandmarkPoint2D.zero,
      rightEar: get(PoseLandmarkType.rightEar) ?? LandmarkPoint2D.zero,
      // Eye landmarks improve head-crown estimation accuracy.
      leftEye: get(PoseLandmarkType.leftEye),
      rightEye: get(PoseLandmarkType.rightEye),
      leftShoulder: ls,
      rightShoulder: rs,
      leftElbow: le,
      rightElbow: re,
      leftWrist: lw,
      rightWrist: rw,
      leftHip: lh,
      rightHip: rh,
      leftKnee: lk,
      rightKnee: rk,
      leftAnkle: la ?? LandmarkPoint2D.zero,
      rightAnkle: ra ?? LandmarkPoint2D.zero,
      // Foot landmarks eliminate the ~4-5% systematic calibration error
      // caused by using the ankle joint (6-8 cm above the floor) as the bottom anchor.
      leftHeel: get(PoseLandmarkType.leftHeel),
      rightHeel: get(PoseLandmarkType.rightHeel),
      leftFootIndex: get(PoseLandmarkType.leftFootIndex),
      rightFootIndex: get(PoseLandmarkType.rightFootIndex),
      imageWidth: width,
      imageHeight: height,
    );
  }

  void dispose() {
    _detector?.close();
    _detector = null;
  }
}
