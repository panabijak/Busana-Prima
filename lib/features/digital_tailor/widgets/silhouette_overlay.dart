import 'package:flutter/material.dart';

/// Overlay widget that displays a human silhouette outline on the camera viewfinder.
/// Changes border color based on device leveling state.
class SilhouetteOverlay extends StatelessWidget {
  final bool isFrontView;
  final bool isLevel;

  const SilhouetteOverlay({
    super.key,
    required this.isFrontView,
    required this.isLevel,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isLevel ? Colors.greenAccent : Colors.redAccent;
    final size = MediaQuery.of(context).size;

    // Silhouette occupies 75% of viewfinder height
    final silhouetteHeight = size.height * 0.75;
    final silhouetteWidth = isFrontView
        ? silhouetteHeight *
              0.35 // Front view aspect ratio
        : silhouetteHeight * 0.25; // Side view is narrower

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: silhouetteWidth,
        height: silhouetteHeight,
        child: CustomPaint(
          painter: _SilhouettePainter(
            isFrontView: isFrontView,
            borderColor: borderColor,
          ),
        ),
      ),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  final bool isFrontView;
  final Color borderColor;

  _SilhouettePainter({required this.isFrontView, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    if (isFrontView) {
      _drawFrontSilhouette(canvas, size, paint, fillPaint);
    } else {
      _drawSideSilhouette(canvas, size, paint, fillPaint);
    }
  }

  void _drawFrontSilhouette(
    Canvas canvas,
    Size size,
    Paint paint,
    Paint fillPaint,
  ) {
    final w = size.width;
    final h = size.height;

    final path = Path();

    // Head (circle at top)
    final headCenterX = w / 2;
    final headCenterY = h * 0.06;
    final headRadius = w * 0.12;

    path.addOval(
      Rect.fromCircle(
        center: Offset(headCenterX, headCenterY),
        radius: headRadius,
      ),
    );

    // Neck
    path.moveTo(w * 0.43, h * 0.09);
    path.lineTo(w * 0.43, h * 0.12);
    path.moveTo(w * 0.57, h * 0.09);
    path.lineTo(w * 0.57, h * 0.12);

    // Shoulders
    path.moveTo(w * 0.43, h * 0.12);
    path.lineTo(w * 0.15, h * 0.15);
    path.moveTo(w * 0.57, h * 0.12);
    path.lineTo(w * 0.85, h * 0.15);

    // Arms (left)
    path.moveTo(w * 0.15, h * 0.15);
    path.lineTo(w * 0.10, h * 0.35);
    path.lineTo(w * 0.08, h * 0.50);

    // Arms (right)
    path.moveTo(w * 0.85, h * 0.15);
    path.lineTo(w * 0.90, h * 0.35);
    path.lineTo(w * 0.92, h * 0.50);

    // Torso
    path.moveTo(w * 0.20, h * 0.15);
    path.lineTo(w * 0.22, h * 0.35); // Waist
    path.lineTo(w * 0.20, h * 0.50); // Hip

    path.moveTo(w * 0.80, h * 0.15);
    path.lineTo(w * 0.78, h * 0.35); // Waist
    path.lineTo(w * 0.80, h * 0.50); // Hip

    // Legs (left)
    path.moveTo(w * 0.30, h * 0.50);
    path.lineTo(w * 0.32, h * 0.72);
    path.lineTo(w * 0.33, h * 0.95);

    // Legs (right)
    path.moveTo(w * 0.70, h * 0.50);
    path.lineTo(w * 0.68, h * 0.72);
    path.lineTo(w * 0.67, h * 0.95);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
  }

  void _drawSideSilhouette(
    Canvas canvas,
    Size size,
    Paint paint,
    Paint fillPaint,
  ) {
    final w = size.width;
    final h = size.height;

    final path = Path();

    // Head (circle)
    final headCenterX = w * 0.5;
    final headCenterY = h * 0.06;
    final headRadius = w * 0.15;

    path.addOval(
      Rect.fromCircle(
        center: Offset(headCenterX, headCenterY),
        radius: headRadius,
      ),
    );

    // Neck
    path.moveTo(w * 0.45, h * 0.09);
    path.lineTo(w * 0.42, h * 0.13);

    // Back line
    path.moveTo(w * 0.35, h * 0.13);
    path.lineTo(w * 0.30, h * 0.25);
    path.lineTo(w * 0.32, h * 0.40);
    path.lineTo(w * 0.30, h * 0.50);

    // Front line (chest/belly)
    path.moveTo(w * 0.55, h * 0.13);
    path.lineTo(w * 0.65, h * 0.25);
    path.lineTo(w * 0.60, h * 0.40);
    path.lineTo(w * 0.58, h * 0.50);

    // Arm
    path.moveTo(w * 0.55, h * 0.15);
    path.lineTo(w * 0.60, h * 0.30);
    path.lineTo(w * 0.55, h * 0.48);

    // Legs
    path.moveTo(w * 0.40, h * 0.50);
    path.lineTo(w * 0.38, h * 0.72);
    path.lineTo(w * 0.40, h * 0.95);

    path.moveTo(w * 0.55, h * 0.50);
    path.lineTo(w * 0.57, h * 0.72);
    path.lineTo(w * 0.55, h * 0.95);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.isFrontView != isFrontView;
  }
}
