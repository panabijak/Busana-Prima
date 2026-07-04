import 'package:camera/camera.dart';

typedef ScanFrameCallback =
    void Function(CameraImage frame, CameraDescription camera);

/// Owns camera selection, lifecycle, preview controller, and image stream.
class ScanCameraController {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _activeCamera;
  bool _isFrontCamera = true;

  CameraController? get controller => _controller;
  CameraDescription? get activeCamera => _activeCamera;
  bool get isReady => _controller?.value.isInitialized == true;
  bool get isFrontCamera => _isFrontCamera;
  bool get hasMultipleCameras => _cameras.length >= 2;

  Future<void> initialize({bool frontCamera = true}) async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw StateError('No camera available.');
    }
    await setup(frontCamera: frontCamera);
  }

  Future<void> setup({required bool frontCamera}) async {
    await stopStream();
    await _controller?.dispose();
    _controller = null;

    _isFrontCamera = frontCamera;
    final direction = frontCamera
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final description = _cameras.firstWhere(
      (camera) => camera.lensDirection == direction,
      orElse: () => _cameras.first,
    );

    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller.initialize();
    _controller = controller;
    _activeCamera = description;
  }

  Future<bool> switchCamera() async {
    if (!hasMultipleCameras) return false;
    await setup(frontCamera: !_isFrontCamera);
    return true;
  }

  Future<void> startStream(ScanFrameCallback onFrame) async {
    final controller = _controller;
    final activeCamera = _activeCamera;
    if (controller == null || activeCamera == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isStreamingImages) return;

    await controller.startImageStream((frame) => onFrame(frame, activeCamera));
  }

  Future<void> stopStream() async {
    final controller = _controller;
    if (controller?.value.isStreamingImages != true) return;
    try {
      await controller!.stopImageStream();
    } catch (_) {
      // Non-fatal: the camera plugin can throw if the stream is already ending.
    }
  }

  Future<void> dispose() async {
    await stopStream();
    await _controller?.dispose();
    _controller = null;
    _activeCamera = null;
  }
}
