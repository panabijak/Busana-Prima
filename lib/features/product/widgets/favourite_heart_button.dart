import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/favourites_provider.dart';

/// Premium "Add to Favourites" microinteraction button.
/// Animates with stitching path, gradient fill, pulse ripple,
/// sparkle particles, and floating mini hearts.
class FavouriteHeartButton extends ConsumerStatefulWidget {
  final String productId;
  final double size;

  const FavouriteHeartButton({
    super.key,
    required this.productId,
    this.size = 24,
  });

  @override
  ConsumerState<FavouriteHeartButton> createState() =>
      _FavouriteHeartButtonState();
}

class _FavouriteHeartButtonState extends ConsumerState<FavouriteHeartButton>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _tapController;
  late AnimationController _particleController;
  late AnimationController _floatingHeartsController;

  late Animation<double> _stitchProgress;
  late Animation<double> _fillProgress;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;
  late Animation<double> _tapScale;

  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _floatingHeartsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _stitchProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeInOut),
      ),
    );

    _fillProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.70, curve: Curves.easeOut),
      ),
    );

    _pulseScale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );

    _pulseOpacity = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );

    _tapScale = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _mainController.dispose();
    _tapController.dispose();
    _particleController.dispose();
    _floatingHeartsController.dispose();
    super.dispose();
  }

  Future<void> _onTap(bool currentlyFavourited) async {
    if (_isAnimating) return;

    HapticFeedback.lightImpact();
    _tapController.forward().then((_) => _tapController.reverse());

    final service = ref.read(favouritesServiceProvider);

    if (!currentlyFavourited) {
      setState(() => _isAnimating = true);
      await service.toggleFavourite(widget.productId);

      _mainController.reset();
      _particleController.reset();
      _floatingHeartsController.reset();
      _mainController.forward();

      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _particleController.forward();
          _floatingHeartsController.forward();
        }
      });

      _mainController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) setState(() => _isAnimating = false);
        }
      });
    } else {
      await service.toggleFavourite(widget.productId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavAsync = ref.watch(isFavouritedProvider(widget.productId));
    final isFav = isFavAsync.valueOrNull ?? false;

    return GestureDetector(
      onTap: () => _onTap(isFav),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _mainController,
          _tapController,
          _particleController,
          _floatingHeartsController,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _tapScale.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: widget.size * 1.8,
                  height: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Pulse ripple
                      if (_isAnimating || _mainController.isAnimating)
                        Transform.scale(
                          scale: _pulseScale.value,
                          child: Opacity(
                            opacity: _pulseOpacity.value,
                            child: CustomPaint(
                              size: Size(widget.size * 1.4, widget.size * 1.4),
                              painter: _HeartPulsePainter(),
                            ),
                          ),
                        ),

                      // Floating mini hearts
                      if (_floatingHeartsController.isAnimating ||
                          _floatingHeartsController.value > 0)
                        CustomPaint(
                          size: Size(widget.size * 2.0, widget.size * 2.0),
                          painter: _FloatingHeartsPainter(
                            progress: _floatingHeartsController.value,
                          ),
                        ),

                      // Sparkle particles
                      if (_particleController.isAnimating ||
                          _particleController.value > 0)
                        CustomPaint(
                          size: Size(widget.size * 1.8, widget.size * 1.8),
                          painter: _SparkleParticlePainter(
                            progress: _particleController.value,
                          ),
                        ),

                      // Main heart
                      CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _HeartPainter(
                          isFavourited: isFav,
                          stitchProgress: _isAnimating
                              ? _stitchProgress.value
                              : (isFav ? 1.0 : 0.0),
                          fillProgress: _isAnimating
                              ? _fillProgress.value
                              : (isFav ? 1.0 : 0.0),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isFav ? 'Favourited' : 'Add to Favourite',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isFav ? const Color(0xFF8B1A3A) : Colors.black,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Paints the heart with stitching border and gradient fill.
class _HeartPainter extends CustomPainter {
  final bool isFavourited;
  final double stitchProgress;
  final double fillProgress;

  _HeartPainter({
    required this.isFavourited,
    required this.stitchProgress,
    required this.fillProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _createHeartPath(size);

    // Fill with luxurious maroon gradient
    if (fillProgress > 0) {
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF8B1A3A),
              const Color(0xFF6B1530),
              fillProgress,
            )!,
            Color.lerp(
              const Color(0xFFB8860B),
              const Color(0xFF8B1A3A),
              fillProgress,
            )!,
          ],
          stops: const [0.3, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          0,
          size.height * (1 - fillProgress),
          size.width,
          size.height * fillProgress,
        ),
      );
      canvas.drawPath(path, fillPaint);
      canvas.restore();
    }

    // Stitching border
    if (stitchProgress > 0 || isFavourited) {
      final stitchPaint = Paint()
        ..color = isFavourited && fillProgress >= 1.0
            ? const Color(0xFFD4A574)
            : const Color(0xFF8B1A3A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;

      if (stitchProgress < 1.0 && !isFavourited) {
        final pathMetrics = path.computeMetrics().first;
        final drawLength = pathMetrics.length * stitchProgress;
        const dashLength = 4.0;
        const gapLength = 3.0;
        double distance = 0;
        while (distance < drawLength) {
          final end = (distance + dashLength).clamp(0.0, drawLength);
          final extractedPath = pathMetrics.extractPath(distance, end);
          canvas.drawPath(extractedPath, stitchPaint);
          distance += dashLength + gapLength;
        }
      } else {
        canvas.drawPath(path, stitchPaint);
      }
    } else {
      final outlinePaint = Paint()
        ..color = const Color(0xFF666666)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, outlinePaint);
    }
  }

  Path _createHeartPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.5, h * 0.85);
    path.cubicTo(w * 0.15, h * 0.65, -w * 0.05, h * 0.35, w * 0.25, h * 0.2);
    path.cubicTo(w * 0.35, h * 0.12, w * 0.45, h * 0.15, w * 0.5, h * 0.3);
    path.cubicTo(w * 0.55, h * 0.15, w * 0.65, h * 0.12, w * 0.75, h * 0.2);
    path.cubicTo(w * 1.05, h * 0.35, w * 0.85, h * 0.65, w * 0.5, h * 0.85);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HeartPainter oldDelegate) {
    return oldDelegate.stitchProgress != stitchProgress ||
        oldDelegate.fillProgress != fillProgress ||
        oldDelegate.isFavourited != isFavourited;
  }
}

/// Soft pulse ripple.
class _HeartPulsePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B1A3A)
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.85)
      ..cubicTo(w * 0.15, h * 0.65, -w * 0.05, h * 0.35, w * 0.25, h * 0.2)
      ..cubicTo(w * 0.35, h * 0.12, w * 0.45, h * 0.15, w * 0.5, h * 0.3)
      ..cubicTo(w * 0.55, h * 0.15, w * 0.65, h * 0.12, w * 0.75, h * 0.2)
      ..cubicTo(w * 1.05, h * 0.35, w * 0.85, h * 0.65, w * 0.5, h * 0.85)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Floating mini hearts that drift upward during animation.
class _FloatingHeartsPainter extends CustomPainter {
  final double progress;
  static final _random = Random(7);
  static final _hearts = List.generate(
    5,
    (i) => _FloatingHeart.random(_random),
  );

  _FloatingHeartsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final heart in _hearts) {
      // Fade in then out
      final fadeIn = (progress * 3).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - progress) * 2).clamp(0.0, 1.0);
      final opacity = (fadeIn * fadeOut * 0.7).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final drift = progress * size.height * 0.8 * heart.speed;
      final x = center.dx + heart.xOffset * size.width * 0.4;
      final y = center.dy - drift;

      canvas.save();
      canvas.translate(x, y);

      final scale = heart.size * (1.0 - progress * 0.3);
      canvas.scale(scale, scale);

      final paint = Paint()
        ..color = heart.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // Draw mini heart shape
      final heartPath = Path()
        ..moveTo(0, 2)
        ..cubicTo(-1.5, 0, -3, -1, -1.5, -2.5)
        ..cubicTo(-0.5, -3.5, 0, -2, 0, -1)
        ..cubicTo(0, -2, 0.5, -3.5, 1.5, -2.5)
        ..cubicTo(3, -1, 1.5, 0, 0, 2)
        ..close();

      canvas.drawPath(heartPath, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingHeartsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _FloatingHeart {
  final double xOffset;
  final double speed;
  final double size;
  final Color color;

  const _FloatingHeart({
    required this.xOffset,
    required this.speed,
    required this.size,
    required this.color,
  });

  static _FloatingHeart random(Random rng) {
    const colors = [
      Color(0xFF8B1A3A),
      Color(0xFFD4A574),
      Color(0xFFE8C58A),
      Color(0xFFC9506B),
      Color(0xFFB8860B),
    ];
    return _FloatingHeart(
      xOffset: (rng.nextDouble() - 0.5) * 2,
      speed: 0.5 + rng.nextDouble() * 0.5,
      size: 0.8 + rng.nextDouble() * 0.6,
      color: colors[rng.nextInt(colors.length)],
    );
  }
}

/// Elegant sparkle/thread particles.
class _SparkleParticlePainter extends CustomPainter {
  final double progress;
  static final _random = Random(42);
  static final _particles = List.generate(8, (i) => _Particle.random(_random));

  _SparkleParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in _particles) {
      final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.8;
      if (opacity <= 0) continue;

      final distance = progress * size.width * 0.6 * particle.speed;
      final x = center.dx + cos(particle.angle) * distance;
      final y = center.dy + sin(particle.angle) * distance;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final sparkleSize = particle.size * (1.0 - progress * 0.5);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * pi * 0.5);

      final sparklePath = Path()
        ..moveTo(0, -sparkleSize)
        ..lineTo(sparkleSize * 0.4, 0)
        ..lineTo(0, sparkleSize)
        ..lineTo(-sparkleSize * 0.4, 0)
        ..close();

      canvas.drawPath(sparklePath, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });

  static _Particle random(Random rng) {
    const colors = [
      Color(0xFFD4A574),
      Color(0xFF8B1A3A),
      Color(0xFFE8C58A),
      Color(0xFFB8860B),
      Color(0xFFC9A96E),
    ];
    return _Particle(
      angle: rng.nextDouble() * 2 * pi,
      speed: 0.6 + rng.nextDouble() * 0.5,
      size: 2.5 + rng.nextDouble() * 2.0,
      color: colors[rng.nextInt(colors.length)],
    );
  }
}
