import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../config/measurement_debug_flags.dart';
import '../models/scan_session.dart';
import '../models/scan_view_mode.dart';
import '../models/scan_workflow_state.dart';
import '../providers/digital_tailor_provider.dart';
import '../providers/smart_scan_provider.dart';
import '../services/camera/scan_camera_controller.dart';
import '../services/capture/scan_capture_controller.dart';
import '../services/leveling_service.dart';
import '../widgets/measurement_debug_panel.dart';
import '../widgets/leveling_indicator.dart';
import '../widgets/pose_debug_overlay.dart';
import '../widgets/quality_indicator_panel.dart';
import '../widgets/scan_countdown.dart';
import '../widgets/skeleton_overlay.dart';

/// Smart Guided Scan Screen — production-quality body scanning experience.
///
/// Architecture fix: Uses camera.startImageStream() for continuous pose
/// detection — NOT takePicture() in a loop (which caused CameraException).
/// takePicture() is called ONCE per scan phase after pose is locked.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  static const bool _debugScanOverlay = bool.fromEnvironment(
    'SCAN_DEBUG',
    defaultValue: false,
  );

  final ScanCameraController _scanCamera = ScanCameraController();
  final ScanCaptureController _captureController = ScanCaptureController();
  LevelingService? _levelingService;
  StreamSubscription<LevelingState>? _levelingSub;

  bool _cameraReady = false;
  bool _isCapturing = false;
  bool _showCountdown = false;
  bool _hasAccelerometer = true;
  bool _isLevel = false;
  double _tiltAngle = 0.0;
  String? _cameraError;
  Size _frameSize = const Size(1280, 720); // sensor-space frame size
  Size _overlaySize = Size.zero; // LayoutBuilder constraints for overlay mapping
  CameraDescription? _activeCamera; // current camera description

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _initLeveling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _levelingSub?.cancel();
    _levelingService?.dispose();
    unawaited(_scanCamera.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      unawaited(_stopStream());
    } else if (state == AppLifecycleState.resumed &&
        _scanCamera.controller != null) {
      _initCamera();
    }
  }

  // ─── Camera Setup ──────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      if (mounted) setState(() => _cameraReady = false);
      await _scanCamera.initialize(frontCamera: _scanCamera.isFrontCamera);
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _cameraError = null;
        _activeCamera = _scanCamera.activeCamera;
      });
      await _startStream();
    } on CameraException catch (e) {
      setState(() => _cameraError = 'Camera access required: ${e.description}');
    } catch (e) {
      setState(() => _cameraError = 'Failed to start camera: $e');
    }
  }

  Future<void> _startStream() async {
    final notifier = ref.read(smartScanProvider.notifier);

    await _scanCamera.startStream((frame, desc) {
      // Capture actual sensor frame size from first frame
      if (_frameSize.width != frame.width.toDouble()) {
        if (mounted) {
          setState(() {
            _frameSize = Size(frame.width.toDouble(), frame.height.toDouble());
          });
        }
      }
      notifier.processFrame(
        frame,
        desc,
        widgetSize: _overlaySize,
        imageSize: _frameSize,
        viewMode:
            ref.read(digitalTailorProvider).session.currentStep ==
                ScanStep.sideCapture
            ? ScanViewMode.side
            : ScanViewMode.front,
      );
    });
  }

  Future<void> _stopStream() => _scanCamera.stopStream();

  Future<void> _switchCamera() async {
    if (!_scanCamera.hasMultipleCameras) return;
    setState(() => _cameraReady = false);
    await _scanCamera.switchCamera();
    ref.read(smartScanProvider.notifier).reset();
    if (!mounted) return;
    setState(() {
      _cameraReady = true;
      _activeCamera = _scanCamera.activeCamera;
    });
    await _startStream();
  }

  // ─── Leveling ──────────────────────────────────────────────────────

  void _initLeveling() {
    try {
      _levelingService = LevelingService()..start();
      _levelingSub = _levelingService!.stateStream.listen((s) {
        if (!mounted) return;
        setState(() {
          _isLevel = s.isLevel;
          _tiltAngle = s.angleDegrees;
        });
        if (s.justBecameLevel) HapticFeedback.lightImpact();
      });
    } catch (_) {
      setState(() {
        _hasAccelerometer = false;
        _isLevel = true;
      });
    }
  }

  // ─── Capture Logic ─────────────────────────────────────────────────

  /// Called when pose has been locked and countdown completes.
  /// ONLY place takePicture() is called — once per scan phase.
  Future<void> _onCountdownComplete() async {
    final camera = _scanCamera.controller;
    if (_isCapturing || camera == null) return;
    final scanNotifier = ref.read(smartScanProvider.notifier);
    scanNotifier.beginCapturing();
    setState(() {
      _showCountdown = false;
      _isCapturing = true;
    });

    try {
      final bytes = await _captureController.captureStill(
        camera: camera,
        stopStream: _stopStream,
      );

      final session = ref.read(digitalTailorProvider).session;
      final notifier = ref.read(digitalTailorProvider.notifier);

      if (session.currentStep == ScanStep.frontCapture) {
        notifier.captureFrontPhoto(bytes);
        scanNotifier.resetForSide();
        // Restart stream for side capture.
        // Explicit stop + delay prevents the camera plugin from silently
        // returning early in startStream() on devices where isStreamingImages
        // stays true momentarily after captureStill's stopStream call.
        await _stopStream();
        await Future.delayed(const Duration(milliseconds: 300));
        await _startStream();
      } else if (session.currentStep == ScanStep.sideCapture) {
        scanNotifier.beginProcessing();
        await notifier.captureSidePhoto(bytes);
        final latestState = ref.read(digitalTailorProvider);

        if (latestState.result != null) {
          scanNotifier.complete();
          if (mounted) context.pushReplacement('/digital-tailor/results');
        } else {
          // Processing failed or quality check rejected the scan.
          // Reset live-scan state and restart the camera stream so the
          // user can retry the step indicated by the processing service
          // (sideCapture for quality/measurement failures, frontCapture
          // for pose-detection failures on the front image).
          scanNotifier.reset();
          if (mounted) {
            // Explicitly stop first — the camera plugin can report
            // isStreamingImages=true even after captureStill stopped it,
            // causing startStream() to silently return and leaving the
            // preview frozen with no landmarks.
            await _stopStream();
            // Give the Android camera HAL 300 ms to fully release the
            // stream buffers before requesting a new stream.
            await Future.delayed(const Duration(milliseconds: 300));
            await _startStream();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Triggered when pose lock is achieved — show countdown.
  void _onPoseLocked() {
    if (_showCountdown || _isCapturing) return;
    HapticFeedback.mediumImpact();
    ref.read(smartScanProvider.notifier).beginCountdown();
    setState(() => _showCountdown = true);
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dtState = ref.watch(digitalTailorProvider);
    final scanState = ref.watch(smartScanProvider);
    final session = dtState.session;
    final isFront = session.currentStep == ScanStep.frontCapture;

    // Trigger countdown when pose locks
    ref.listen<SmartScanState>(smartScanProvider, (prev, next) {
      if (next.workflowState == ScanWorkflowState.locked &&
          prev?.workflowState != ScanWorkflowState.locked) {
        _onPoseLocked();
      } else if (_showCountdown && !next.isPoseLocked) {
        setState(() => _showCountdown = false);
      }
    });

    if (_cameraError != null) return _buildErrorScreen();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _overlaySize = Size(constraints.maxWidth, constraints.maxHeight);

            return Stack(
              fit: StackFit.expand,
              children: [
                // ── Camera preview ─────────────────────────────────────
                if (_cameraReady && _scanCamera.controller != null)
                  _buildPreview()
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),

                // ── Live skeleton overlay ──────────────────────────────
                if (_cameraReady &&
                    scanState.rawLandmarks.isNotEmpty &&
                    _activeCamera != null &&
                    _overlaySize.width > 0)
                  Positioned.fill(
                    child: SkeletonOverlay(
                      landmarks: scanState.rawLandmarks,
                      camera: _activeCamera!,
                      imageSize: _frameSize,
                      widgetSize: _overlaySize,
                      smoothedLandmarks: scanState.landmarks,
                    ),
                  ),

                // ── Debug overlay (set enabled: true to diagnose) ─────
                if (_activeCamera != null && _overlaySize.width > 0)
                  PoseDebugOverlay(
                    landmarks: scanState.rawLandmarks,
                    camera: _activeCamera,
                    imageSize: _frameSize,
                    previewSize: _scanCamera.controller?.value.previewSize,
                    widgetSize: _overlaySize,
                    workflowState: scanState.workflowState,
                    poseConfidence: scanState.quality?.overall ?? 0,
                    lockConfidence: scanState.lockConfidence,
                    landmarkJitter: scanState.landmarkJitter,
                    fps: scanState.fps,
                    frameProcessingTimeMs: scanState.frameProcessingTimeMs,
                    enabled: kDebugMode && _debugScanOverlay,
                  ),

                // ── Top bar ────────────────────────────────────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildTopBar(isFront),
                ),

                // ── Quality indicators ─────────────────────────────────
                if (_cameraReady && scanState.quality != null)
                  Positioned(
                    top: 90,
                    left: 0,
                    right: 0,
                    child: QualityIndicatorPanel(metrics: scanState.quality!),
                  ),

                // ── Guidance card ──────────────────────────────────────
                if (!_showCountdown && !dtState.isProcessing)
                  Positioned(
                    bottom: 160,
                    left: 24,
                    right: 24,
                    child: _buildGuidanceCard(scanState, isFront),
                  ),

                // ── Countdown overlay ──────────────────────────────────
                if (_showCountdown)
                  Center(
                    child: ScanCountdown(
                      onTick: ref
                          .read(smartScanProvider.notifier)
                          .announceCountdownTick,
                      onComplete: _onCountdownComplete,
                    ),
                  ),

                // ── Processing overlay ─────────────────────────────────
                if (dtState.isProcessing)
                  Positioned.fill(
                    child: _buildProcessingOverlay(dtState.processingMessage),
                  ),

                // ── Error + debug (debug survives quality rejection) ───
                if (dtState.errorMessage != null && !dtState.isProcessing)
                  Positioned(
                    bottom: 120,
                    left: 16,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildErrorToast(dtState),
                        if (kMeasurementDebugEnabled &&
                            (dtState.measurementDebug != null ||
                                dtState.qualityReport != null)) ...[
                          const SizedBox(height: 8),
                          MeasurementDebugPanel(
                            compact: true,
                            frontCalibration: dtState.frontCalibration,
                            sideCalibration: dtState.sideCalibration,
                            qualityReport: dtState.qualityReport,
                            measurementDebug: dtState.measurementDebug,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Sub-builders ──────────────────────────────────────────────────

  Widget _buildPreview() {
    final camera = _scanCamera.controller!;
    final ratio = camera.value.aspectRatio;
    return LayoutBuilder(
      builder: (_, constraints) {
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth * ratio,
                child: CameraPreview(camera),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(bool isFront) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isFront ? 'Front  1/2' : 'Side  2/2',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_hasAccelerometer)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: LevelingIndicator(
                    angleDegrees: _tiltAngle,
                    isLevel: _isLevel,
                  ),
                ),
            ],
          ),
          const Spacer(),
          if (_scanCamera.hasMultipleCameras)
            IconButton(
              icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
              onPressed: _isCapturing ? null : _switchCamera,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard(SmartScanState scan, bool isFront) {
    final locked = scan.isPoseLocked;
    final valid = scan.isPoseValid;
    final hint = scan.primaryGuidance;
    final progress = scan.lockConfidence.clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: locked
              ? Colors.greenAccent.withValues(alpha: 0.6)
              : valid
              ? Colors.amber.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            locked
                ? 'Pose locked. Hold still.'
                : isFront
                ? 'Stand facing camera, arms slightly open'
                : 'Stand sideways, arms at your sides',
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            scan.workflowState.label,
            style: TextStyle(
              color: locked
                  ? Colors.greenAccent
                  : valid
                  ? Colors.amber
                  : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          if (hint != null && !locked) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.amber,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  hint,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (!locked) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 0.8 ? Colors.greenAccent : Colors.amber,
              ),
              minHeight: 4,
            ),
            const SizedBox(height: 4),
            Text(
              'Lock confidence ${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
            ),
          ],
          if (locked) ...[
            const SizedBox(height: 6),
            const Text(
              '✓ Pose locked',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay(String? message) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              message ?? 'Processing...',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please wait a moment',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorToast(DigitalTailorState dtState) {
    final message = dtState.errorMessage ?? '';
    final isSideRetry = dtState.session.currentStep == ScanStep.sideCapture;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (kMeasurementDebugEnabled && dtState.measurementDebug != null) ...[
            const SizedBox(height: 6),
            const Text(
              'Debug panel di bawah — screenshot sebelum retry',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSideRetry)
                TextButton(
                  onPressed: () async {
                    ref
                        .read(digitalTailorProvider.notifier)
                        .clearErrorKeepDebug();
                    ref.read(smartScanProvider.notifier).reset();
                    setState(() => _showCountdown = false);
                    await _stopStream();
                    await Future.delayed(const Duration(milliseconds: 300));
                    await _startStream();
                  },
                  child: const Text(
                    'Retry Side',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              TextButton(
                onPressed: () {
                  ref.read(digitalTailorProvider.notifier).restartScan();
                  ref.read(smartScanProvider.notifier).reset();
                  setState(() => _showCountdown = false);
                },
                child: Text(
                  isSideRetry ? 'Start Over' : 'Try Again',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Smart Scan'),
      ),
      body: Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 56,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Camera Access Required',
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _cameraError ?? 'Please allow camera access to continue.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
