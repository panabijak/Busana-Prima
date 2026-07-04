import 'dart:ui';

/// The four body landmarks required by the Virtual Try-On overlay.
///
/// Coordinates are stored as **raw ML Kit landmark pixels** — i.e. exactly the
/// `x`/`y` reported by the pose detector in the (rotated) image space. They are
/// intentionally NOT normalized or mirrored here.
///
/// Converting these into on-screen widget pixels is done in one place only —
/// the shared [CoordinateTransformer] — which is the same transform the body
/// scanner uses for its (correctly aligned) skeleton overlay. Keeping raw
/// coordinates avoids a second, divergent mapping implementation.
class TorsoLandmarks {
  final Offset leftShoulder;
  final Offset rightShoulder;
  final Offset leftHip;
  final Offset rightHip;

  const TorsoLandmarks({
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftHip,
    required this.rightHip,
  });
}
