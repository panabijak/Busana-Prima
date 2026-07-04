/// Developer trace for a single computed measurement.
///
/// Shows the raw geometry before and after pixel-to-cm conversion so
/// engineers can pinpoint where a value becomes anatomically wrong.
class MeasurementDebugTrace {
  final String key;
  final String label;

  /// Raw pixel distance or contour width in image space.
  final double? widthPx;

  /// Side-view torso depth in pixels (circumference only).
  final double? depthPx;

  /// Pixel-to-cm factor applied to [widthPx].
  final double? pixelToCm;

  /// Side pixel-to-cm factor applied to [depthPx].
  final double? pixelToCmSide;

  /// Contour width converted to cm (full diameter, not semi-axis).
  final double? contourWidthCm;

  /// Contour depth converted to cm (full diameter, not semi-axis).
  final double? contourDepthCm;

  /// Ellipse semi-axis a (half front width) in cm.
  final double? semiAxisAcm;

  /// Ellipse semi-axis b (half side depth) in cm.
  final double? semiAxisBcm;

  /// Final reported value in cm.
  final double finalCm;

  /// Computation confidence.
  final double confidence;

  /// Human-readable formula path (e.g. frontSideFusion, landmarkLinear).
  final String method;

  const MeasurementDebugTrace({
    required this.key,
    required this.label,
    this.widthPx,
    this.depthPx,
    this.pixelToCm,
    this.pixelToCmSide,
    this.contourWidthCm,
    this.contourDepthCm,
    this.semiAxisAcm,
    this.semiAxisBcm,
    required this.finalCm,
    required this.confidence,
    required this.method,
  });
}
