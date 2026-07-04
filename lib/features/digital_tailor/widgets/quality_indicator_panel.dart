import 'package:flutter/material.dart';

import '../services/pipeline/scan_quality_evaluator.dart';

/// Live quality indicators panel shown during scanning.
///
/// Displays segmented bar indicators for each quality dimension,
/// matching the design brief:
///   Lighting       ██████████ 90%
///   Body Visibility████████── 80%
///   Pose Accuracy  ███████─── 70%
///   Distance       ██████████ 95%
///   Overall        ████████── 84%
class QualityIndicatorPanel extends StatelessWidget {
  final ScanQualityMetrics metrics;

  const QualityIndicatorPanel({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QualityRow(label: 'Lighting', value: metrics.lighting),
          const SizedBox(height: 5),
          _QualityRow(label: 'Body Visibility', value: metrics.bodyVisibility),
          const SizedBox(height: 5),
          _QualityRow(label: 'Pose Accuracy', value: metrics.poseAccuracy),
          const SizedBox(height: 5),
          _QualityRow(label: 'Distance', value: metrics.cameraDistance),
          const SizedBox(height: 8),
          // Overall divider
          Container(height: 0.5, color: Colors.white24),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Overall Confidence',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(metrics.overall * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: _valueColor(metrics.overall),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _valueColor(double v) {
    if (v >= 0.8) return Colors.greenAccent;
    if (v >= 0.6) return Colors.amber;
    return Colors.redAccent;
  }
}

class _QualityRow extends StatelessWidget {
  final String label;
  final double value;

  const _QualityRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = _color(value);
    final segments = 10;
    final filledSegments = (value * segments).round().clamp(0, segments);

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: List.generate(segments, (i) {
              final filled = i < filledSegments;
              return Expanded(
                child: Container(
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: filled
                        ? color
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 32,
          child: Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Color _color(double v) {
    if (v >= 0.75) return Colors.greenAccent;
    if (v >= 0.5) return Colors.amber;
    return Colors.redAccent;
  }
}
