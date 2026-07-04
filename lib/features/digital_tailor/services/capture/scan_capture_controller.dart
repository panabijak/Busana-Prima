import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// Owns the still-image capture sequence for the guided scan.
class ScanCaptureController {
  Future<Uint8List> captureStill({
    required CameraController camera,
    required FutureOr<void> Function() stopStream,
  }) async {
    await stopStream();
    await SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();

    final xFile = await camera.takePicture();
    return xFile.readAsBytes();
  }
}
