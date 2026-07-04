import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Single source of truth for mapping ML Kit/MediaPipe landmark coordinates
/// into the Flutter overlay coordinate space.
///
/// Coordinate stages:
/// raw landmark -> upright preview-normalized -> optional front mirror ->
/// BoxFit crop/scale -> overlay widget pixels.
class CoordinateTransformer {
  final CameraDescription camera;

  /// Raw [CameraImage] size passed to ML Kit metadata.
  final Size imageSize;

  /// Size of the overlay stack that also contains the camera preview.
  final Size widgetSize;

  /// Must match the preview fit mode.
  final BoxFit previewFit;

  /// Whether the visible preview is mirrored. Flutter's mobile camera preview
  /// mirrors front camera output, so this defaults to front-camera detection.
  final bool mirrorPreview;

  CoordinateTransformer({
    required this.camera,
    required this.imageSize,
    required this.widgetSize,
    this.previewFit = BoxFit.cover,
    bool? mirrorPreview,
  }) : mirrorPreview =
           mirrorPreview ?? camera.lensDirection == CameraLensDirection.front;

  int get rotationDegrees => camera.sensorOrientation;

  bool get isRotatedSideways => rotationDegrees == 90 || rotationDegrees == 270;

  /// Upright coordinate space used by ML Kit's rotated output on Android.
  Size get uprightSize =>
      isRotatedSideways ? Size(imageSize.height, imageSize.width) : imageSize;

  CoordinateTransformDebug get debug {
    final fit = _fitTransform;
    return CoordinateTransformDebug(
      imageSize: imageSize,
      uprightSize: uprightSize,
      widgetSize: widgetSize,
      rotationDegrees: rotationDegrees,
      mirrorPreview: mirrorPreview,
      fit: previewFit,
      scale: fit.scale,
      offset: Offset(fit.offsetX, fit.offsetY),
      displayedSize: Size(fit.displayedWidth, fit.displayedHeight),
    );
  }

  FitTransform get fitTransform => _fitTransform;

  Offset transform(PoseLandmark landmark) => transformXY(landmark.x, landmark.y);

  Offset transformXY(double x, double y) {
    final normalized = rawToNormalized(x, y);
    return normalizedToWidget(normalized.dx, normalized.dy);
  }

  Offset normalizeToScreen(double x, double y) {
    final point = transformXY(x, y);
    if (widgetSize.width <= 0 || widgetSize.height <= 0) return Offset.zero;
    return Offset(point.dx / widgetSize.width, point.dy / widgetSize.height);
  }

  /// Converts ML Kit output into upright preview-normalized space.
  ///
  /// For Android stream frames with rotation90/270, ML Kit landmark coordinates
  /// are reported in rotated image space: x spans raw image height, y spans raw
  /// image width. This matches Google's ML Kit Flutter painter examples.
  Offset rawToNormalized(double x, double y) {
    final normalized = switch (rotationDegrees) {
      90 => Offset(
        _safeDivide(x, imageSize.height),
        _safeDivide(y, imageSize.width),
      ),
      270 => Offset(
        1.0 - _safeDivide(x, imageSize.height),
        _safeDivide(y, imageSize.width),
      ),
      180 => Offset(
        1.0 - _safeDivide(x, imageSize.width),
        1.0 - _safeDivide(y, imageSize.height),
      ),
      _ => Offset(
        _safeDivide(x, imageSize.width),
        _safeDivide(y, imageSize.height),
      ),
    };

    final mirrored = mirrorPreview
        ? Offset(1.0 - normalized.dx, normalized.dy)
        : normalized;

    return Offset(
      mirrored.dx.clamp(0.0, 1.0),
      mirrored.dy.clamp(0.0, 1.0),
    );
  }

  Offset normalizedToWidget(double x, double y) {
    if (widgetSize.width <= 0 || widgetSize.height <= 0) return Offset.zero;

    final fit = _fitTransform;
    return Offset(
      fit.offsetX + x * fit.displayedWidth,
      fit.offsetY + y * fit.displayedHeight,
    );
  }

  FitTransform get _fitTransform {
    final source = uprightSize;
    final scale = previewFit == BoxFit.cover
        ? math.max(widgetSize.width / source.width, widgetSize.height / source.height)
        : math.min(widgetSize.width / source.width, widgetSize.height / source.height);
    final displayedWidth = source.width * scale;
    final displayedHeight = source.height * scale;

    return FitTransform(
      scale: scale,
      offsetX: (widgetSize.width - displayedWidth) / 2,
      offsetY: (widgetSize.height - displayedHeight) / 2,
      displayedWidth: displayedWidth,
      displayedHeight: displayedHeight,
    );
  }

  double _safeDivide(double value, double divisor) {
    if (divisor <= 0) return 0;
    return value / divisor;
  }
}

class FitTransform {
  final double scale;
  final double offsetX;
  final double offsetY;
  final double displayedWidth;
  final double displayedHeight;

  const FitTransform({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.displayedWidth,
    required this.displayedHeight,
  });
}

class CoordinateTransformDebug {
  final Size imageSize;
  final Size uprightSize;
  final Size widgetSize;
  final int rotationDegrees;
  final bool mirrorPreview;
  final BoxFit fit;
  final double scale;
  final Offset offset;
  final Size displayedSize;

  const CoordinateTransformDebug({
    required this.imageSize,
    required this.uprightSize,
    required this.widgetSize,
    required this.rotationDegrees,
    required this.mirrorPreview,
    required this.fit,
    required this.scale,
    required this.offset,
    required this.displayedSize,
  });
}
