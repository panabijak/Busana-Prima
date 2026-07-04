import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/body_landmarks.dart';
import '../models/processed_landmarks.dart';
import '../services/detection/coordinate_transformer.dart';

/// Live skeleton overlay using the correct coordinate transform.
///
/// Uses [CoordinateTransformer] to map ML Kit landmark coordinates
/// (sensor image space, landscape) → Flutter screen space (portrait).
class SkeletonOverlay extends StatelessWidget {
  final List<PoseLandmark> landmarks;
  final CameraDescription camera;
  final Size imageSize; // CameraImage.width × CameraImage.height
  final Size widgetSize; // LayoutBuilder constraints (preview stack size)
  final BoxFit previewFit;
  final ProcessedLandmarks? smoothedLandmarks;

  const SkeletonOverlay({
    super.key,
    required this.landmarks,
    required this.camera,
    required this.imageSize,
    required this.widgetSize,
    this.previewFit = BoxFit.cover,
    this.smoothedLandmarks,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: widgetSize,
      painter: _SkeletonPainter(
        landmarks: landmarks,
        smoothedLandmarks: smoothedLandmarks,
        transformer: CoordinateTransformer(
          camera: camera,
          imageSize: imageSize,
          widgetSize: widgetSize,
          previewFit: previewFit,
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  final List<PoseLandmark> landmarks;
  final ProcessedLandmarks? smoothedLandmarks;
  final CoordinateTransformer transformer;

  const _SkeletonPainter({
    required this.landmarks,
    required this.smoothedLandmarks,
    required this.transformer,
  });

  static const List<(PoseLandmarkType, PoseLandmarkType)> _connections = [
    (PoseLandmarkType.leftEar, PoseLandmarkType.leftEye),
    (PoseLandmarkType.rightEar, PoseLandmarkType.rightEye),
    (PoseLandmarkType.leftEye, PoseLandmarkType.nose),
    (PoseLandmarkType.rightEye, PoseLandmarkType.nose),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.nose),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.nose),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
    (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
    (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
    (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
    (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
    (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
    (PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb),
    (PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex),
    (PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb),
    (PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty && smoothedLandmarks == null) return;
    final rawMap = {for (final lm in landmarks) lm.type: lm};
    final smoothedMap = _processedMap(smoothedLandmarks);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Connections
    for (final (a, b) in _connections) {
      final la = smoothedMap[a];
      final lb = smoothedMap[b];
      final rawA = rawMap[a];
      final rawB = rawMap[b];
      final confidenceA = la?.confidence ?? rawA?.likelihood;
      final confidenceB = lb?.confidence ?? rawB?.likelihood;
      if (confidenceA == null || confidenceB == null) continue;
      if (confidenceA < 0.3 || confidenceB < 0.3) continue;

      final pointA = la != null
          ? transformer.transformXY(la.x, la.y)
          : transformer.transform(rawA!);
      final pointB = lb != null
          ? transformer.transformXY(lb.x, lb.y)
          : transformer.transform(rawB!);
      linePaint.color = _conf(
        (confidenceA + confidenceB) / 2,
      ).withValues(alpha: 0.65);
      canvas.drawLine(pointA, pointB, linePaint);
    }

    // Dots
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.black26;

    final allTypes = <PoseLandmarkType>{
      ...rawMap.keys,
      ...smoothedMap.keys,
    };

    for (final type in allTypes) {
      final smoothed = smoothedMap[type];
      final raw = rawMap[type];
      final confidence = smoothed?.confidence ?? raw?.likelihood;
      if (confidence == null || confidence < 0.25) continue;

      final pt = smoothed != null
          ? transformer.transformXY(smoothed.x, smoothed.y)
          : transformer.transform(raw!);
      final r = confidence >= 0.7 ? 5.0 : 3.5;
      dotPaint.color = _conf(confidence);
      canvas.drawCircle(pt, r, dotPaint);
      canvas.drawCircle(pt, r, border);
    }
  }

  Map<PoseLandmarkType, LandmarkPoint2D> _processedMap(
    ProcessedLandmarks? landmarks,
  ) {
    if (landmarks == null) return const {};
    return {
      PoseLandmarkType.nose: landmarks.nose,
      PoseLandmarkType.leftEar: landmarks.leftEar,
      PoseLandmarkType.rightEar: landmarks.rightEar,
      PoseLandmarkType.leftShoulder: landmarks.leftShoulder,
      PoseLandmarkType.rightShoulder: landmarks.rightShoulder,
      PoseLandmarkType.leftElbow: landmarks.leftElbow,
      PoseLandmarkType.rightElbow: landmarks.rightElbow,
      PoseLandmarkType.leftWrist: landmarks.leftWrist,
      PoseLandmarkType.rightWrist: landmarks.rightWrist,
      PoseLandmarkType.leftHip: landmarks.leftHip,
      PoseLandmarkType.rightHip: landmarks.rightHip,
      PoseLandmarkType.leftKnee: landmarks.leftKnee,
      PoseLandmarkType.rightKnee: landmarks.rightKnee,
      PoseLandmarkType.leftAnkle: landmarks.leftAnkle,
      PoseLandmarkType.rightAnkle: landmarks.rightAnkle,
    };
  }

  Color _conf(double v) {
    if (v >= 0.80) return Colors.greenAccent;
    if (v >= 0.50) return Colors.amber;
    return Colors.redAccent;
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter old) =>
      old.landmarks != landmarks || old.smoothedLandmarks != smoothedLandmarks;
}
