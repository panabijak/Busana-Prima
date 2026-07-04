/// A 2D point with confidence score.
class LandmarkPoint2D {
  final double x;
  final double y;
  final double confidence;

  const LandmarkPoint2D({
    required this.x,
    required this.y,
    required this.confidence,
  });

  static const zero = LandmarkPoint2D(x: 0, y: 0, confidence: 0);
}

/// A 3D point with confidence score (for world landmarks).
class LandmarkPoint3D {
  final double x;
  final double y;
  final double z;
  final double confidence;

  const LandmarkPoint3D({
    required this.x,
    required this.y,
    required this.z,
    required this.confidence,
  });

  static const zero = LandmarkPoint3D(x: 0, y: 0, z: 0, confidence: 0);
}
