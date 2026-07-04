import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/scan_workflow_state.dart';
import '../services/detection/coordinate_transformer.dart';

/// Debug overlay — shows raw landmark values and transformed positions.
/// Enable with [enabled] = true during development.
class PoseDebugOverlay extends StatelessWidget {
  final List<PoseLandmark> landmarks;
  final CameraDescription? camera;
  final Size imageSize;
  final Size? previewSize;
  final Size widgetSize;
  final BoxFit previewFit;
  final ScanWorkflowState workflowState;
  final double poseConfidence;
  final double lockConfidence;
  final double landmarkJitter;
  final double fps;
  final int frameProcessingTimeMs;
  final bool enabled;

  const PoseDebugOverlay({
    super.key,
    required this.landmarks,
    required this.camera,
    required this.imageSize,
    this.previewSize,
    required this.widgetSize,
    this.previewFit = BoxFit.cover,
    this.workflowState = ScanWorkflowState.searching,
    this.poseConfidence = 0,
    this.lockConfidence = 0,
    this.landmarkJitter = 0,
    this.fps = 0,
    this.frameProcessingTimeMs = 0,
    this.enabled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled || landmarks.isEmpty || camera == null) {
      return const SizedBox.shrink();
    }

    final transformer = CoordinateTransformer(
      camera: camera!,
      imageSize: imageSize,
      widgetSize: widgetSize,
      previewFit: previewFit,
    );
    final debug = transformer.debug;

    final map = {for (final lm in landmarks) lm.type: lm};
    final nose = map[PoseLandmarkType.nose];
    final ls = map[PoseLandmarkType.leftShoulder];
    final rs = map[PoseLandmarkType.rightShoulder];
    final lh = map[PoseLandmarkType.leftHip];
    final rh = map[PoseLandmarkType.rightHip];

    final lines = <String>[
      'state: ${workflowState.label}',
      'fps: ${fps.toStringAsFixed(1)}',
      'processMs: $frameProcessingTimeMs',
      'poseConf: ${(poseConfidence * 100).toStringAsFixed(0)}%',
      'lockConf: ${(lockConfidence * 100).toStringAsFixed(0)}%',
      'jitter: ${landmarkJitter.toStringAsFixed(1)}px',
      'sensorOrientation: ${camera!.sensorOrientation}',
      'lensDir: ${camera!.lensDirection.name}',
      'frameSize: ${imageSize.width.toInt()}×${imageSize.height.toInt()}',
      if (previewSize != null)
        'previewSize: ${previewSize!.width.toInt()}×${previewSize!.height.toInt()}',
      'uprightSize: ${debug.uprightSize.width.toInt()}×${debug.uprightSize.height.toInt()}',
      'widgetSize: ${widgetSize.width.toInt()}×${widgetSize.height.toInt()}',
      'previewFit: ${previewFit.name}',
      'coverScale: ${debug.scale.toStringAsFixed(2)}',
      'coverOffset: (${debug.offset.dx.toInt()}, ${debug.offset.dy.toInt()})',
      'displayed: ${debug.displayedSize.width.toInt()}×${debug.displayedSize.height.toInt()}',
      'matrix: scale=${debug.scale.toStringAsFixed(4)}, tx=${debug.offset.dx.toStringAsFixed(1)}, ty=${debug.offset.dy.toStringAsFixed(1)}',
      'pixelToCm: post-capture',
      'mirror: ${debug.mirrorPreview}',
      if (nose != null) ...[
        'nose raw: (${nose.x.toInt()}, ${nose.y.toInt()})',
        'nose screen: ${_fmt(transformer.transform(nose))}',
      ],
      if (ls != null)
        'lShoulder raw: (${ls.x.toInt()}, ${ls.y.toInt()}) → ${_fmt(transformer.transform(ls))}',
      if (rs != null)
        'rShoulder raw: (${rs.x.toInt()}, ${rs.y.toInt()}) → ${_fmt(transformer.transform(rs))}',
      if (lh != null)
        'lHip raw: (${lh.x.toInt()}, ${lh.y.toInt()}) → ${_fmt(transformer.transform(lh))}',
      if (rh != null)
        'rHip raw: (${rh.x.toInt()}, ${rh.y.toInt()}) → ${_fmt(transformer.transform(rh))}',
    ];

    if (nose != null && ls != null && rs != null && lh != null && rh != null) {
      final noseS = transformer.transform(nose);
      final lsS = transformer.transform(ls);
      final rsS = transformer.transform(rs);
      final lhS = transformer.transform(lh);
      final rhS = transformer.transform(rh);

      final noseAboveShoulders = noseS.dy < ((lsS.dy + rsS.dy) / 2);
      final shoulderAboveHip =
          ((lsS.dy + rsS.dy) / 2) < ((lhS.dy + rhS.dy) / 2);
      final shoulderHorizontal =
          (lsS.dy - rsS.dy).abs() < widgetSize.height * 0.15;
      final leftOnLeft = lsS.dx < rsS.dx;

      lines.add('✓ Nose above shoulders: $noseAboveShoulders');
      lines.add('✓ Shoulder above hip: $shoulderAboveHip');
      lines.add('✓ Shoulders horizontal: $shoulderHorizontal');
      lines.add('✓ Left shoulder on left: $leftOnLeft');
    }

    return Positioned(
      top: 280,
      left: 8,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: lines
              .map(
                (l) => Text(
                  l,
                  style: const TextStyle(color: Colors.white, fontSize: 9.5),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _fmt(Offset o) => '(${o.dx.toInt()}, ${o.dy.toInt()})';
}
