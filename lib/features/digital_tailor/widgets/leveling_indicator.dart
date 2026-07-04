import 'package:flutter/material.dart';

/// A compact visual indicator showing device tilt angle.
///
/// Displays a horizontal line with a bubble that moves based on tilt.
/// Green when within acceptable range, red when tilted.
class LevelingIndicator extends StatelessWidget {
  /// Current tilt angle in degrees (0 = perfectly vertical).
  final double angleDegrees;

  /// Maximum acceptable deviation.
  final double maxDeviation;

  /// Whether the device is currently level.
  final bool isLevel;

  const LevelingIndicator({
    super.key,
    required this.angleDegrees,
    this.maxDeviation = 5.0,
    required this.isLevel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isLevel ? Colors.greenAccent : Colors.redAccent;
    // Normalize angle to [-1, 1] range for positioning
    final normalized = (angleDegrees / 30.0).clamp(-1.0, 1.0);

    return SizedBox(
      width: 120,
      height: 28,
      child: CustomPaint(
        painter: _LevelingPainter(
          normalizedTilt: normalized,
          color: color,
          isLevel: isLevel,
        ),
      ),
    );
  }
}

class _LevelingPainter extends CustomPainter {
  final double normalizedTilt;
  final Color color;
  final bool isLevel;

  _LevelingPainter({
    required this.normalizedTilt,
    required this.color,
    required this.isLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final centerX = size.width / 2;

    // Track background
    final trackPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(8, centerY),
      Offset(size.width - 8, centerY),
      trackPaint,
    );

    // Center marker
    final markerPaint = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(centerX, centerY - 6),
      Offset(centerX, centerY + 6),
      markerPaint,
    );

    // Bubble
    final bubbleX = centerX + normalizedTilt * (size.width / 2 - 12);
    final bubblePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(bubbleX, centerY), 6, bubblePaint);

    // Bubble border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(Offset(bubbleX, centerY), 6, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _LevelingPainter old) {
    return old.normalizedTilt != normalizedTilt || old.color != color;
  }
}
