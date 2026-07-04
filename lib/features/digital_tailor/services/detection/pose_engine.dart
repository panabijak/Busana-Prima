import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../../models/live_pose_frame.dart';
import '../../models/scan_view_mode.dart';
import '../filtering/landmark_smoother.dart';
import '../pipeline/a_pose_validator.dart';
import '../pipeline/scan_quality_evaluator.dart';
import 'coordinate_transformer.dart';
import 'stream_pose_adapter.dart';

/// Live pose processing engine.
///
/// Owns the CV-side frame pipeline:
/// camera image → pose detection → coordinate transformer → smoothing →
/// validation → quality metrics.
class PoseEngine {
  final StreamPoseAdapter _adapter = StreamPoseAdapter();
  final LandmarkSmoother _smoother = LandmarkSmoother();
  final ScanQualityEvaluator _qualityEvaluator = ScanQualityEvaluator();

  APoseValidator _validator = APoseValidator();
  CameraDescription? _currentCamera;
  ScanViewMode _currentViewMode = ScanViewMode.front;

  double get landmarkJitter => _smoother.lastJitter;

  void initialize() {
    _adapter.initialize();
  }

  Future<LivePoseFrame?> processFrame(
    CameraImage frame,
    CameraDescription camera, {
    required Size widgetSize,
    required Size imageSize,
    ScanViewMode viewMode = ScanViewMode.front,
  }) async {
    _resetTrackingIfCameraChanged(camera, viewMode);

    final result = await _adapter.processFrame(frame, camera);
    if (result == null) return null;

    final transformer = CoordinateTransformer(
      camera: camera,
      imageSize: imageSize,
      widgetSize: widgetSize,
    );

    final baseQuality = _qualityEvaluator.evaluate(
      frame: frame,
      landmarks: result.landmarks,
      poseValidation: null,
    );

    if (!result.hasLandmarks || result.landmarks == null) {
      return LivePoseFrame(
        rawLandmarks: result.rawLandmarks,
        landmarks: null,
        validation: null,
        quality: baseQuality,
        transformer: transformer,
        landmarkJitter: _smoother.lastJitter,
        shoulderCenterNormX: null,
      );
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch / 1000000.0;
    final smoothed = _smoother.smooth(result.landmarks!, timestamp);
    final validation = _validator.validate(smoothed, transformer: transformer);
    final quality = _qualityEvaluator.evaluate(
      frame: frame,
      landmarks: smoothed,
      poseValidation: validation,
    );

    final shoulderCenterNormX = transformer
        .normalizeToScreen(
          (smoothed.leftShoulder.x + smoothed.rightShoulder.x) / 2,
          (smoothed.leftShoulder.y + smoothed.rightShoulder.y) / 2,
        )
        .dx;

    return LivePoseFrame(
      rawLandmarks: result.rawLandmarks,
      landmarks: smoothed,
      validation: validation,
      quality: quality,
      transformer: transformer,
      landmarkJitter: _smoother.lastJitter,
      shoulderCenterNormX: shoulderCenterNormX,
    );
  }

  void reset() {
    _validator.reset();
    _smoother.reset();
  }

  void dispose() {
    _adapter.dispose();
  }

  void _resetTrackingIfCameraChanged(
    CameraDescription camera,
    ScanViewMode viewMode,
  ) {
    if (_currentCamera?.sensorOrientation == camera.sensorOrientation &&
        _currentCamera?.lensDirection == camera.lensDirection &&
        _currentViewMode == viewMode) {
      return;
    }

    _currentCamera = camera;
    _currentViewMode = viewMode;
    _validator = APoseValidator(
      sensorOrientation: camera.sensorOrientation,
      isSideView: viewMode == ScanViewMode.side,
    );
    _smoother.reset();
  }
}
