import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/torso_landmarks.dart';
import '../services/pose_detection_service.dart';
import '../services/torso_smoother.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/garment_overlay.dart';

/// Virtual Try-On screen (MVP).
///
/// Opens the camera, continuously detects the user's torso landmarks with
/// MediaPipe / ML Kit pose detection, and overlays a transparent garment PNG
/// scaled to the shoulder width and anchored at the shoulder midpoint.
///
/// This is intentionally a lightweight 2D overlay — NOT full AR.
class TryOnScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final String transparentUrl;

  const TryOnScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.transparentUrl,
  });

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen>
    with WidgetsBindingObserver {
  // ── Camera ───────────────────────────────────────────────────────────
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _activeCamera;
  bool _isFrontCamera = true;
  bool _cameraReady = false;
  bool _switching = false;

  // ── Pose detection ───────────────────────────────────────────────────
  final PoseDetectionService _poseService = PoseDetectionService();
  final TorsoSmoother _smoother = TorsoSmoother();
  final ValueNotifier<TorsoLandmarks?> _landmarks = ValueNotifier(null);

  /// Raw `CameraImage` size (width × height) captured from the first frame.
  Size? _imageSize;

  // ── Garment ──────────────────────────────────────────────────────────
  ui.Image? _garmentImage;
  bool _garmentLoading = true;
  String? _garmentError;

  // ── Errors ───────────────────────────────────────────────────────────
  String? _fatalError;
  bool _permissionDenied = false;

  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poseService.initialize();
    _loadGarment();
    _setupCamera();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _controller?.dispose();
    _poseService.dispose();
    _landmarks.dispose();
    _garmentImage?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopStream();
    } else if (state == AppLifecycleState.resumed) {
      _startStream();
    }
  }

  // ─── Garment loading ───────────────────────────────────────────────────

  /// Resolve and decode the transparent PNG into a [ui.Image] so the
  /// [GarmentOverlay] painter can draw it directly on the canvas. Shows a
  /// loading indicator until it completes.
  void _loadGarment() {
    final provider = CachedNetworkImageProvider(widget.transparentUrl);
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        // Clone so we own a handle independent of the image cache, and can
        // safely dispose it in `dispose()`.
        final image = info.image.clone();
        if (_disposed) {
          image.dispose();
        } else if (mounted) {
          setState(() {
            _garmentImage = image;
            _garmentLoading = false;
          });
        }
        stream.removeListener(listener);
      },
      onError: (Object error, _) {
        if (!_disposed && mounted) {
          setState(() {
            _garmentError = 'Failed to load garment image.';
            _garmentLoading = false;
          });
        }
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);
  }

  // ─── Camera setup ──────────────────────────────────────────────────────

  Future<void> _setupCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _fatalError = 'No camera found on device.');
        return;
      }

      await _initController(front: true);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _fatalError = 'Camera error: ${e.description}');
      }
    } catch (e) {
      if (mounted) setState(() => _fatalError = 'Failed to start camera: $e');
    }
  }

  Future<void> _initController({required bool front}) async {
    await _stopStream();
    await _controller?.dispose();
    _controller = null;

    final direction =
        front ? CameraLensDirection.front : CameraLensDirection.back;
    final description = _cameras.firstWhere(
      (c) => c.lensDirection == direction,
      orElse: () => _cameras.first,
    );

    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();

    if (_disposed) {
      await controller.dispose();
      return;
    }

    _controller = controller;
    _activeCamera = description;
    _isFrontCamera = description.lensDirection == CameraLensDirection.front;
    _landmarks.value = null;
    _smoother.reset();
    _imageSize = null;

    if (mounted) setState(() => _cameraReady = true);
    await _startStream();
  }

  Future<void> _startStream() async {
    final controller = _controller;
    final camera = _activeCamera;
    if (controller == null ||
        camera == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream((frame) {
      _rememberImageSize(frame);
      // Fire-and-forget: the service internally drops frames while busy.
      unawaited(_processFrame(frame, camera));
    });
  }

  Future<void> _stopStream() async {
    final controller = _controller;
    if (controller?.value.isStreamingImages != true) return;
    try {
      await controller!.stopImageStream();
    } catch (_) {
      // Non-fatal: plugin can throw if the stream is already ending.
    }
  }

  Future<void> _processFrame(
    CameraImage frame,
    CameraDescription camera,
  ) async {
    final result = await _poseService.processFrame(frame, camera);
    if (_disposed || !result.processed) return;

    final next = result.landmarks;
    if (next == null) {
      // Torso lost — clear the overlay and drop smoothing history so it does
      // not slide in from a stale position when the user reappears.
      _smoother.reset();
      _landmarks.value = null;
      return;
    }
    // Temporal smoothing (Phase 1) removes high-frequency jitter and keeps the
    // garment from jumping between frames. Updating the ValueNotifier repaints
    // ONLY the garment layer — never the whole widget tree (Phase 9).
    _landmarks.value = _smoother.add(next);
  }

  /// Record the raw frame size once per camera. The shared
  /// [CoordinateTransformer] handles rotation internally, so we store the
  /// unmodified `CameraImage` dimensions here.
  void _rememberImageSize(CameraImage frame) {
    if (_imageSize != null) return;
    final size = Size(frame.width.toDouble(), frame.height.toDouble());
    if (mounted) setState(() => _imageSize = size);
  }

  Future<void> _switchCamera() async {
    if (_switching || _cameras.length < 2) return;
    setState(() {
      _switching = true;
      _cameraReady = false;
    });
    try {
      await _initController(front: !_isFrontCamera);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  bool get _hasMultipleCameras => _cameras.length >= 2;

  // ─── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return _buildMessageScreen(
        icon: Icons.no_photography_outlined,
        title: 'Camera Access Required',
        message:
            'Please allow camera access in your device settings to use Virtual '
            'Try-On.',
        showSettingsButton: true,
      );
    }
    if (_fatalError != null) {
      return _buildMessageScreen(
        icon: Icons.error_outline,
        title: 'Camera Unavailable',
        message: _fatalError!,
      );
    }

    final controller = _controller;
    final camera = _activeCamera;
    final garmentImage = _garmentImage;
    final canOverlay = _cameraReady &&
        controller != null &&
        camera != null &&
        garmentImage != null &&
        _imageSize != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ────────────────────────────────────────────
          if (_cameraReady && controller != null)
            CameraPreviewWidget(controller: controller)
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // ── Garment overlay ───────────────────────────────────────────
          if (canOverlay)
            Positioned.fill(
              child: GarmentOverlay(
                landmarks: _landmarks,
                garmentImage: garmentImage,
                camera: camera,
                imageSize: _imageSize!,
              ),
            ),

          // ── Garment loading indicator ─────────────────────────────────
          if (_garmentLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Loading garment…',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

          // ── Garment load error ────────────────────────────────────────
          if (_garmentError != null)
            Positioned(
              bottom: 120,
              left: 24,
              right: 24,
              child: _buildToast(_garmentError!),
            ),

          // ── Top bar (back + name + switch) ────────────────────────────
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),

          // ── Guidance hint ─────────────────────────────────────────────
          if (canOverlay && !_garmentLoading)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: _buildHint(),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 8,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          _circleButton(
            icon: Icons.arrow_back,
            onTap: () => context.pop(),
          ),
          Expanded(
            child: Text(
              widget.productName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_hasMultipleCameras)
            _circleButton(
              icon: Icons.cameraswitch_rounded,
              onTap: _switching ? null : _switchCamera,
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildHint() {
    return ValueListenableBuilder<TorsoLandmarks?>(
      valueListenable: _landmarks,
      builder: (context, torso, _) {
        final detected = torso != null;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: detected
                  ? Colors.greenAccent.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                detected ? Icons.check_circle : Icons.accessibility_new,
                color: detected ? Colors.greenAccent : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  detected
                      ? 'Pose detected — move to adjust the fit'
                      : 'Stand back so your upper body is fully visible',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToast(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      ),
    );
  }

  Widget _buildMessageScreen({
    required IconData icon,
    required String title,
    required String message,
    bool showSettingsButton = false,
  }) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ),
              const Spacer(),
              Icon(icon, size: 56, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              ),
              if (showSettingsButton) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: openAppSettings,
                  child: const Text('Open Settings'),
                ),
              ],
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
