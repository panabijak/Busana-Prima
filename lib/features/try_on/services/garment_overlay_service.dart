import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';

import '../../digital_tailor/services/detection/coordinate_transformer.dart';
import '../models/torso_landmarks.dart';

/// The computed on-screen placement of the garment overlay.
///
/// [rect] is the axis-aligned box (before rotation) in overlay-widget pixels.
/// [anchor] is the detected shoulder midpoint — the garment is both positioned
/// and rotated about this point, so it pivots at the base of the neck the way a
/// real garment resting on the shoulders would.
class GarmentPlacement {
  final Rect rect;
  final double rotation; // radians
  final Offset anchor; // shoulder midpoint (position + rotation pivot)

  const GarmentPlacement({
    required this.rect,
    required this.rotation,
    required this.anchor,
  });

  double get left => rect.left;
  double get top => rect.top;
  double get width => rect.width;
  double get height => rect.height;
}

/// Pure geometry helper that turns raw torso landmarks into a concrete garment
/// placement on screen.
///
/// It delegates the landmark → screen-pixel mapping to the shared
/// [CoordinateTransformer] (the exact transform the body-scanner skeleton uses)
/// so the garment lines up with the live preview. It then scales + positions
/// the garment from the shoulder width while preserving the source image
/// aspect ratio (no independent width/height stretch).
class GarmentOverlayService {
  /// Fraction of the garment PNG's WIDTH that is spanned by its shoulders.
  ///
  /// This is the garment's "reference shoulder width" (Phase 4), expressed as
  /// a ratio so it is resolution-independent. A typical top/blazer cut-out has
  /// its shoulder seams at roughly the outer ~52% of the image width (the rest
  /// is sleeve/seam allowance). The garment is scaled so that this reference
  /// span matches the user's detected shoulder width:
  ///
  ///   garmentWidth = detectedShoulderWidth / garmentShoulderWidthRatio
  ///
  /// Lower it if the garment renders too small, raise it if too wide.
  static const double garmentShoulderWidthRatio = 0.52;

  /// Vertical position of the garment's SHOULDER SEAM inside the PNG, measured
  /// from the top edge as a fraction of the garment's rendered WIDTH.
  ///
  /// This is the key to anatomically-correct anchoring. A garment cut-out is
  /// not shoulder-seam-at-the-top: there is a collar / yoke / transparent
  /// margin above the seam whose height is proportional to the garment's
  /// breadth. By placing the PNG so this seam depth lands exactly on the
  /// detected shoulder line, the garment's shoulders sit on the user's
  /// shoulders (and the neckline just above), instead of hanging from the
  /// chest.
  ///
  /// It is a single, garment-agnostic anatomical ratio — NOT a per-garment
  /// value and NOT a fixed pixel offset — so it scales automatically with
  /// shoulder width across all body sizes. Increase it if the garment still
  /// sits a little low; decrease it if it rides too high.
  static const double _shoulderSeamTopMargin = 0.15;

  /// Minimum garment height as a multiple of the detected torso height, used
  /// only as a safety floor so the garment always reaches at least the upper
  /// hip (Phase 6). Applied uniformly to keep the aspect ratio intact.
  static const double _minTorsoCoverage = 1.15;

  /// Maximum shoulder tilt (radians) applied to the overlay. Keeps the garment
  /// stable if the pose estimate briefly produces an extreme angle (Phase 5).
  static const double _maxTilt = 0.6; // ~34°

  const GarmentOverlayService();

  /// Compute the garment placement, or `null` when it cannot be determined.
  ///
  /// * [torso]         — raw landmarks straight from the pose detector.
  /// * [camera]        — active camera (lens direction + sensor orientation).
  /// * [imageSize]     — raw `CameraImage` size (width × height).
  /// * [widgetSize]    — the overlay/preview widget size in logical pixels.
  /// * [garmentAspect] — garment PNG width / height.
  GarmentPlacement? computePlacement({
    required TorsoLandmarks torso,
    required CameraDescription camera,
    required Size imageSize,
    required Size widgetSize,
    required double garmentAspect,
  }) {
    if (widgetSize.width <= 0 ||
        widgetSize.height <= 0 ||
        imageSize.width <= 0 ||
        imageSize.height <= 0 ||
        garmentAspect <= 0) {
      return null;
    }

    // Single source of truth for the landmark → screen transform.
    final transformer = CoordinateTransformer(
      camera: camera,
      imageSize: imageSize,
      widgetSize: widgetSize,
    );

    final leftShoulder = transformer.transformXY(
      torso.leftShoulder.dx,
      torso.leftShoulder.dy,
    );
    final rightShoulder = transformer.transformXY(
      torso.rightShoulder.dx,
      torso.rightShoulder.dy,
    );
    final leftHip =
        transformer.transformXY(torso.leftHip.dx, torso.leftHip.dy);
    final rightHip =
        transformer.transformXY(torso.rightHip.dx, torso.rightHip.dy);

    // ── Phase 4: torso metrics in screen pixels ──────────────────────────
    final shoulderMid = Offset(
      (leftShoulder.dx + rightShoulder.dx) / 2,
      (leftShoulder.dy + rightShoulder.dy) / 2,
    );
    final hipMid = Offset(
      (leftHip.dx + rightHip.dx) / 2,
      (leftHip.dy + rightHip.dy) / 2,
    );
    final shoulderWidthPx = (leftShoulder - rightShoulder).distance;
    if (shoulderWidthPx <= 1) return null;
    final torsoHeightPx = (hipMid - shoulderMid).distance;

    // ── Dynamic scaling from shoulder width, aspect-locked ───────────────
    // Width follows the body; height is derived from the source aspect ratio
    // so the garment is NEVER stretched independently. Because a real garment
    // cut-out already spans shoulders → hip, this naturally covers the torso
    // once the width is correct.
    double garmentWidth = shoulderWidthPx / garmentShoulderWidthRatio;
    double garmentHeight = garmentWidth / garmentAspect;

    // ── Torso coverage floor (uniform scale) ─────────────────────────────
    // If the aspect-derived garment is far shorter than the torso, grow BOTH
    // dimensions by the same factor. Scaling uniformly (a) preserves the
    // aspect ratio and (b) keeps the garment centred on the shoulder midpoint,
    // so scaling never shifts the overlay sideways or downward on its own.
    if (torsoHeightPx > 0) {
      final minHeight = torsoHeightPx * _minTorsoCoverage;
      if (garmentHeight < minHeight) {
        final k = minHeight / garmentHeight;
        garmentHeight *= k;
        garmentWidth *= k;
      }
    }

    // ── Anatomical anchoring: shoulder SEAM on the shoulder line ─────────
    // The shoulder midpoint (average of both shoulder landmarks) lies on the
    // user's shoulder line at the base of the neck. We place the PNG so that
    // its shoulder seam — which sits `_shoulderSeamTopMargin × width` below the
    // image top — coincides with that line. The garment therefore rests on the
    // shoulders with the neckline just above, and horizontal centring keeps it
    // symmetric about the neck.
    final seamDepth = garmentWidth * _shoulderSeamTopMargin;
    final top = shoulderMid.dy - seamDepth;
    final left = shoulderMid.dx - (garmentWidth / 2);

    final rect = Rect.fromLTWH(left, top, garmentWidth, garmentHeight);
    final rotation = _shoulderTilt(leftShoulder, rightShoulder);

    return GarmentPlacement(rect: rect, rotation: rotation, anchor: shoulderMid);
  }

  /// Angle of the shoulder line relative to horizontal, clamped for safety.
  ///
  /// `transformXY` already accounts for the front-camera mirror, so left and
  /// right shoulders are in the orientation the user sees. We take the
  /// absolute horizontal direction so the sign of the tilt follows the real
  /// shoulder slope regardless of which shoulder maps to the larger x.
  double _shoulderTilt(Offset leftShoulder, Offset rightShoulder) {
    // Order the two points left-to-right on screen so the angle is stable and
    // never flips by ~180° when the shoulders are near-vertical/jittery.
    final a = leftShoulder.dx <= rightShoulder.dx ? leftShoulder : rightShoulder;
    final b = leftShoulder.dx <= rightShoulder.dx ? rightShoulder : leftShoulder;
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    if (dx == 0 && dy == 0) return 0;
    final angle = math.atan2(dy, dx);
    return angle.clamp(-_maxTilt, _maxTilt);
  }
}
