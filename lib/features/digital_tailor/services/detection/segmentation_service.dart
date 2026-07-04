import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:path_provider/path_provider.dart';

/// Service that produces a body segmentation mask from an image.
///
/// The segmentation mask identifies which pixels belong to the person
/// vs. the background. This enables measuring actual body surface widths
/// rather than relying solely on skeleton joint positions.
class SegmentationService {
  SelfieSegmenter? _segmenter;

  /// Initialize the segmenter.
  void initialize() {
    _segmenter = SelfieSegmenter(
      mode: SegmenterMode.single,
      enableRawSizeMask: true,
    );
  }

  /// Segment a person from the image.
  ///
  /// Returns a [SegmentationResult] with the mask data, or null on failure.
  Future<SegmentationResult?> segment(Uint8List imageBytes) async {
    if (_segmenter == null) return null;

    try {
      // Save to temp file for InputImage
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/seg_$timestamp.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final mask = await _segmenter!.processImage(inputImage);

      // Clean up
      try {
        await tempFile.delete();
      } catch (_) {}

      if (mask == null) return null;

      return SegmentationResult(
        confidences: mask.confidences,
        width: mask.width,
        height: mask.height,
      );
    } catch (e) {
      return null;
    }
  }

  /// Dispose resources.
  void dispose() {
    _segmenter?.close();
    _segmenter = null;
  }
}

/// Processed segmentation mask with per-pixel confidence values.
class SegmentationResult {
  /// Flat array of confidence values (0.0 to 1.0) for each pixel.
  /// Ordered row by row, left to right, top to bottom.
  final List<double> confidences;

  /// Width of the mask in pixels.
  final int width;

  /// Height of the mask in pixels.
  final int height;

  const SegmentationResult({
    required this.confidences,
    required this.width,
    required this.height,
  });

  /// Get the confidence value at (x, y) in mask coordinates.
  double getConfidenceAt(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return 0.0;
    final index = y * width + x;
    if (index >= confidences.length) return 0.0;
    return confidences[index];
  }

  /// Scan a horizontal row to find the leftmost and rightmost body pixels.
  ///
  /// [row] is the y-coordinate in mask space.
  /// [threshold] is the minimum confidence to consider a pixel as "body".
  /// [leftBound] / [rightBound] — optional x-clip range in mask coordinates.
  ///   Used by [BodyOutlineAnalyzer] to exclude limbs from torso measurements.
  ({int? left, int? right}) scanRow(
    int row, {
    double threshold = 0.5,
    int? leftBound,
    int? rightBound,
  }) {
    if (row < 0 || row >= height) return (left: null, right: null);

    final xStart = (leftBound ?? 0).clamp(0, width - 1);
    final xEnd = (rightBound ?? width - 1).clamp(0, width - 1);

    int? leftEdge;
    int? rightEdge;

    for (int x = xStart; x <= xEnd; x++) {
      if (getConfidenceAt(x, row) >= threshold) {
        leftEdge ??= x;
        rightEdge = x;
      }
    }

    return (left: leftEdge, right: rightEdge);
  }

  /// Find the topmost and bottommost rows that contain body pixels.
  ///
  /// Returns the top and bottom row indices (in mask coordinates), or null if
  /// no valid body region is found.
  ///
  /// [threshold] — pixel confidence required to count as "body".
  /// [minBodyFraction] — fraction of the row width that must be body before
  ///   the row is counted (avoids spurious single-pixel edges from hair/fingers).
  ({int top, int bottom})? getBodyBounds({
    double threshold = 0.5,
    double minBodyFraction = 0.05,
  }) {
    final minBodyPx = (width * minBodyFraction).round().clamp(1, width);

    int? topRow;
    int? bottomRow;

    for (int y = 0; y < height; y++) {
      int bodyCount = 0;
      for (int x = 0; x < width; x++) {
        if (getConfidenceAt(x, y) >= threshold) bodyCount++;
        if (bodyCount >= minBodyPx) break; // early exit once threshold met
      }
      if (bodyCount >= minBodyPx) {
        topRow ??= y;
        bottomRow = y;
      }
    }

    if (topRow == null || bottomRow == null || bottomRow <= topRow) return null;
    return (top: topRow, bottom: bottomRow);
  }

  /// Coverage of the body mask (fraction of pixels above threshold).
  ///
  /// Used to assess segmentation quality for confidence scoring.
  double get bodyCoverage {
    if (confidences.isEmpty) return 0.0;
    final bodyCount = confidences.where((c) => c >= 0.5).length;
    return bodyCount / confidences.length;
  }
}
