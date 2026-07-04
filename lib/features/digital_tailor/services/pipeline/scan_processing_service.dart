import 'dart:typed_data';

import '../../models/calibration_result.dart';
import '../../models/measurement.dart';
import '../../models/measurement_confidence.dart';
import '../../models/measurement_debug.dart';
import '../../models/scan_result.dart';
import '../../models/scan_session.dart';
import '../../services/detection/pose_detection_service_v2.dart';
import '../../services/validation/quality_controller.dart';
import 'scanning_pipeline.dart';

/// Result of post-capture scan processing.
class ScanProcessingResult {
  final ScanResult? scanResult;
  final ConfidenceReport? confidenceReport;
  final QualityReport? qualityReport;
  final String? errorMessage;
  final ScanStep? retryStep;

  /// Front-photo calibration result for developer debug display.
  final CalibrationResult? frontCalibration;

  /// Side-photo calibration result for developer debug display.
  final CalibrationResult? sideCalibration;

  /// Per-measurement computation traces (debug mode).
  final List<MeasurementDebugTrace>? measurementDebug;

  const ScanProcessingResult.success({
    required this.scanResult,
    required this.confidenceReport,
    required this.qualityReport,
    this.frontCalibration,
    this.sideCalibration,
    this.measurementDebug,
  }) : errorMessage = null,
       retryStep = null;

  const ScanProcessingResult.failed({
    required this.errorMessage,
    required this.retryStep,
    this.qualityReport,
    this.frontCalibration,
    this.sideCalibration,
    this.measurementDebug,
  }) : scanResult = null,
       confidenceReport = null;

  bool get isSuccess => scanResult != null;
}

/// Post-capture processing orchestration:
/// still images → accurate pose detection → measurement pipeline → scan result.
class ScanProcessingService {
  final PoseDetectionServiceV2 poseService;
  final ScanningPipeline pipeline;

  const ScanProcessingService({
    required this.poseService,
    required this.pipeline,
  });

  Future<ScanProcessingResult> process({
    required Uint8List frontImage,
    required Uint8List sideImage,
    required double heightCm,
  }) async {
    final frontResult = await poseService.detectPose(frontImage);
    if (!frontResult.isSuccess || frontResult.landmarks == null) {
      return ScanProcessingResult.failed(
        errorMessage:
            frontResult.errorMessage ?? 'Failed to detect pose from front photo.',
        retryStep: ScanStep.frontCapture,
      );
    }

    final sideResult = await poseService.detectPose(sideImage);
    if (!sideResult.isSuccess || sideResult.landmarks == null) {
      return ScanProcessingResult.failed(
        errorMessage:
            sideResult.errorMessage ?? 'Failed to detect pose from side photo.',
        retryStep: ScanStep.sideCapture,
      );
    }

    final pipelineResult = await pipeline.execute(
      frontLandmarks: frontResult.landmarks!,
      sideLandmarks: sideResult.landmarks!,
      frontImage: frontImage,
      sideImage: sideImage,
      calibrationInput: CalibrationInput(userHeightCm: heightCm),
    );

    if (!pipelineResult.isSuccess || pipelineResult.measurements == null) {
      // Choose which scan step to retry based on where the pipeline failed.
      //
      // Front pose detection failure → must redo front scan.
      // Everything else (calibration, outline, measurement, quality control)
      // → the front image is already captured and valid; only the side scan
      //   needs to be redone with better pose or a cleaner side image.
      //
      // This prevents the frustrating UX of redoing the front scan after
      // a quality-control rejection that is unrelated to the front image.
      final retryStep = _retryStepForFailedStage(pipelineResult.failedStage);
      return ScanProcessingResult.failed(
        errorMessage:
            pipelineResult.errorMessage ?? 'Failed to compute measurements.',
        retryStep: retryStep,
        qualityReport: pipelineResult.quality,
        frontCalibration: pipelineResult.frontCalibration,
        sideCalibration: pipelineResult.sideCalibration,
        measurementDebug: pipelineResult.measurementDebug,
      );
    }

    final confidence = pipelineResult.confidence!;
    final scanResult = _convertToScanResult(
      pipelineResult.measurements!,
      confidence,
    );

    return ScanProcessingResult.success(
      scanResult: scanResult,
      confidenceReport: confidence,
      qualityReport: pipelineResult.quality!,
      frontCalibration: pipelineResult.frontCalibration,
      sideCalibration: pipelineResult.sideCalibration,
      measurementDebug: pipelineResult.measurementDebug,
    );
  }

  /// Map a failed pipeline stage to the scan step the user should retry.
  ScanStep _retryStepForFailedStage(PipelineStage? stage) {
    switch (stage) {
      case PipelineStage.poseDetection:
        // Pose detection failure on the front image — redo front scan.
        return ScanStep.frontCapture;
      case PipelineStage.calibration:
      case PipelineStage.segmentation:
      case PipelineStage.outlineAnalysis:
      case PipelineStage.measurement:
      case PipelineStage.qualityControl:
      case null:
        // Front image was captured successfully. The issue is downstream
        // (calibration, segmentation, measurement quality). Retry only
        // the side scan; the front bytes are preserved in session state.
        return ScanStep.sideCapture;
    }
  }

  ScanResult _convertToScanResult(
    List<MeasurementWithConfidence> measurements,
    ConfidenceReport confidence,
  ) {
    final legacyMeasurements = measurements.map((measurement) {
      return Measurement(
        key: measurement.key,
        label: measurement.label,
        valueCm: measurement.valueCm,
        valueInch: measurement.valueInch,
        region: MeasurementRegion.fromString(measurement.region),
      );
    }).toList();

    return ScanResult(
      measurements: legacyMeasurements,
      confidenceScore: confidence.overall,
      scannedAt: DateTime.now(),
      scanVersion: '2.0.0',
    );
  }
}
