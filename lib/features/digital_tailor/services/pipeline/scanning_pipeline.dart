import 'dart:typed_data';

import '../../models/body_outline.dart';
import '../../models/calibration_result.dart';
import '../../models/measurement_confidence.dart';
import '../../models/measurement_debug.dart';
import '../../models/processed_landmarks.dart';
import '../calibration/calibration_engine.dart';
import '../detection/segmentation_service.dart';
import '../measurement/body_outline_analyzer.dart';
import '../measurement/measurement_engine.dart';
import '../measurement/measurement_stabilizer.dart';
import '../validation/confidence_scorer.dart';
import '../validation/quality_controller.dart';

/// Result of the full scanning pipeline execution.
class PipelineResult {
  final bool isSuccess;
  final List<MeasurementWithConfidence>? measurements;
  final QualityReport? quality;
  final ConfidenceReport? confidence;
  final String? calibrationMethod;
  final CalibrationResult? frontCalibration;
  final CalibrationResult? sideCalibration;
  final List<MeasurementDebugTrace>? measurementDebug;
  final String? errorMessage;
  final PipelineStage? failedStage;

  const PipelineResult._({
    required this.isSuccess,
    this.measurements,
    this.quality,
    this.confidence,
    this.calibrationMethod,
    this.frontCalibration,
    this.sideCalibration,
    this.measurementDebug,
    this.errorMessage,
    this.failedStage,
  });

  factory PipelineResult.success({
    required List<MeasurementWithConfidence> measurements,
    required QualityReport quality,
    required ConfidenceReport confidence,
    required String calibrationMethod,
    required CalibrationResult frontCalibration,
    required CalibrationResult sideCalibration,
    List<MeasurementDebugTrace>? measurementDebug,
  }) {
    return PipelineResult._(
      isSuccess: true,
      measurements: measurements,
      quality: quality,
      confidence: confidence,
      calibrationMethod: calibrationMethod,
      frontCalibration: frontCalibration,
      sideCalibration: sideCalibration,
      measurementDebug: measurementDebug,
    );
  }

  factory PipelineResult.failed(
    String error, {
    PipelineStage? stage,
    List<MeasurementWithConfidence>? measurements,
    QualityReport? quality,
    CalibrationResult? frontCalibration,
    CalibrationResult? sideCalibration,
    List<MeasurementDebugTrace>? measurementDebug,
  }) {
    return PipelineResult._(
      isSuccess: false,
      errorMessage: error,
      failedStage: stage,
      measurements: measurements,
      quality: quality,
      frontCalibration: frontCalibration,
      sideCalibration: sideCalibration,
      measurementDebug: measurementDebug,
    );
  }
}

/// Stages of the pipeline (for error reporting).
enum PipelineStage {
  poseDetection,
  segmentation,
  calibration,
  outlineAnalysis,
  measurement,
  qualityControl,
}

/// The main scanning pipeline orchestrator.
///
/// Coordinates all stages of the measurement process:
/// 1. Pose detection (front + side)
/// 2. Segmentation (front + side)
/// 3. Calibration
/// 4. Body outline analysis
/// 5. Measurement computation
/// 6. Quality control
/// 7. Confidence scoring
class ScanningPipeline {
  final SegmentationService segmentationService;
  final CalibrationEngine calibrationEngine;
  final MeasurementEngine measurementEngine;
  final QualityController qualityController;
  final ConfidenceScorer confidenceScorer;

  /// Optional cross-scan EMA stabilizer (TASK 3). When present, size-driving
  /// measurements are smoothed against previous scans in the session.
  final MeasurementStabilizer? stabilizer;

  const ScanningPipeline({
    required this.segmentationService,
    required this.calibrationEngine,
    required this.measurementEngine,
    required this.qualityController,
    required this.confidenceScorer,
    this.stabilizer,
  });

  /// Execute the complete measurement pipeline.
  ///
  /// [frontLandmarks] - Pre-computed stable landmarks from multi-frame accumulation.
  /// [sideLandmarks] - Pre-computed stable landmarks from side photo.
  /// [frontImage] - Raw front image for segmentation.
  /// [sideImage] - Raw side image for segmentation.
  /// [calibrationInput] - User-provided calibration data.
  Future<PipelineResult> execute({
    required ProcessedLandmarks frontLandmarks,
    required ProcessedLandmarks sideLandmarks,
    required Uint8List frontImage,
    required Uint8List sideImage,
    required CalibrationInput calibrationInput,
  }) async {
    // ─── Stage 1: Segmentation ──────────────────────────────────────
    SegmentationResult? frontMask;
    SegmentationResult? sideMask;
    try {
      frontMask = await segmentationService.segment(frontImage);
      sideMask = await segmentationService.segment(sideImage);
    } catch (e) {
      // Segmentation failure is non-fatal — we can still compute with landmarks
    }

    // ─── Stage 2: Calibration ───────────────────────────────────────
    // Extract segmentation-derived body height when mask is available.
    // This gives the most accurate pixel-to-cm scale (eliminates both
    // the ankle-joint error and the nose-heuristic error).
    double? frontSegBodyHeightPx;
    double? frontSegCoverage;
    if (frontMask != null) {
      final bounds = frontMask.getBodyBounds();
      if (bounds != null) {
        // Scale mask rows back to image pixels for unit consistency.
        final scale = frontLandmarks.imageHeight / frontMask.height;
        frontSegBodyHeightPx = (bounds.bottom - bounds.top) * scale;
        frontSegCoverage = frontMask.bodyCoverage;
      }
    }

    double? sideSegBodyHeightPx;
    double? sideSegCoverage;
    if (sideMask != null) {
      final bounds = sideMask.getBodyBounds();
      if (bounds != null) {
        final scale = sideLandmarks.imageHeight / sideMask.height;
        sideSegBodyHeightPx = (bounds.bottom - bounds.top) * scale;
        sideSegCoverage = sideMask.bodyCoverage;
      }
    }

    CalibrationResult calibration;
    CalibrationResult sideCalibration;
    try {
      final enrichedInput = calibrationInput.copyWith(
        detectedBodyHeightPx: frontLandmarks.estimatedBodyHeightPx,
        detectedShoulderWidthPx: frontLandmarks.shoulderWidth,
        segmentationBodyHeightPx: frontSegBodyHeightPx,
        segmentationCoverage: frontSegCoverage,
        landmarkCalibrationQuality: frontLandmarks.calibrationLandmarkQuality,
      );
      calibration = await calibrationEngine.calibrate(enrichedInput);

      final sideInput = calibrationInput.copyWith(
        detectedBodyHeightPx: sideLandmarks.estimatedBodyHeightPx,
        detectedShoulderWidthPx: sideLandmarks.shoulderWidth,
        segmentationBodyHeightPx: sideSegBodyHeightPx,
        segmentationCoverage: sideSegCoverage,
        landmarkCalibrationQuality: sideLandmarks.calibrationLandmarkQuality,
      );
      sideCalibration = await calibrationEngine.calibrate(sideInput);
    } catch (e) {
      return PipelineResult.failed(
        'Kalibrasi gagal: ${e.toString()}',
        stage: PipelineStage.calibration,
      );
    }

    // ─── Stage 3: Body Outline Analysis ─────────────────────────────
    BodyOutline? frontOutline;
    BodyOutline? sideOutline;

    if (frontMask != null) {
      try {
        final analyzer = BodyOutlineAnalyzer();
        frontOutline = analyzer.analyzeFullOutline(
          mask: frontMask,
          landmarks: frontLandmarks,
          imageWidth: frontLandmarks.imageWidth,
          imageHeight: frontLandmarks.imageHeight,
          isSideView: false,
        );
      } catch (_) {}
    }

    if (sideMask != null) {
      try {
        final analyzer = BodyOutlineAnalyzer();
        sideOutline = analyzer.analyzeFullOutline(
          mask: sideMask,
          landmarks: sideLandmarks,
          imageWidth: sideLandmarks.imageWidth,
          imageHeight: sideLandmarks.imageHeight,
          isSideView: true,
        );
      } catch (_) {}
    }

    // ─── Stage 4: Measurement Computation ───────────────────────────
    MeasurementComputationResult computation;
    try {
      computation = measurementEngine.computeAll(
        frontLandmarks: frontLandmarks,
        sideLandmarks: sideLandmarks,
        frontOutline: frontOutline,
        sideOutline: sideOutline,
        pixelToCm: calibration.pixelToCm,
        pixelToCmSide: sideCalibration.pixelToCm,
        userHeightCm: calibrationInput.userHeightCm,
      );
    } catch (e) {
      return PipelineResult.failed(
        'Gagal menghitung pengukuran: ${e.toString()}',
        stage: PipelineStage.measurement,
      );
    }

    final measurements = computation.measurements;

    if (measurements.isEmpty) {
      return PipelineResult.failed(
        'Tidak ada pengukuran yang berhasil dihitung. '
        'Pastikan seluruh tubuh terlihat jelas.',
        stage: PipelineStage.measurement,
      );
    }

    // ─── Stage 5: Quality Control ───────────────────────────────────
    final quality = qualityController.validate(
      measurements: measurements,
      landmarks: frontLandmarks,
      userHeightCm: calibrationInput.userHeightCm,
    );

    if (!quality.isAcceptable) {
      final reason = quality.criticalIssues.isNotEmpty
          ? quality.criticalIssues.first.message
          : 'Ukuran badan tidak konsisten. Sila imbas semula.';
      return PipelineResult.failed(
        reason,
        stage: PipelineStage.qualityControl,
        measurements: measurements,
        quality: quality,
        frontCalibration: calibration,
        sideCalibration: sideCalibration,
        measurementDebug: computation.debugTraces,
      );
    }

    // TASK 3: temporal (pose-to-pose) EMA smoothing. Applied ONLY after the
    // scan is accepted, so a rejected low-quality scan never pollutes the
    // cross-scan history.
    final stableMeasurements = stabilizer != null
        ? stabilizer!.stabilize(measurements)
        : measurements;

    // ─── Stage 6: Confidence Scoring ────────────────────────────────
    final confidence = confidenceScorer.score(
      measurements: stableMeasurements,
      frontLandmarks: frontLandmarks,
      sideLandmarks: sideLandmarks,
      calibration: calibration,
      quality: quality,
    );

    return PipelineResult.success(
      measurements: stableMeasurements,
      quality: quality,
      confidence: confidence,
      calibrationMethod: calibration.method,
      frontCalibration: calibration,
      sideCalibration: sideCalibration,
      measurementDebug: computation.debugTraces,
    );
  }
}
