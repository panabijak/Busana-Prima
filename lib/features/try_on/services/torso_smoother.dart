import 'dart:ui';

import '../models/torso_landmarks.dart';

/// Exponential moving-average smoother for torso landmarks (Phase 1).
///
/// Raw pose output jitters a few pixels every frame, which makes the garment
/// visibly vibrate. This applies a per-landmark EMA:
///
///   smoothed = smoothed * (1 - alpha) + raw * alpha
///
/// A lower [alpha] means heavier smoothing (calmer, slightly more lag); a
/// higher [alpha] tracks faster but jitters more. `0.35` is a good balance for
/// a live 2D try-on.
///
/// The smoother is intentionally tiny and allocation-light so it can run on
/// every processed frame without hurting the 20–30 FPS target.
class TorsoSmoother {
  final double alpha;

  TorsoLandmarks? _current;

  TorsoSmoother({this.alpha = 0.35});

  /// Feed the latest raw landmarks and get back the smoothed result.
  TorsoLandmarks add(TorsoLandmarks raw) {
    final previous = _current;
    if (previous == null) {
      _current = raw;
      return raw;
    }
    _current = TorsoLandmarks(
      leftShoulder: _ema(previous.leftShoulder, raw.leftShoulder),
      rightShoulder: _ema(previous.rightShoulder, raw.rightShoulder),
      leftHip: _ema(previous.leftHip, raw.leftHip),
      rightHip: _ema(previous.rightHip, raw.rightHip),
    );
    return _current!;
  }

  /// Clear history so the next sample is taken as-is (e.g. after the torso is
  /// lost or the camera is switched — prevents the garment sliding in from a
  /// stale position).
  void reset() => _current = null;

  Offset _ema(Offset prev, Offset next) => Offset(
        prev.dx * (1 - alpha) + next.dx * alpha,
        prev.dy * (1 - alpha) + next.dy * alpha,
      );
}
