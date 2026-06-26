import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/scan_session.dart';
import '../providers/digital_tailor_provider.dart';
import '../services/leveling_service.dart';
import '../widgets/silhouette_overlay.dart';

/// Camera scanner screen with leveling system, silhouette overlay,
/// and front/back camera switching for self-scanning.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  LevelingService? _levelingService;
  StreamSubscription<LevelingState>? _levelingSubscription;

  bool _isCameraInitialized = false;
  bool _isLevel = false;
  bool _isCapturing = false;
  String? _levelHint;
  String? _cameraError;
  bool _hasAccelerometer = true;
  bool _isFrontCamera = true; // Default to front camera for self-scanning
  List<CameraDescription> _availableCameras = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _initializeLeveling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _levelingService?.dispose();
    _levelingSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() => _cameraError = 'Tidak ada kamera tersedia.');
        return;
      }

      await _setupCamera();
    } on CameraException catch (e) {
      setState(() {
        _cameraError = 'Akses kamera diperlukan: ${e.description}';
      });
    } catch (e) {
      setState(() {
        _cameraError = 'Gagal menginisialisasi kamera: $e';
      });
    }
  }

  /// Setup camera with the selected lens direction
  Future<void> _setupCamera() async {
    // Dispose existing controller
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
      setState(() => _isCameraInitialized = false);
    }

    // Find the desired camera
    final targetDirection = _isFrontCamera
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    CameraDescription selectedCamera;
    try {
      selectedCamera = _availableCameras.firstWhere(
        (c) => c.lensDirection == targetDirection,
      );
    } catch (_) {
      // If desired camera not found, use whatever is available
      selectedCamera = _availableCameras.first;
      _isFrontCamera =
          selectedCamera.lensDirection == CameraLensDirection.front;
    }

    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.medium, // Medium for better ML Kit performance
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
        _cameraError = null;
      });
    }
  }

  /// Switch between front and back camera
  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya satu kamera tersedia pada perangkat ini.'),
        ),
      );
      return;
    }

    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isCameraInitialized = false;
    });

    await _setupCamera();
  }

  /// Check if device has both front and back cameras
  bool get _hasBothCameras {
    final hasFront = _availableCameras.any(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    final hasBack = _availableCameras.any(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    return hasFront && hasBack;
  }

  void _initializeLeveling() {
    try {
      _levelingService = LevelingService();
      _levelingService!.start();

      _levelingSubscription = _levelingService!.stateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isLevel = state.isLevel;
            _levelHint = state.hint;
          });

          // Haptic feedback when device becomes level
          if (state.justBecameLevel) {
            HapticFeedback.lightImpact();
          }
        }
      });
    } catch (e) {
      // Device may not have accelerometer
      setState(() {
        _hasAccelerometer = false;
        _isLevel = true; // Allow capture without leveling
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || _cameraController == null) return;
    if (!_isLevel && _hasAccelerometer) return;

    setState(() => _isCapturing = true);

    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await xFile.readAsBytes();

      final tailor = ref.read(digitalTailorProvider.notifier);
      final session = ref.read(digitalTailorProvider).session;

      if (session.currentStep == ScanStep.frontCapture) {
        tailor.captureFrontPhoto(bytes);
      } else if (session.currentStep == ScanStep.sideCapture) {
        await tailor.captureSidePhoto(bytes);
        if (mounted) {
          context.pushReplacement('/digital-tailor/results');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Build camera preview with correct aspect ratio (no distortion).
  /// Uses FittedBox with BoxFit.cover to fill the screen while maintaining
  /// the camera's native aspect ratio — crops edges instead of stretching.
  Widget _buildCameraPreview() {
    final controller = _cameraController!;
    final cameraAspectRatio = controller.value.aspectRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            // Calculate the size needed to cover the container
            // while maintaining the camera's aspect ratio
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth * cameraAspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(digitalTailorProvider);
    final session = state.session;
    final isFrontCapture = session.currentStep == ScanStep.frontCapture;
    final stepLabel = isFrontCapture ? '1/2' : '2/2';

    if (_cameraError != null) {
      return _buildCameraErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview - maintain correct aspect ratio to avoid distortion
            if (_isCameraInitialized && _cameraController != null)
              Positioned.fill(child: _buildCameraPreview())
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Silhouette overlay
            if (_isCameraInitialized)
              Positioned.fill(
                child: SilhouetteOverlay(
                  isFrontView: isFrontCapture,
                  isLevel: _isLevel || !_hasAccelerometer,
                ),
              ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    // Step indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Langkah $stepLabel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Camera switch button
                    if (_hasBothCameras)
                      IconButton(
                        icon: const Icon(
                          Icons.cameraswitch_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _isCapturing ? null : _switchCamera,
                        tooltip: _isFrontCamera
                            ? 'Tukar ke kamera belakang'
                            : 'Tukar ke kamera depan',
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // Camera indicator label
            if (_isCameraInitialized)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isFrontCamera ? '📷 Kamera Depan' : '📷 Kamera Belakang',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Instruction text
                    Text(
                      isFrontCapture
                          ? 'Berdiri menghadap kamera, 2 meter dari kamera'
                          : 'Berdiri menyamping, 2 meter dari kamera',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),

                    // Self-scanning tip
                    if (_isFrontCamera)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Tip: Gunakan timer atau minta bantuan orang lain',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Leveling hint
                    if (!_hasAccelerometer)
                      const Text(
                        '⚠️ Sensor orientasi tidak tersedia. Akurasi mungkin berkurang.',
                        style: TextStyle(color: Colors.amber, fontSize: 12),
                        textAlign: TextAlign.center,
                      )
                    else if (_levelHint != null && !_isLevel)
                      Text(
                        _levelHint!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      )
                    else if (_isLevel)
                      const Text(
                        '✓ Perangkat tegak - siap mengambil foto',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),

                    const SizedBox(height: 24),

                    // Capture button row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Back button (only in side capture)
                        if (!isFrontCapture)
                          TextButton.icon(
                            onPressed: () {
                              ref
                                  .read(digitalTailorProvider.notifier)
                                  .goBackToFront();
                            },
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white70,
                              size: 18,
                            ),
                            label: const Text(
                              'Kembali',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        else
                          const SizedBox(width: 80),

                        // Capture button
                        GestureDetector(
                          onTap:
                              (_isLevel || !_hasAccelerometer) && !_isCapturing
                              ? _capturePhoto
                              : null,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (_isLevel || !_hasAccelerometer)
                                    ? Colors.white
                                    : Colors.white38,
                                width: 4,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_isLevel || !_hasAccelerometer)
                                    ? Colors.white
                                    : Colors.white24,
                              ),
                              child: _isCapturing
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),

                        // Placeholder for balance
                        const SizedBox(width: 80),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Processing overlay
            if (state.isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Menganalisis pose tubuh...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Mohon tunggu sebentar',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Error message
            if (state.errorMessage != null && !state.isProcessing)
              Positioned(
                bottom: 200,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(digitalTailorProvider.notifier)
                                  .restartScan();
                            },
                            child: const Text(
                              'Cuba Lagi',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          if (ref
                              .read(digitalTailorProvider.notifier)
                              .maxRetakesReached)
                            TextButton(
                              onPressed: () => context.pop(),
                              child: const Text(
                                'Kembali ke Profil',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraErrorScreen() {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Scanner'),
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
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Akses Kamera Diperlukan',
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _cameraError ??
                    'Izinkan akses kamera untuk melanjutkan scanning.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Buka Pengaturan',
                size: AppButtonSize.small,
                isFullWidth: false,
                onPressed: () {
                  // Open app settings
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
