import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Animated 3-2-1 countdown displayed after pose lock.
///
/// Triggers [onComplete] when the countdown finishes.
/// Uses animation + haptic feedback for each tick.
class ScanCountdown extends StatefulWidget {
  final VoidCallback onComplete;
  final ValueChanged<int>? onTick;
  final int seconds;
  final Duration initialDelay;

  const ScanCountdown({
    super.key,
    required this.onComplete,
    this.onTick,
    this.seconds = 3,
    this.initialDelay = const Duration(milliseconds: 900),
  });

  @override
  State<ScanCountdown> createState() => _ScanCountdownState();
}

class _ScanCountdownState extends State<ScanCountdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  Timer? _delay;
  Timer? _ticker;

  int _current = 3;
  bool _done = false;

  @override
  void initState() {
    super.initState();

    _current = widget.seconds;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scale = Tween<double>(
      begin: 1.5,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _delay = Timer(widget.initialDelay, () {
      _tick();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    });
  }

  void _tick() {
    if (!mounted) return;

    if (_current > 0) {
      widget.onTick?.call(_current);
      HapticFeedback.heavyImpact();
      _controller.forward(from: 0);
      setState(() {});
      _current--;
    } else if (!_done) {
      _done = true;
      HapticFeedback.heavyImpact();
      _ticker?.cancel();
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _delay?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final display = _current > 0 ? '$_current' : '✓';

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Opacity(
          opacity: _done ? 0 : _fade.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  display,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
