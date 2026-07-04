import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/calibration_result.dart';
import '../models/measurement_confidence.dart';
import '../models/measurement_debug.dart';
import '../models/scan_result.dart';
import '../models/scan_session.dart';
import '../services/calibration/calibration_engine.dart';
import '../services/calibration/height_calibrator.dart';
import '../services/calibration/segmentation_calibrator.dart';
import '../services/detection/pose_detection_service_v2.dart';
import '../services/detection/segmentation_service.dart';
import '../services/measurement/measurement_engine.dart';
import '../services/measurement/measurement_stabilizer.dart';
import '../services/measurement_firestore_service.dart';
import '../services/pipeline/scan_processing_service.dart';
import '../services/pipeline/scanning_pipeline.dart';
import '../services/validation/confidence_scorer.dart';
import '../services/validation/quality_controller.dart';

/// Provider for the Firestore measurement service
final measurementFirestoreServiceProvider = Provider((ref) {
  return MeasurementFirestoreService();
});

// ─── V2 Pipeline Providers ──────────────────────────────────────────────────

/// V2 Pose Detection Service
final poseDetectionServiceV2Provider = Provider((ref) {
  final service = PoseDetectionServiceV2();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

/// V2 Segmentation Service
final segmentationServiceProvider = Provider((ref) {
  final service = SegmentationService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

/// V2 Calibration Engine (tries strategies in priority order)
final calibrationEngineProvider = Provider((ref) {
  return CalibrationEngine(strategies: [
    SegmentationCalibrator(), // priority 2: preferred when mask succeeds
    HeightCalibrator(), // priority 4: landmark-based fallback
  ]);
});

/// V2 Measurement Engine
final measurementEngineProvider = Provider((ref) => MeasurementEngine());

/// V2 Quality Controller
final qualityControllerProvider = Provider((ref) => QualityController());

/// V2 Confidence Scorer
final confidenceScorerProvider = Provider((ref) => ConfidenceScorer());

/// V2 Cross-scan measurement stabilizer (EMA). Singleton for the session.
final measurementStabilizerProvider =
    Provider((ref) => MeasurementStabilizer(alpha: 0.6));

/// V2 Scanning Pipeline (orchestrates the entire measurement flow)
final scanningPipelineProvider = Provider((ref) {
  return ScanningPipeline(
    segmentationService: ref.watch(segmentationServiceProvider),
    calibrationEngine: ref.watch(calibrationEngineProvider),
    measurementEngine: ref.watch(measurementEngineProvider),
    qualityController: ref.watch(qualityControllerProvider),
    confidenceScorer: ref.watch(confidenceScorerProvider),
    stabilizer: ref.watch(measurementStabilizerProvider),
  );
});

/// Post-capture processor for accurate pose detection + measurements.
final scanProcessingServiceProvider = Provider((ref) {
  return ScanProcessingService(
    poseService: ref.watch(poseDetectionServiceV2Provider),
    pipeline: ref.watch(scanningPipelineProvider),
  );
});

/// Main state notifier for the digital tailor scanning flow (V2)
final digitalTailorProvider =
    StateNotifierProvider<DigitalTailorNotifier, DigitalTailorState>((ref) {
      return DigitalTailorNotifier(
        firestoreService: ref.watch(measurementFirestoreServiceProvider),
        processingService: ref.watch(scanProcessingServiceProvider),
        stabilizer: ref.watch(measurementStabilizerProvider),
      );
    });

/// State for the digital tailor module
class DigitalTailorState {
  final ScanSession session;
  final ScanResult? result;
  final bool isProcessing;
  final bool isSaving;
  final String? errorMessage;
  final int retakeAttempts;
  final int saveAttempts;

  /// V2: per-measurement confidence data
  final ConfidenceReport? confidenceReport;

  /// V2: quality report from validation
  final QualityReport? qualityReport;

  /// V2: processing progress message
  final String? processingMessage;

  /// Debug: front-photo calibration details (pixelToCm, method, confidence, etc.)
  final CalibrationResult? frontCalibration;

  /// Debug: side-photo calibration details
  final CalibrationResult? sideCalibration;

  /// Debug: per-measurement computation traces
  final List<MeasurementDebugTrace>? measurementDebug;

  const DigitalTailorState({
    this.session = const ScanSession(),
    this.result,
    this.isProcessing = false,
    this.isSaving = false,
    this.errorMessage,
    this.retakeAttempts = 0,
    this.saveAttempts = 0,
    this.confidenceReport,
    this.qualityReport,
    this.processingMessage,
    this.frontCalibration,
    this.sideCalibration,
    this.measurementDebug,
  });

  DigitalTailorState copyWith({
    ScanSession? session,
    ScanResult? result,
    bool? isProcessing,
    bool? isSaving,
    String? errorMessage,
    int? retakeAttempts,
    int? saveAttempts,
    ConfidenceReport? confidenceReport,
    QualityReport? qualityReport,
    String? processingMessage,
    CalibrationResult? frontCalibration,
    CalibrationResult? sideCalibration,
    List<MeasurementDebugTrace>? measurementDebug,
    bool clearResult = false,
    bool clearError = false,
    bool clearConfidence = false,
    bool clearQuality = false,
  }) {
    return DigitalTailorState(
      session: session ?? this.session,
      result: clearResult ? null : (result ?? this.result),
      isProcessing: isProcessing ?? this.isProcessing,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      retakeAttempts: retakeAttempts ?? this.retakeAttempts,
      saveAttempts: saveAttempts ?? this.saveAttempts,
      confidenceReport: clearConfidence
          ? null
          : (confidenceReport ?? this.confidenceReport),
      qualityReport: clearQuality
          ? null
          : (qualityReport ?? this.qualityReport),
      processingMessage: processingMessage,
      frontCalibration: frontCalibration ?? this.frontCalibration,
      sideCalibration: sideCalibration ?? this.sideCalibration,
      measurementDebug: measurementDebug ?? this.measurementDebug,
    );
  }
}

/// Notifier managing the digital tailor scanning workflow.
///
/// V2: Uses the new ScanningPipeline for measurement computation while
/// maintaining backward compatibility with the existing UI flow.
class DigitalTailorNotifier extends StateNotifier<DigitalTailorState> {
  final MeasurementFirestoreService firestoreService;
  final ScanProcessingService processingService;
  final MeasurementStabilizer stabilizer;

  DigitalTailorNotifier({
    required this.firestoreService,
    required this.processingService,
    required this.stabilizer,
  }) : super(const DigitalTailorState());

  /// Set user height for calibration and proceed to front capture
  void setCalibration(double heightCm) {
    // New scan session → clear cross-scan EMA history so measurements from a
    // previous person/session never bleed into this one.
    stabilizer.reset();
    state = state.copyWith(
      session: state.session.copyWith(
        userHeightCm: heightCm,
        currentStep: ScanStep.frontCapture,
      ),
      clearError: true,
    );
  }

  /// Capture front photo and move to side capture
  void captureFrontPhoto(Uint8List imageBytes) {
    state = state.copyWith(
      session: state.session.copyWith(
        frontImage: imageBytes,
        currentStep: ScanStep.sideCapture,
      ),
      clearError: true,
    );
  }

  /// Capture side photo and begin processing using the V2 pipeline
  Future<void> captureSidePhoto(Uint8List imageBytes) async {
    state = state.copyWith(
      session: state.session.copyWith(
        sideImage: imageBytes,
        currentStep: ScanStep.processing,
      ),
      isProcessing: true,
      processingMessage: 'Analysing body pose...',
      clearError: true,
    );

    await _processImages();
  }

  /// Go back from side capture to front capture
  void goBackToFront() {
    state = state.copyWith(
      session: ScanSession(
        currentStep: ScanStep.frontCapture,
        userHeightCm: state.session.userHeightCm,
        calibrationMethod: state.session.calibrationMethod,
      ),
      clearError: true,
    );
  }

  /// Restart the entire scanning session
  void restartScan() {
    stabilizer.reset();
    state = const DigitalTailorState();
  }

  /// Clear error for side-scan retry; keep front photo + debug traces.
  void clearErrorKeepDebug() {
    state = state.copyWith(
      clearError: true,
      isProcessing: false,
      session: ScanSession(
        currentStep: ScanStep.sideCapture,
        frontImage: state.session.frontImage,
        userHeightCm: state.session.userHeightCm,
        calibrationMethod: state.session.calibrationMethod,
      ),
    );
  }

  /// Process images through pose detection, measurement, quality, and confidence.
  Future<void> _processImages() async {
    final frontImage = state.session.frontImage;
    final sideImage = state.session.sideImage;
    final heightCm = state.session.userHeightCm;

    if (frontImage == null || sideImage == null || heightCm == null) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Incomplete data. Please restart the scanning process.',
      );
      return;
    }

    state = state.copyWith(processingMessage: 'Analysing body pose...');

    final result = await processingService.process(
      frontImage: frontImage,
      sideImage: sideImage,
      heightCm: heightCm,
    );

    if (!result.isSuccess) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: result.errorMessage,
        retakeAttempts: state.retakeAttempts + 1,
        qualityReport: result.qualityReport,
        frontCalibration: result.frontCalibration,
        sideCalibration: result.sideCalibration,
        measurementDebug: result.measurementDebug,
        session: state.session.copyWith(
          currentStep: result.retryStep ?? ScanStep.frontCapture,
        ),
      );
      return;
    }

    state = state.copyWith(processingMessage: 'Validating results...');

    state = state.copyWith(
      isProcessing: false,
      result: result.scanResult,
      confidenceReport: result.confidenceReport,
      qualityReport: result.qualityReport,
      frontCalibration: result.frontCalibration,
      sideCalibration: result.sideCalibration,
      measurementDebug: result.measurementDebug,
      session: state.session.copyWith(currentStep: ScanStep.results),
    );
  }

  /// Save measurements to Firestore
  Future<void> saveMeasurements() async {
    final result = state.result;
    if (result == null) return;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await firestoreService.saveMeasurements(result);
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save: ${e.toString()}',
        saveAttempts: state.saveAttempts + 1,
      );
    }
  }

  /// Check if max retake attempts reached
  bool get maxRetakesReached => state.retakeAttempts >= 3;
}
