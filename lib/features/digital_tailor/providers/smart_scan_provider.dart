import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/processed_landmarks.dart';
import '../models/scan_view_mode.dart';
import '../models/scan_workflow_state.dart';
import '../services/detection/pose_engine.dart';
import '../services/pipeline/pose_lock_engine.dart';
import '../services/pipeline/scan_quality_evaluator.dart';
import '../services/voice/voice_guidance_service.dart';

/// State for the Smart Guided Scan live stream.
class SmartScanState {
  /// Whether current pose passes A-Pose validation.
  final bool isPoseValid;

  /// Whether pose has been stable long enough to trigger capture.
  final bool isPoseLocked;

  /// Stability progress toward lock (0.0–1.0).
  final double stabilityProgress;

  /// Primary guidance message to show user.
  final String? primaryGuidance;

  /// Raw ML Kit landmarks for skeleton overlay rendering.
  final List<PoseLandmark> rawLandmarks;

  /// Current quality metrics.
  final ScanQualityMetrics? quality;

  /// Last processed landmarks (smoothed).
  final ProcessedLandmarks? landmarks;

  /// Explicit production scan state.
  final ScanWorkflowState workflowState;

  /// Lock confidence accumulated with hysteresis.
  final double lockConfidence;

  /// Average landmark jitter in image pixels.
  final double landmarkJitter;

  /// Approximate processed-frame FPS.
  final double fps;

  /// Last pose frame processing time.
  final int frameProcessingTimeMs;

  /// Screen-space shoulder midpoint X, normalized [0,1].
  /// 0 = left edge, 0.5 = center, 1 = right edge.
  /// Used for left/right guidance — computed in screen space after transform.
  final double? shoulderCenterNormX;

  const SmartScanState({
    this.isPoseValid = false,
    this.isPoseLocked = false,
    this.stabilityProgress = 0.0,
    this.primaryGuidance,
    this.rawLandmarks = const [],
    this.quality,
    this.landmarks,
    this.workflowState = ScanWorkflowState.searching,
    this.lockConfidence = 0.0,
    this.landmarkJitter = 0.0,
    this.fps = 0.0,
    this.frameProcessingTimeMs = 0,
    this.shoulderCenterNormX,
  });

  SmartScanState copyWith({
    bool? isPoseValid,
    bool? isPoseLocked,
    double? stabilityProgress,
    String? primaryGuidance,
    List<PoseLandmark>? rawLandmarks,
    ScanQualityMetrics? quality,
    ProcessedLandmarks? landmarks,
    ScanWorkflowState? workflowState,
    double? lockConfidence,
    double? landmarkJitter,
    double? fps,
    int? frameProcessingTimeMs,
    double? shoulderCenterNormX,
    bool clearGuidance = false,
  }) {
    return SmartScanState(
      isPoseValid: isPoseValid ?? this.isPoseValid,
      isPoseLocked: isPoseLocked ?? this.isPoseLocked,
      stabilityProgress: stabilityProgress ?? this.stabilityProgress,
      primaryGuidance: clearGuidance
          ? null
          : (primaryGuidance ?? this.primaryGuidance),
      rawLandmarks: rawLandmarks ?? this.rawLandmarks,
      quality: quality ?? this.quality,
      landmarks: landmarks ?? this.landmarks,
      workflowState: workflowState ?? this.workflowState,
      lockConfidence: lockConfidence ?? this.lockConfidence,
      landmarkJitter: landmarkJitter ?? this.landmarkJitter,
      fps: fps ?? this.fps,
      frameProcessingTimeMs: frameProcessingTimeMs ?? this.frameProcessingTimeMs,
      shoulderCenterNormX: shoulderCenterNormX ?? this.shoulderCenterNormX,
    );
  }
}

/// Provider for the live scan stream state.
final smartScanProvider =
    StateNotifierProvider.autoDispose<SmartScanNotifier, SmartScanState>((ref) {
      final notifier = SmartScanNotifier();
      ref.onDispose(() => notifier.dispose());
      return notifier;
    });

/// Notifier that owns the live image stream processing loop.
///
/// KEY DESIGN:
/// processFrame() is called by camera.startImageStream() callback.
/// Each frame is processed asynchronously without blocking the stream.
/// ML Kit processes at ~10fps; extra frames are dropped when busy.
class SmartScanNotifier extends StateNotifier<SmartScanState> {
  final PoseEngine _poseEngine = PoseEngine();
  final PoseLockEngine _lockEngine = PoseLockEngine();
  final VoiceGuidanceService _voice = VoiceGuidanceService();

  bool _isProcessing = false;
  String? _lastVoiceMsg;
  DateTime? _lastVoiceTime;
  DateTime? _lastProcessedFrameAt;

  SmartScanNotifier() : super(const SmartScanState()) {
    _poseEngine.initialize();
    _voice.initialize();
  }

  /// Called from camera.startImageStream() for every camera frame.
  /// Drops frames when the detector is already busy.
  /// [widgetSize] and [imageSize] are needed for screen-space centering.
  void processFrame(
    CameraImage frame,
    CameraDescription camera, {
    Size widgetSize = const Size(412, 917),
    Size imageSize = const Size(1280, 720),
    ScanViewMode viewMode = ScanViewMode.front,
  }) {
    if (_isProcessing ||
        state.workflowState == ScanWorkflowState.capturing ||
        state.workflowState == ScanWorkflowState.processing ||
        state.workflowState == ScanWorkflowState.completed) {
      return;
    }
    _isProcessing = true;

    _processFrameAsync(
      frame,
      camera,
      widgetSize: widgetSize,
      imageSize: imageSize,
      viewMode: viewMode,
    ).whenComplete(() {
      _isProcessing = false;
    });
  }

  Future<void> _processFrameAsync(
    CameraImage frame,
    CameraDescription camera, {
    required Size widgetSize,
    required Size imageSize,
    required ScanViewMode viewMode,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final poseFrame = await _poseEngine.processFrame(
        frame,
        camera,
        widgetSize: widgetSize,
        imageSize: imageSize,
        viewMode: viewMode,
      );
      if (poseFrame == null) return; // Frame skipped (rate limited)

      final fps = _calculateFps();

      // Update skeleton overlay immediately even if pose is incomplete
      if (poseFrame.rawLandmarks.isNotEmpty) {
        state = state.copyWith(rawLandmarks: poseFrame.rawLandmarks);
      }

      if (!poseFrame.hasLandmarks || poseFrame.landmarks == null) {
        final lock = _lockEngine.update(
          validation: null,
          quality: poseFrame.quality,
          landmarkJitter: poseFrame.landmarkJitter,
          hasLandmarks: false,
        );
        state = state.copyWith(
          isPoseValid: false,
          isPoseLocked: false,
          stabilityProgress: lock.confidence,
          primaryGuidance: lock.guidance,
          quality: poseFrame.quality,
          workflowState: lock.state,
          lockConfidence: lock.confidence,
          landmarkJitter: lock.jitter,
          fps: fps,
          frameProcessingTimeMs: stopwatch.elapsedMilliseconds,
        );
        _poseEngine.reset();
        _speakIfNew('Make sure your full body is visible in the camera');
        return;
      }

      final lm = poseFrame.landmarks!;
      final validation = poseFrame.validation!;

      final lock = _lockEngine.update(
        validation: validation,
        quality: poseFrame.quality,
        landmarkJitter: poseFrame.landmarkJitter,
        hasLandmarks: true,
      );

      // Voice guidance
      final failure = validation.primaryFailure;
      if (lock.justLocked) {
        _speakIfNew('Perfect. Hold still.', force: true);
      } else if (failure != null &&
          lock.state != ScanWorkflowState.locked &&
          lock.state != ScanWorkflowState.countdown) {
        _speakIfNew(failure.voiceScript);
      } else if (validation.isValid && !state.isPoseValid) {
        _speakIfNew(GuidanceMessages.poseGood);
      }

      final currentWorkflow = state.workflowState;
      final workflowState =
          (currentWorkflow == ScanWorkflowState.countdown && !lock.hardReset)
          ? ScanWorkflowState.countdown
          : lock.state;
      final isLocked =
          workflowState == ScanWorkflowState.locked ||
          workflowState == ScanWorkflowState.countdown;

      state = state.copyWith(
        isPoseValid: validation.isValid || lock.confidence >= 0.45,
        isPoseLocked: isLocked,
        stabilityProgress: lock.confidence,
        primaryGuidance: workflowState == ScanWorkflowState.countdown
            ? 'Hold still'
            : lock.guidance,
        quality: poseFrame.quality,
        landmarks: lm,
        workflowState: workflowState,
        lockConfidence: lock.confidence,
        landmarkJitter: lock.jitter,
        fps: fps,
        frameProcessingTimeMs: stopwatch.elapsedMilliseconds,
        shoulderCenterNormX: poseFrame.shoulderCenterNormX,
        clearGuidance: validation.isValid && failure == null,
      );
    } catch (_) {
      // Non-fatal: silently skip bad frames
    }
  }

  void beginCountdown() {
    _lockEngine.forceState(ScanWorkflowState.countdown);
    state = state.copyWith(
      workflowState: ScanWorkflowState.countdown,
      isPoseLocked: true,
      primaryGuidance: 'Ready to capture',
    );
    _speakIfNew('Ready to capture.', force: true);
  }

  void announceCountdownTick(int secondsRemaining) {
    switch (secondsRemaining) {
      case 3:
        _speakIfNew(GuidanceMessages.countThree, force: true);
      case 2:
        _speakIfNew(GuidanceMessages.countTwo, force: true);
      case 1:
        _speakIfNew(GuidanceMessages.countOne, force: true);
    }
  }

  void beginCapturing() {
    _lockEngine.forceState(ScanWorkflowState.capturing);
    state = state.copyWith(workflowState: ScanWorkflowState.capturing);
  }

  void beginProcessing() {
    _lockEngine.forceState(ScanWorkflowState.processing);
    state = state.copyWith(workflowState: ScanWorkflowState.processing);
  }

  void complete() {
    _lockEngine.forceState(ScanWorkflowState.completed);
    state = state.copyWith(workflowState: ScanWorkflowState.completed);
  }

  /// Reset for side capture phase.
  void resetForSide() {
    _poseEngine.reset();
    _lockEngine.reset();
    _lastVoiceMsg = null;
    state = const SmartScanState();
    _speakIfNew(GuidanceMessages.frontCaptured, force: true);
  }

  /// Full reset (restart scan).
  void reset() {
    _poseEngine.reset();
    _lockEngine.reset();
    _lastVoiceMsg = null;
    state = const SmartScanState();
  }

  double _calculateFps() {
    final now = DateTime.now();
    final previous = _lastProcessedFrameAt;
    _lastProcessedFrameAt = now;
    if (previous == null) return 0.0;
    final ms = now.difference(previous).inMilliseconds;
    if (ms <= 0) return 0.0;
    return 1000.0 / ms;
  }

  void _speakIfNew(String message, {bool force = false}) {
    final now = DateTime.now();
    final tooSoon =
        _lastVoiceTime != null && now.difference(_lastVoiceTime!).inSeconds < 3;

    if (!force && _lastVoiceMsg == message && tooSoon) return;

    _lastVoiceMsg = message;
    _lastVoiceTime = now;
    _voice.speak(message, force: force);
  }

  @override
  void dispose() {
    _poseEngine.dispose();
    _voice.dispose();
    super.dispose();
  }
}
