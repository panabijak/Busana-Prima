import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scan_result.dart';
import '../models/scan_session.dart';
import '../services/measurement_calculator.dart';
import '../services/measurement_firestore_service.dart';
import '../services/pose_detection_service.dart';

/// Provider for the Firestore measurement service
final measurementFirestoreServiceProvider = Provider((ref) {
  return MeasurementFirestoreService();
});

/// Provider for the pose detection service
final poseDetectionServiceProvider = Provider((ref) {
  final service = PoseDetectionService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the measurement calculator
final measurementCalculatorProvider = Provider((ref) {
  return MeasurementCalculator();
});

/// Main state notifier for the digital tailor scanning flow
final digitalTailorProvider =
    StateNotifierProvider<DigitalTailorNotifier, DigitalTailorState>((ref) {
      return DigitalTailorNotifier(
        poseService: ref.watch(poseDetectionServiceProvider),
        calculator: ref.watch(measurementCalculatorProvider),
        firestoreService: ref.watch(measurementFirestoreServiceProvider),
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

  const DigitalTailorState({
    this.session = const ScanSession(),
    this.result,
    this.isProcessing = false,
    this.isSaving = false,
    this.errorMessage,
    this.retakeAttempts = 0,
    this.saveAttempts = 0,
  });

  DigitalTailorState copyWith({
    ScanSession? session,
    ScanResult? result,
    bool? isProcessing,
    bool? isSaving,
    String? errorMessage,
    int? retakeAttempts,
    int? saveAttempts,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return DigitalTailorState(
      session: session ?? this.session,
      result: clearResult ? null : (result ?? this.result),
      isProcessing: isProcessing ?? this.isProcessing,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      retakeAttempts: retakeAttempts ?? this.retakeAttempts,
      saveAttempts: saveAttempts ?? this.saveAttempts,
    );
  }
}

/// Notifier managing the digital tailor scanning workflow
class DigitalTailorNotifier extends StateNotifier<DigitalTailorState> {
  final PoseDetectionService poseService;
  final MeasurementCalculator calculator;
  final MeasurementFirestoreService firestoreService;

  DigitalTailorNotifier({
    required this.poseService,
    required this.calculator,
    required this.firestoreService,
  }) : super(const DigitalTailorState());

  /// Set user height for calibration and proceed to front capture
  void setCalibration(double heightCm) {
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

  /// Capture side photo and begin processing
  Future<void> captureSidePhoto(Uint8List imageBytes) async {
    state = state.copyWith(
      session: state.session.copyWith(
        sideImage: imageBytes,
        currentStep: ScanStep.processing,
      ),
      isProcessing: true,
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
    state = const DigitalTailorState();
  }

  /// Process captured images through pose detection and measurement calculation
  Future<void> _processImages() async {
    final frontImage = state.session.frontImage;
    final sideImage = state.session.sideImage;
    final heightCm = state.session.userHeightCm;

    if (frontImage == null || sideImage == null || heightCm == null) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Data tidak lengkap. Silakan ulangi proses scanning.',
      );
      return;
    }

    // Detect front pose
    final frontResult = await poseService.detectPose(frontImage);

    // Check if front pose has usable data (success OR partial with pose)
    if (!frontResult.isSuccess && frontResult.pose == null) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage:
            frontResult.errorMessage ??
            'Gagal mendeteksi pose dari foto depan.',
        retakeAttempts: state.retakeAttempts + 1,
        session: state.session.copyWith(currentStep: ScanStep.frontCapture),
      );
      return;
    }

    // Detect side pose
    final sideResult = await poseService.detectPose(sideImage);

    // Check if side pose has usable data (success OR partial with pose)
    if (!sideResult.isSuccess && sideResult.pose == null) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage:
            sideResult.errorMessage ??
            'Gagal mendeteksi pose dari foto samping.',
        retakeAttempts: state.retakeAttempts + 1,
        session: state.session.copyWith(currentStep: ScanStep.sideCapture),
      );
      return;
    }

    // We have pose data from both images (either full or partial)
    final frontPose = frontResult.pose!;
    final sidePose = sideResult.pose!;
    final imageHeight = frontResult.imageHeight ?? 1920; // Default fallback

    // Calculate measurements
    try {
      final scanResult = calculator.calculate(
        frontPose: frontPose,
        sidePose: sidePose,
        userHeightCm: heightCm,
        frontImageHeight: imageHeight,
      );

      if (scanResult.measurements.isEmpty) {
        state = state.copyWith(
          isProcessing: false,
          errorMessage:
              'Tidak dapat mengira pengukuran. Pastikan seluruh tubuh terlihat jelas dalam kedua-dua foto.',
          retakeAttempts: state.retakeAttempts + 1,
          session: state.session.copyWith(currentStep: ScanStep.frontCapture),
        );
        return;
      }

      state = state.copyWith(
        isProcessing: false,
        result: scanResult,
        session: state.session.copyWith(currentStep: ScanStep.results),
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal menghitung pengukuran: ${e.toString()}',
        retakeAttempts: state.retakeAttempts + 1,
      );
    }
  }

  /// Save measurements to Firestore
  Future<void> saveMeasurements() async {
    final result = state.result;
    if (result == null) return;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await firestoreService.saveMeasurements(result);
      // Success - the profile stream will auto-update
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Gagal menyimpan: ${e.toString()}',
        saveAttempts: state.saveAttempts + 1,
      );
    }
  }

  /// Check if max retake attempts reached
  bool get maxRetakesReached => state.retakeAttempts >= 3;
}
