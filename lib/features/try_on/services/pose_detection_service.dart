import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/torso_landmarks.dart';

/// Outcome of running pose detection on a single camera frame.
///
/// [processed] distinguishes a *skipped* frame (detector busy / rate limited)
/// from a *processed* one. When a frame is processed but no usable torso was
/// found, [landmarks] is `null` — the caller should then hide the overlay.
class TorsoDetectionResult {
  /// Whether the frame was actually run through the detector.
  /// `false` means it was dropped (busy or throttled) — ignore it.
  final bool processed;

  /// The extracted torso landmarks, or `null` if no confident torso was found.
  final TorsoLandmarks? landmarks;

  const TorsoDetectionResult._({required this.processed, this.landmarks});

  const TorsoDetectionResult.skipped() : this._(processed: false);
  const TorsoDetectionResult.empty() : this._(processed: true, landmarks: null);
  const TorsoDetectionResult.found(TorsoLandmarks landmarks)
      : this._(processed: true, landmarks: landmarks);
}

/// Lightweight MediaPipe / ML Kit pose detection wrapper for the Virtual
/// Try-On feature.
///
/// Unlike the full body-scanner pipeline, this service only cares about the
/// four torso landmarks (both shoulders + both hips). It runs the detector in
/// **stream mode** with the fast base model and returns coordinates already
/// normalized into upright, preview-mirrored space so the overlay can be
/// painted directly.
///
/// Performance safeguards:
/// * Frames are dropped while a previous frame is still being processed.
/// * A minimum interval is enforced between processed frames.
class PoseDetectionService {
  PoseDetector? _detector;
  bool _isProcessing = false;
  DateTime? _lastProcessTime;

  /// Minimum landmark likelihood for a point to be trusted.
  static const double _minConfidence = 0.5;

  /// Minimum time between processed frames. ~40 ms targets ~25 FPS (within the
  /// 20–30 FPS goal); the busy-drop guard above prevents a backlog when the
  /// detector cannot keep up on slower devices.
  static const Duration _minFrameInterval = Duration(milliseconds: 40);

  bool get isInitialized => _detector != null;

  /// Create the underlying detector. Safe to call more than once.
  void initialize() {
    _detector ??= PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  /// Process a single [frame] from the camera image stream.
  ///
  /// Returns a [TorsoDetectionResult] describing whether the frame was
  /// processed and, if so, the detected torso landmarks.
  Future<TorsoDetectionResult> processFrame(
    CameraImage frame,
    CameraDescription camera,
  ) async {
    final detector = _detector;
    if (detector == null) return const TorsoDetectionResult.skipped();

    // Drop the frame if the detector is still busy — prevents a backlog.
    if (_isProcessing) return const TorsoDetectionResult.skipped();

    final now = DateTime.now();
    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!) < _minFrameInterval) {
      return const TorsoDetectionResult.skipped();
    }

    _isProcessing = true;
    _lastProcessTime = now;

    try {
      final inputImage = _toInputImage(frame, camera);
      if (inputImage == null) return const TorsoDetectionResult.empty();

      final poses = await detector.processImage(inputImage);
      if (poses.isEmpty) return const TorsoDetectionResult.empty();

      final landmarks = _extractTorso(poses.first);
      return landmarks == null
          ? const TorsoDetectionResult.empty()
          : TorsoDetectionResult.found(landmarks);
    } catch (_) {
      // A single failed frame is non-fatal — just skip it.
      return const TorsoDetectionResult.empty();
    } finally {
      _isProcessing = false;
    }
  }

  /// Extract the four torso landmarks as **raw** ML Kit coordinates. Returns
  /// `null` if any of the four points is missing or below the confidence
  /// threshold. Mapping into screen space happens later via the shared
  /// [CoordinateTransformer], so no rotation/mirroring is applied here.
  TorsoLandmarks? _extractTorso(Pose pose) {
    Offset? raw(PoseLandmarkType type) {
      final lm = pose.landmarks[type];
      if (lm == null || lm.likelihood < _minConfidence) return null;
      return Offset(lm.x, lm.y);
    }

    final leftShoulder = raw(PoseLandmarkType.leftShoulder);
    final rightShoulder = raw(PoseLandmarkType.rightShoulder);
    final leftHip = raw(PoseLandmarkType.leftHip);
    final rightHip = raw(PoseLandmarkType.rightHip);

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return null;
    }

    return TorsoLandmarks(
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftHip: leftHip,
      rightHip: rightHip,
    );
  }

  /// Convert a [CameraImage] into an ML Kit [InputImage].
  InputImage? _toInputImage(CameraImage frame, CameraDescription camera) {
    final format = InputImageFormatValue.fromRawValue(frame.format.raw);
    if (format == null) return null;

    final rotation = _rotationFromSensor(camera.sensorOrientation);
    final metadata = InputImageMetadata(
      size: Size(frame.width.toDouble(), frame.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: frame.planes.first.bytesPerRow,
    );

    // Single-plane formats (e.g. BGRA8888 on iOS) can be passed directly.
    if (frame.planes.length == 1) {
      return InputImage.fromBytes(
        bytes: frame.planes.first.bytes,
        metadata: metadata,
      );
    }

    // Multi-plane YUV420 (Android): concatenate planes into one buffer.
    return InputImage.fromBytes(
      bytes: _mergePlanes(frame),
      metadata: metadata,
    );
  }

  Uint8List _mergePlanes(CameraImage frame) {
    final total =
        frame.planes.fold<int>(0, (sum, p) => sum + p.bytes.length);
    final merged = Uint8List(total);
    var offset = 0;
    for (final plane in frame.planes) {
      merged.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return merged;
  }

  InputImageRotation _rotationFromSensor(int sensorOrientation) {
    return switch (sensorOrientation) {
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => InputImageRotation.rotation0deg,
    };
  }

  /// Release the detector. Must be called from the owner's `dispose()`.
  void dispose() {
    _detector?.close();
    _detector = null;
    _isProcessing = false;
    _lastProcessTime = null;
  }
}
