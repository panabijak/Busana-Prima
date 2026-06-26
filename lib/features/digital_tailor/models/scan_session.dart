import 'dart:typed_data';

/// Represents the current state of a scanning session.
class ScanSession {
  final ScanStep currentStep;
  final Uint8List? frontImage;
  final Uint8List? sideImage;
  final double? userHeightCm;
  final CalibrationMethod calibrationMethod;

  const ScanSession({
    this.currentStep = ScanStep.calibration,
    this.frontImage,
    this.sideImage,
    this.userHeightCm,
    this.calibrationMethod = CalibrationMethod.height,
  });

  ScanSession copyWith({
    ScanStep? currentStep,
    Uint8List? frontImage,
    Uint8List? sideImage,
    double? userHeightCm,
    CalibrationMethod? calibrationMethod,
  }) {
    return ScanSession(
      currentStep: currentStep ?? this.currentStep,
      frontImage: frontImage ?? this.frontImage,
      sideImage: sideImage ?? this.sideImage,
      userHeightCm: userHeightCm ?? this.userHeightCm,
      calibrationMethod: calibrationMethod ?? this.calibrationMethod,
    );
  }

  bool get hasFrontImage => frontImage != null;
  bool get hasSideImage => sideImage != null;
  bool get isComplete => hasFrontImage && hasSideImage;
}

/// Steps in the scanning workflow
enum ScanStep { calibration, frontCapture, sideCapture, processing, results }

/// Method used for pixel-to-cm calibration
enum CalibrationMethod { height, referenceObject }
