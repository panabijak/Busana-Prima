import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/torso_landmarks.dart';
import '../services/garment_overlay_service.dart';

/// Paints the transparent garment onto the camera preview and keeps it locked
/// to the torso as the pose changes.
///
/// Rendering uses a [CustomPainter] driven directly by the landmark
/// [ValueListenable] (passed as `repaint`). This means a new pose triggers only
/// a repaint of this single layer — the widget tree is NOT rebuilt — which is
/// what keeps the overlay smooth at 20–30 FPS (Phase 9).
class GarmentOverlay extends StatelessWidget {
  /// Latest smoothed torso landmarks (`null` while no torso is visible).
  final ValueListenable<TorsoLandmarks?> landmarks;

  /// The decoded transparent garment image.
  final ui.Image garmentImage;

  /// Active camera — needed for the shared coordinate transform.
  final CameraDescription camera;

  /// Raw `CameraImage` size (width × height) used by the transform.
  final Size imageSize;

  /// Geometry helper. Stateless & const, injected for testability.
  final GarmentOverlayService overlayService;

  const GarmentOverlay({
    super.key,
    required this.landmarks,
    required this.garmentImage,
    required this.camera,
    required this.imageSize,
    this.overlayService = const GarmentOverlayService(),
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GarmentPainter(
          repaint: landmarks,
          garmentImage: garmentImage,
          camera: camera,
          imageSize: imageSize,
          overlayService: overlayService,
        ),
      ),
    );
  }
}

class _GarmentPainter extends CustomPainter {
  final ValueListenable<TorsoLandmarks?> repaintListenable;
  final ui.Image garmentImage;
  final CameraDescription camera;
  final Size imageSize;
  final GarmentOverlayService overlayService;

  _GarmentPainter({
    required ValueListenable<TorsoLandmarks?> repaint,
    required this.garmentImage,
    required this.camera,
    required this.imageSize,
    required this.overlayService,
  })  : repaintListenable = repaint,
        super(repaint: repaint);

  final Paint _paint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    final torso = repaintListenable.value;
    if (torso == null) return;

    final aspect = garmentImage.width / garmentImage.height;
    final placement = overlayService.computePlacement(
      torso: torso,
      camera: camera,
      imageSize: imageSize,
      widgetSize: size,
      garmentAspect: aspect,
    );
    if (placement == null) return;

    final src = Rect.fromLTWH(
      0,
      0,
      garmentImage.width.toDouble(),
      garmentImage.height.toDouble(),
    );

    // Rotate around the shoulder midpoint (base of the neck) so the garment
    // pivots exactly where it rests on the body and the sleeves swing from the
    // shoulders as the user leans (Phase 5).
    final pivot = placement.anchor;

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(placement.rotation);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawImageRect(garmentImage, src, placement.rect, _paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GarmentPainter oldDelegate) {
    // Pose-driven repaints are handled by the `repaint` listenable; only
    // repaint from here if a structural input (image / camera / size) changed.
    return oldDelegate.garmentImage != garmentImage ||
        oldDelegate.camera != camera ||
        oldDelegate.imageSize != imageSize;
  }
}
