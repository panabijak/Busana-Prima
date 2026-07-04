import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme.dart';

/// Elegant "Digital Tailor" quick-action banner for the home screen.
///
/// Highlights the 3D body scanning feature with:
/// - Animated gradient background matching the project's plum palette
/// - Floating measurement indicator dots
/// - Shimmer highlight animation
/// - Clear CTA navigating to calibration screen
class DigitalTailorBanner extends StatefulWidget {
  const DigitalTailorBanner({super.key});

  @override
  State<DigitalTailorBanner> createState() => _DigitalTailorBannerState();
}

class _DigitalTailorBannerState extends State<DigitalTailorBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          onTap: () => context.push(AppRoutes.digitalTailorCalibration),
          child: Container(
            height: 132,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // ── Gradient background ──────────────────────────────
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF380438), // primaryDark
                            Color(0xFF580C58), // primary
                            Color(0xFF7A1C7A), // primaryLight
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // ── Shimmer sweep ────────────────────────────────────
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _shimmerAnim,
                      builder: (_, __) {
                        return ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: const [
                                Colors.transparent,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [
                                (_shimmerAnim.value - 0.3).clamp(0.0, 1.0),
                                _shimmerAnim.value.clamp(0.0, 1.0),
                                (_shimmerAnim.value + 0.3).clamp(0.0, 1.0),
                              ],
                            ).createShader(bounds);
                          },
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        );
                      },
                    ),
                  ),

                  // ── Decorative circles ───────────────────────────────
                  Positioned(
                    right: -18,
                    top: -18,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 36,
                    bottom: -30,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),

                  // ── Floating body-scan icon ──────────────────────────
                  Positioned(
                    right: 20,
                    top: 0,
                    bottom: 0,
                    child: Center(child: _BodyScanIcon()),
                  ),

                  // ── Text + CTA ───────────────────────────────────────
                  Positioned(
                    left: 20,
                    top: 0,
                    bottom: 0,
                    right: 120,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "NEW" pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'BARU',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Digital Tailor',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          'Ukuran badan tepat\ndari kamera anda',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.75),
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // CTA button
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Mula Scan',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 200.ms)
        .slideY(begin: 0.08, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }
}

/// Animated body-scan SVG-style icon painted with Canvas.
class _BodyScanIcon extends StatefulWidget {
  @override
  State<_BodyScanIcon> createState() => _BodyScanIconState();
}

class _BodyScanIconState extends State<_BodyScanIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        return Transform.scale(
          scale: _pulseAnim.value,
          child: SizedBox(
            width: 72,
            height: 88,
            child: CustomPaint(
              painter: _BodyScanPainter(scanProgress: _scanLineAnim.value),
            ),
          ),
        );
      },
    );
  }
}

/// Paints a minimal body outline with an animated scan line.
class _BodyScanPainter extends CustomPainter {
  final double scanProgress;

  _BodyScanPainter({required this.scanProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    // Head
    path.addOval(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.07), radius: w * 0.11),
    );

    // Shoulders / arms (T-Pose)
    path.moveTo(w * 0.36, h * 0.16);
    path.lineTo(w * 0.05, h * 0.16);
    path.moveTo(w * 0.64, h * 0.16);
    path.lineTo(w * 0.95, h * 0.16);

    // Torso
    path.moveTo(w * 0.38, h * 0.14);
    path.lineTo(w * 0.40, h * 0.38);
    path.lineTo(w * 0.38, h * 0.50);

    path.moveTo(w * 0.62, h * 0.14);
    path.lineTo(w * 0.60, h * 0.38);
    path.lineTo(w * 0.62, h * 0.50);

    // Hip connector
    path.moveTo(w * 0.38, h * 0.50);
    path.lineTo(w * 0.62, h * 0.50);

    // Legs
    path.moveTo(w * 0.43, h * 0.50);
    path.lineTo(w * 0.42, h * 0.73);
    path.lineTo(w * 0.43, h * 0.97);

    path.moveTo(w * 0.57, h * 0.50);
    path.lineTo(w * 0.58, h * 0.73);
    path.lineTo(w * 0.57, h * 0.97);

    canvas.drawPath(path, bodyPaint);

    // Measurement dots at key points
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final dotPoints = [
      Offset(w * 0.5, h * 0.16), // shoulder mid
      Offset(w * 0.5, h * 0.38), // waist
      Offset(w * 0.5, h * 0.50), // hip
    ];

    for (final pt in dotPoints) {
      canvas.drawCircle(pt, 2.5, dotPaint);
    }

    // Scan line (animated horizontal sweep)
    final scanY = h * (0.05 + scanProgress * 0.92);
    final scanPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Dashed scan line approximation
    final dashWidth = w * 0.08;
    final gap = w * 0.04;
    double x = 0;
    while (x < w) {
      canvas.drawLine(
        Offset(x, scanY),
        Offset(min(x + dashWidth, w), scanY),
        scanPaint,
      );
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _BodyScanPainter old) =>
      old.scanProgress != scanProgress;
}
