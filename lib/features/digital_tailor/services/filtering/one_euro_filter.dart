import 'dart:math';

/// The One Euro Filter — an adaptive low-pass filter for noisy signals.
///
/// Designed for interactive applications where low latency matters.
/// When the signal moves slowly → aggressive smoothing (removes jitter).
/// When the signal moves quickly → minimal smoothing (stays responsive).
///
/// Reference: Casiez et al., "1€ Filter: A Simple Speed-based Low-pass Filter
/// for Noisy Input in Interactive Systems", CHI 2012.
class OneEuroFilter {
  /// Minimum cutoff frequency in Hz. Lower = smoother when slow.
  final double minCutoff;

  /// Speed coefficient. Higher = more responsive to fast movements.
  final double beta;

  /// Cutoff frequency for the derivative estimation.
  final double dCutoff;

  double? _xPrev;
  double? _dxPrev;
  double? _tPrev;

  OneEuroFilter({this.minCutoff = 1.0, this.beta = 0.007, this.dCutoff = 1.0});

  /// Filter a new sample.
  ///
  /// [x] is the raw input value.
  /// [timestamp] is the time in seconds.
  /// Returns the filtered value.
  double filter(double x, double timestamp) {
    if (_tPrev == null) {
      _xPrev = x;
      _dxPrev = 0.0;
      _tPrev = timestamp;
      return x;
    }

    final dt = timestamp - _tPrev!;
    if (dt <= 0) return _xPrev!;

    // Estimate derivative (velocity)
    final dx = (x - _xPrev!) / dt;
    final alphaDx = _smoothingFactor(dt, dCutoff);
    final dxFiltered = alphaDx * dx + (1 - alphaDx) * _dxPrev!;

    // Adaptive cutoff: increases with speed
    final cutoff = minCutoff + beta * dxFiltered.abs();

    // Filter position
    final alpha = _smoothingFactor(dt, cutoff);
    final xFiltered = alpha * x + (1 - alpha) * _xPrev!;

    _xPrev = xFiltered;
    _dxPrev = dxFiltered;
    _tPrev = timestamp;

    return xFiltered;
  }

  /// Reset filter state (e.g., when starting a new scan session).
  void reset() {
    _xPrev = null;
    _dxPrev = null;
    _tPrev = null;
  }

  double _smoothingFactor(double dt, double cutoff) {
    final tau = 1.0 / (2 * pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }
}

/// Applies One Euro filtering to a 2D point (x, y).
class OneEuroFilter2D {
  final OneEuroFilter _xFilter;
  final OneEuroFilter _yFilter;

  OneEuroFilter2D({
    double minCutoff = 1.0,
    double beta = 0.007,
    double dCutoff = 1.0,
  }) : _xFilter = OneEuroFilter(
         minCutoff: minCutoff,
         beta: beta,
         dCutoff: dCutoff,
       ),
       _yFilter = OneEuroFilter(
         minCutoff: minCutoff,
         beta: beta,
         dCutoff: dCutoff,
       );

  ({double x, double y}) filter(double x, double y, double timestamp) {
    return (x: _xFilter.filter(x, timestamp), y: _yFilter.filter(y, timestamp));
  }

  void reset() {
    _xFilter.reset();
    _yFilter.reset();
  }
}

/// Applies One Euro filtering to a 3D point (x, y, z).
class OneEuroFilter3D {
  final OneEuroFilter _xFilter;
  final OneEuroFilter _yFilter;
  final OneEuroFilter _zFilter;

  OneEuroFilter3D({
    double minCutoff = 1.0,
    double beta = 0.007,
    double dCutoff = 1.0,
  }) : _xFilter = OneEuroFilter(
         minCutoff: minCutoff,
         beta: beta,
         dCutoff: dCutoff,
       ),
       _yFilter = OneEuroFilter(
         minCutoff: minCutoff,
         beta: beta,
         dCutoff: dCutoff,
       ),
       _zFilter = OneEuroFilter(
         minCutoff: minCutoff,
         beta: beta,
         dCutoff: dCutoff,
       );

  ({double x, double y, double z}) filter(
    double x,
    double y,
    double z,
    double timestamp,
  ) {
    return (
      x: _xFilter.filter(x, timestamp),
      y: _yFilter.filter(y, timestamp),
      z: _zFilter.filter(z, timestamp),
    );
  }

  void reset() {
    _xFilter.reset();
    _yFilter.reset();
    _zFilter.reset();
  }
}
