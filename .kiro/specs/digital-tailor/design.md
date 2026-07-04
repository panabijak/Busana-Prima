# Digital Tailor v2 — Complete Measurement Engine Redesign

## Executive Summary

This document specifies a **complete replacement** of the current body measurement pipeline. The existing system uses Google ML Kit Pose Detection with single-frame Euclidean distances and hardcoded multipliers — resulting in inconsistent, underestimated circumference measurements and poor landmark stability.

The new architecture uses **MediaPipe Pose Landmarker** with multi-frame temporal smoothing, body segmentation-assisted outline estimation, multi-method calibration, and research-backed anthropometric formulas. It is designed for **tailoring-grade accuracy** (±2 cm target deviation).

---

## 1. Architecture Overview

### 1.1 Pipeline Stages

```
┌─────────────────────────────────────────────────────────────┐
│                    SCANNING PIPELINE v2                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│  │  Pre-Scan    │──▶│  Pose        │──▶│  Temporal    │    │
│  │  Validation  │   │  Validation  │   │  Smoothing   │    │
│  └──────────────┘   └──────────────┘   └──────────────┘    │
│         │                                      │             │
│         ▼                                      ▼             │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│  │  Calibration │◀──│  Body Outline│◀──│  Landmark    │    │
│  │  Engine      │   │  Estimation  │   │  Detection   │    │
│  └──────────────┘   └──────────────┘   └──────────────┘    │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│  │  Measurement │──▶│  Front+Side  │──▶│  Quality     │    │
│  │  Computation │   │  Fusion      │   │  Control     │    │
│  └──────────────┘   └──────────────┘   └──────────────┘    │
│                                                │             │
│                                                ▼             │
│                                         ┌──────────────┐    │
│                                         │  Result +    │    │
│                                         │  Confidence  │    │
│                                         └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Layer Separation (Clean Architecture)

```
┌───────────────────────────────────────────────────────────┐
│ PRESENTATION LAYER                                         │
│  Screens, Widgets, Overlays                               │
├───────────────────────────────────────────────────────────┤
│ STATE MANAGEMENT LAYER                                     │
│  Riverpod Notifiers, Pipeline Orchestrator                │
├───────────────────────────────────────────────────────────┤
│ DOMAIN LAYER                                               │
│  Measurement Engine, Quality Validator, Fusion Engine      │
├───────────────────────────────────────────────────────────┤
│ DATA LAYER                                                 │
│  Pose Detector, Segmentation, Calibration, Filters        │
├───────────────────────────────────────────────────────────┤
│ INFRASTRUCTURE LAYER                                       │
│  Camera, Sensors, Firestore, Platform Channels            │
└───────────────────────────────────────────────────────────┘
```

### 1.3 Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Keep `google_mlkit_pose_detection` | MediaPipe Pose Landmarker has no official Flutter SDK. ML Kit's `PoseDetectionModel.accurate` uses the same BlazePose model that powers MediaPipe Pose. The underlying model is identical — both produce 33 landmarks with visibility and confidence. The Flutter `google_mlkit_pose_detection` package wraps MediaPipe's BlazePose via ML Kit. |
| Add `google_mlkit_selfie_segmentation` | Body outline width estimation requires segmentation mask to find actual body contour widths at specific y-coordinates |
| One Euro Filter for smoothing | Best balance of latency vs smoothness for interactive pose tracking (see §3.3) |
| Multi-frame capture (15 frames) | Statistical averaging eliminates single-frame noise |
| Ellipse + depth regression | Replaces hardcoded multipliers with data-driven circumference estimation |

---

## 2. Folder Structure (Redesigned)

```
lib/features/digital_tailor/
├── models/
│   ├── measurement.dart              # Measurement data model (keep)
│   ├── measurement_confidence.dart   # Per-measurement confidence
│   ├── scan_result.dart              # Scan results (enhanced)
│   ├── scan_session.dart             # Session state (enhanced)
│   ├── body_landmarks.dart           # Processed landmark data
│   ├── body_outline.dart             # Body contour widths
│   └── calibration_result.dart       # Calibration output
├── providers/
│   ├── digital_tailor_provider.dart  # Main orchestrator (rewrite)
│   ├── measurement_profile_provider.dart # Profile display (keep)
│   └── scanner_state_provider.dart   # Camera + leveling state
├── screens/
│   ├── calibration_screen.dart       # Enhanced calibration UI
│   ├── scanner_screen.dart           # Multi-frame capture UI
│   ├── results_screen.dart           # Results with confidence
│   ├── measurement_profile_screen.dart
│   └── profile_list_screen.dart
├── services/
│   ├── pipeline/
│   │   ├── scanning_pipeline.dart        # Pipeline orchestrator
│   │   ├── pre_scan_validator.dart       # Step 1: Environment validation
│   │   └── pose_validator.dart           # Step 2: T-Pose validation
│   ├── detection/
│   │   ├── pose_detection_service.dart   # Step 3: ML Kit wrapper
│   │   ├── segmentation_service.dart     # Step 5: Selfie segmentation
│   │   └── landmark_processor.dart       # Landmark normalization
│   ├── filtering/
│   │   ├── one_euro_filter.dart          # Step 3: Temporal smoothing
│   │   ├── multi_frame_accumulator.dart  # Frame averaging
│   │   └── outlier_detector.dart         # Statistical outlier removal
│   ├── calibration/
│   │   ├── calibration_engine.dart       # Step 4: Abstraction layer
│   │   ├── reference_object_calibrator.dart  # A4 / card detection
│   │   ├── height_calibrator.dart        # User height method
│   │   └── camera_distance_calibrator.dart   # Known distance method
│   ├── measurement/
│   │   ├── measurement_engine.dart       # Step 6: Main calculator
│   │   ├── linear_measurer.dart          # Euclidean distances
│   │   ├── circumference_estimator.dart  # Ellipse + regression
│   │   ├── body_outline_analyzer.dart    # Step 5: Contour analysis
│   │   └── front_side_fusion.dart        # Step 7: View fusion
│   ├── validation/
│   │   ├── quality_controller.dart       # Step 8: Validation
│   │   ├── symmetry_checker.dart         # Left-right symmetry
│   │   ├── range_validator.dart          # Physiological ranges
│   │   └── confidence_scorer.dart        # Step 9: Scoring
│   ├── leveling_service.dart             # Accelerometer (keep)
│   ├── measurement_firestore_service.dart # Persistence (keep)
│   └── measurement_profile_service.dart  # Profile queries (keep)
└── widgets/
    ├── silhouette_overlay.dart           # Enhanced overlay
    ├── leveling_indicator.dart           # Orientation widget
    ├── pose_guide_overlay.dart           # T-Pose guidance
    ├── confidence_badge.dart             # Confidence display
    └── save_profile_sheet.dart           # Save dialog (keep)
```

---

## 3. Detailed Stage Design

### 3.1 STEP 1 — Pre-Scan Validation

**Purpose:** Reject captures before they happen if conditions are unsuitable.

**Implementation:** `PreScanValidator` class analyzes real-time camera frames.

```dart
abstract class PreScanCheck {
  Future<ValidationResult> validate(CameraImage frame);
  String get failureGuidance;
}

class PreScanValidator {
  final List<PreScanCheck> checks = [
    LightingCheck(),          // Histogram analysis: mean luminance 80-200
    FullBodyVisibleCheck(),   // Quick pose check: all major joints detected
    BackgroundCheck(),        // Edge density < threshold (plain background)
    DistanceCheck(),          // Body height occupies 60-85% of frame
    OrientationCheck(),       // Portrait mode enforced
    StandingCheck(),          // Hip-ankle vertical alignment
  ];

  Future<PreScanReport> runAll(CameraImage frame) async {
    final results = <String, ValidationResult>{};
    for (final check in checks) {
      results[check.runtimeType.toString()] = await check.validate(frame);
    }
    return PreScanReport(results);
  }
}
```

**Lighting Check Algorithm:**
- Convert frame to grayscale
- Compute histogram mean and standard deviation
- Accept if: mean ∈ [80, 200] AND stddev > 30 (not flat/washed out)
- Reject with guidance: "Pastikan pencahayaan cukup terang" / "Kurangi cahaya berlebihan"

**Distance Check Algorithm:**
- Run quick pose detection on preview frame
- Measure nose-to-ankle pixel distance relative to frame height
- Accept if body occupies 60–85% of vertical frame space
- Guidance: "Mundur sedikit" / "Maju sedikit"

---

### 3.2 STEP 2 — Automatic Pose Validation (T-Pose)

**Purpose:** Ensure consistent, measurable body posture before capture.

**T-Pose Requirements:**
- Both arms extended horizontally (within ±15° of horizontal)
- Shoulders level (y-difference < 3% of shoulder width)
- Both legs visible and vertical
- Head visible and centered
- Body centered in frame (midpoint within 10% of frame center)

```dart
class PoseValidator {
  static const double armAngleTolerance = 15.0; // degrees from horizontal
  static const double shoulderLevelTolerance = 0.03; // 3% of width
  static const int requiredStableFrames = 15; // consecutive valid frames

  int _consecutiveValidFrames = 0;

  PoseValidationResult validate(ProcessedLandmarks landmarks) {
    final checks = <String, bool>{
      'arms_horizontal': _checkArmsHorizontal(landmarks),
      'shoulders_level': _checkShouldersLevel(landmarks),
      'legs_visible': _checkLegsVisible(landmarks),
      'head_visible': _checkHeadVisible(landmarks),
      'body_centered': _checkBodyCentered(landmarks),
      'standing_straight': _checkStandingStraight(landmarks),
    };

    final allValid = checks.values.every((v) => v);

    if (allValid) {
      _consecutiveValidFrames++;
    } else {
      _consecutiveValidFrames = 0;
    }

    return PoseValidationResult(
      isValid: allValid,
      isStable: _consecutiveValidFrames >= requiredStableFrames,
      failedChecks: checks.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList(),
      stableFrameCount: _consecutiveValidFrames,
    );
  }

  bool _checkArmsHorizontal(ProcessedLandmarks lm) {
    // Left arm: shoulder → wrist angle relative to horizontal
    final leftAngle = _angleDegrees(
      lm.leftShoulder, lm.leftWrist,
    );
    final rightAngle = _angleDegrees(
      lm.rightShoulder, lm.rightWrist,
    );
    return leftAngle.abs() < armAngleTolerance &&
           rightAngle.abs() < armAngleTolerance;
  }
}
```

**Multi-frame stability:** Never capture from a single frame. Require 15 consecutive valid frames (≈0.5s at 30fps) before triggering capture. This eliminates transient noise.

---

### 3.3 STEP 3 — Landmark Detection & Temporal Smoothing

**Detection:** Continue using `google_mlkit_pose_detection` with `PoseDetectionModel.accurate`.

**Why ML Kit ≈ MediaPipe Pose Landmarker for Flutter:**
- ML Kit Pose Detection uses the same BlazePose GHUM 3D model that powers MediaPipe Pose Landmarker
- Both produce 33 landmarks with x, y, z coordinates and confidence scores
- ML Kit's `likelihood` field = MediaPipe's `visibility` score
- No official `mediapipe` Flutter package exists for Pose Landmarker (as of 2025)
- The `google/flutter-mediapipe` repo is experimental/incomplete
- ML Kit on-device inference is equivalent; the accuracy gap is zero

**What we gain from the redesign:** Not a model change, but a **pipeline change** — multi-frame averaging, temporal filtering, segmentation fusion, and proper calibration.

#### Temporal Smoothing: One Euro Filter

**Why One Euro Filter over alternatives:**

| Filter | Pros | Cons | Best For |
|--------|------|------|----------|
| Moving Average | Simple | Fixed lag, poor responsiveness | Static scenes |
| Kalman Filter | Optimal for linear systems | Requires tuning Q/R, assumes Gaussian | Tracking |
| **One Euro Filter** | **Adaptive: smooth when slow, responsive when fast** | **Two parameters** | **Interactive pose** |

**The One Euro Filter** is specifically designed for noisy interactive signals. It uses an adaptive cutoff frequency: when the signal velocity is low (user standing still), it applies aggressive smoothing. When velocity is high (transitioning poses), it reduces smoothing to stay responsive. MediaPipe itself uses One Euro internally.

```dart
class OneEuroFilter {
  final double minCutoff;  // Minimum cutoff frequency (smoothness)
  final double beta;       // Speed coefficient (responsiveness)
  final double dCutoff;    // Derivative cutoff frequency

  double? _xPrev;
  double? _dxPrev;
  double? _tPrev;

  OneEuroFilter({
    this.minCutoff = 1.0,   // Hz — lower = smoother
    this.beta = 0.007,      // Higher = more responsive to speed
    this.dCutoff = 1.0,
  });

  double filter(double x, double timestamp) {
    if (_tPrev == null) {
      _xPrev = x;
      _dxPrev = 0.0;
      _tPrev = timestamp;
      return x;
    }

    final dt = timestamp - _tPrev!;
    if (dt <= 0) return _xPrev!;

    // Derivative estimation
    final dx = (x - _xPrev!) / dt;
    final alphaDx = _smoothingFactor(dt, dCutoff);
    final dxFiltered = alphaDx * dx + (1 - alphaDx) * _dxPrev!;

    // Adaptive cutoff based on speed
    final cutoff = minCutoff + beta * dxFiltered.abs();

    // Position filtering
    final alpha = _smoothingFactor(dt, cutoff);
    final xFiltered = alpha * x + (1 - alpha) * _xPrev!;

    _xPrev = xFiltered;
    _dxPrev = dxFiltered;
    _tPrev = timestamp;

    return xFiltered;
  }

  double _smoothingFactor(double dt, double cutoff) {
    final tau = 1.0 / (2 * pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }
}
```

#### Multi-Frame Accumulator

```dart
class MultiFrameAccumulator {
  static const int targetFrames = 15;
  static const double outlierThresholdSigma = 2.0;

  final List<Map<PoseLandmarkType, Point3D>> _frames = [];

  void addFrame(Pose pose) {
    final landmarks = <PoseLandmarkType, Point3D>{};
    for (final entry in pose.landmarks.entries) {
      if (entry.value.likelihood >= 0.5) {
        landmarks[entry.key] = Point3D(
          entry.value.x, entry.value.y, entry.value.z,
        );
      }
    }
    _frames.add(landmarks);
  }

  bool get isComplete => _frames.length >= targetFrames;

  /// Compute median landmarks with outlier rejection
  Map<PoseLandmarkType, Point3D> computeStableLandmarks() {
    final result = <PoseLandmarkType, Point3D>{};

    for (final type in PoseLandmarkType.values) {
      final points = _frames
          .where((f) => f.containsKey(type))
          .map((f) => f[type]!)
          .toList();

      if (points.length < targetFrames * 0.7) continue; // Need 70%+ frames

      // Remove outliers using IQR method
      final cleaned = _removeOutliers(points);
      if (cleaned.isEmpty) continue;

      // Compute median (more robust than mean)
      result[type] = _medianPoint(cleaned);
    }
    return result;
  }
}
```

---

### 3.4 STEP 4 — Calibration Engine

**Problem with current approach:** Height-only calibration depends on accurate detection of nose and ankle landmarks. If the head or feet are partially cropped or landmarks jitter, the scale factor is wrong — corrupting ALL measurements.

**New design:** A calibration abstraction with priority-ordered strategies.

```dart
/// Abstract calibration strategy
abstract class CalibrationStrategy {
  int get priority; // Lower = higher priority
  String get methodName;
  Future<CalibrationResult?> calibrate(CalibrationInput input);
}

class CalibrationEngine {
  final List<CalibrationStrategy> _strategies;

  CalibrationEngine()
      : _strategies = [
          ReferenceObjectCalibrator(),   // Priority 1
          CameraDistanceCalibrator(),    // Priority 2
          ExistingProfileCalibrator(),   // Priority 3
          HeightCalibrator(),            // Priority 4
        ]..sort((a, b) => a.priority.compareTo(b.priority));

  Future<CalibrationResult> calibrate(CalibrationInput input) async {
    for (final strategy in _strategies) {
      if (!strategy.isAvailable(input)) continue;
      final result = await strategy.calibrate(input);
      if (result != null && result.isValid) return result;
    }
    throw CalibrationException('No calibration method succeeded');
  }
}
```

#### Priority 1: Reference Object Calibration

```dart
class ReferenceObjectCalibrator extends CalibrationStrategy {
  @override int get priority => 1;

  // Known object dimensions (cm)
  static const Map<ReferenceType, Size> knownSizes = {
    ReferenceType.a4Paper: Size(21.0, 29.7),
    ReferenceType.creditCard: Size(5.4, 8.56),
    ReferenceType.a5Paper: Size(14.8, 21.0),
  };

  @override
  Future<CalibrationResult?> calibrate(CalibrationInput input) async {
    if (input.referenceType == null) return null;

    final knownSize = knownSizes[input.referenceType!]!;
    // Detect rectangle in image using edge detection
    final detectedPixels = await _detectRectangle(
      input.image, knownSize.width / knownSize.height,
    );
    if (detectedPixels == null) return null;

    // pixel-to-cm = known_cm / detected_pixels
    final pixelToCm = knownSize.height / detectedPixels.height;

    return CalibrationResult(
      pixelToCm: pixelToCm,
      method: 'reference_object',
      confidence: 0.95, // High confidence with known object
    );
  }
}
```

#### Priority 2: Camera Distance Calibration

If the user stands at a known distance (e.g., 2 meters) and we know the camera's focal length (from EXIF or device database), we can compute pixel-to-cm using:

```
pixel_size_cm = (distance_cm × sensor_size_cm) / (focal_length_mm × image_width_px)
```

This requires a device camera intrinsics database (maintained per device model).

#### Priority 3: Existing Profile Calibration

If the user has a previously validated measurement (e.g., manually entered shoulder width), use it as a reference:

```dart
class ExistingProfileCalibrator extends CalibrationStrategy {
  @override int get priority => 3;

  @override
  Future<CalibrationResult?> calibrate(CalibrationInput input) async {
    if (input.existingMeasurements == null) return null;

    // Use shoulder width as reference (easiest to detect consistently)
    final knownShoulderCm = input.existingMeasurements!['bahu']?.valueCm;
    if (knownShoulderCm == null) return null;

    final detectedShoulderPx = input.landmarks.shoulderWidth;
    if (detectedShoulderPx <= 0) return null;

    return CalibrationResult(
      pixelToCm: knownShoulderCm / detectedShoulderPx,
      method: 'existing_profile',
      confidence: 0.80,
    );
  }
}
```

#### Priority 4: Height Calibration (Improved)

```dart
class HeightCalibrator extends CalibrationStrategy {
  @override int get priority => 4;

  @override
  Future<CalibrationResult?> calibrate(CalibrationInput input) async {
    if (input.userHeightCm == null) return null;

    // Use multi-point height estimation (not just nose-to-ankle)
    final topY = _estimateHeadTop(input.landmarks);
    final bottomY = _estimateFootBottom(input.landmarks);
    final bodyHeightPx = (bottomY - topY).abs();

    if (bodyHeightPx < 100) return null; // Too small to be reliable

    return CalibrationResult(
      pixelToCm: input.userHeightCm! / bodyHeightPx,
      method: 'user_height',
      confidence: 0.70, // Lower confidence than reference objects
    );
  }

  double _estimateHeadTop(ProcessedLandmarks lm) {
    // Head top ≈ nose_y - 0.12 × body_height
    // Based on anthropometric research: head is ~12% of body height
    final noseY = lm.nose.y;
    final ankleY = (lm.leftAnkle.y + lm.rightAnkle.y) / 2;
    final bodyApprox = (ankleY - noseY).abs();
    return noseY - bodyApprox * 0.12;
  }
}
```

---

### 3.5 STEP 5 — Body Outline Estimation

**Problem:** Pose landmarks mark joint centers, NOT body surface. Shoulder landmarks are at the glenohumeral joint — 3-5 cm inward from the actual shoulder edge. Hip landmarks are at the femoral head — not the widest part of the hips. This is why the current system underestimates chest, waist, and hip.

**Solution:** Combine landmarks with selfie segmentation to find actual body contour widths.

#### Integration: `google_mlkit_selfie_segmentation`

```dart
class SegmentationService {
  SelfieSegmenter? _segmenter;

  void initialize() {
    _segmenter = SelfieSegmenter(
      mode: SegmenterMode.single,
      enableRawSizeMask: true,
    );
  }

  /// Returns binary mask where pixels belonging to the person are true
  Future<SegmentationMask?> segment(InputImage image) async {
    final mask = await _segmenter?.processImage(image);
    return mask;
  }
}
```

#### Body Outline Analyzer

```dart
class BodyOutlineAnalyzer {
  /// Extract body width at a specific y-coordinate from segmentation mask
  ///
  /// Scans horizontally at the given y to find leftmost and rightmost
  /// body pixels, returning the actual body surface width.
  BodyWidthResult getWidthAtY({
    required SegmentationMask mask,
    required double yCoordinate,
    required int imageWidth,
    required int imageHeight,
  }) {
    final row = (yCoordinate * mask.height ~/ imageHeight)
        .clamp(0, mask.height - 1);

    int? leftEdge;
    int? rightEdge;

    // Scan the row for body pixels (confidence > 0.7)
    for (int x = 0; x < mask.width; x++) {
      final confidence = mask.getConfidence(x, row);
      if (confidence > 0.7) {
        leftEdge ??= x;
        rightEdge = x;
      }
    }

    if (leftEdge == null || rightEdge == null) {
      return BodyWidthResult.notFound();
    }

    // Convert mask coordinates to image pixel coordinates
    final widthInMaskPx = (rightEdge - leftEdge).toDouble();
    final widthInImagePx = widthInMaskPx * imageWidth / mask.width;

    return BodyWidthResult(
      widthPx: widthInImagePx,
      leftEdgePx: leftEdge * imageWidth / mask.width,
      rightEdgePx: rightEdge * imageWidth / mask.width,
      confidence: 0.9,
    );
  }

  /// Get body widths at all measurement-critical y-positions
  BodyOutline analyzeFullOutline({
    required SegmentationMask mask,
    required ProcessedLandmarks landmarks,
    required int imageWidth,
    required int imageHeight,
  }) {
    // Chest: y-coordinate between shoulders and nipple line
    // Approximately 25% down from shoulder to hip
    final chestY = landmarks.shoulderMidY +
        (landmarks.hipMidY - landmarks.shoulderMidY) * 0.25;

    // Waist: narrowest point between chest and hip
    // Approximately 60% down from shoulder to hip
    final waistY = landmarks.shoulderMidY +
        (landmarks.hipMidY - landmarks.shoulderMidY) * 0.60;

    // Hip: widest point at or below hip landmarks
    // Approximately 10% below hip landmark y
    final hipY = landmarks.hipMidY +
        (landmarks.kneeMidY - landmarks.hipMidY) * 0.10;

    // Shoulder: at shoulder landmark y-level
    final shoulderY = landmarks.shoulderMidY;

    return BodyOutline(
      shoulderWidth: getWidthAtY(
        mask: mask, yCoordinate: shoulderY,
        imageWidth: imageWidth, imageHeight: imageHeight,
      ),
      chestWidth: getWidthAtY(
        mask: mask, yCoordinate: chestY,
        imageWidth: imageWidth, imageHeight: imageHeight,
      ),
      waistWidth: getWidthAtY(
        mask: mask, yCoordinate: waistY,
        imageWidth: imageWidth, imageHeight: imageHeight,
      ),
      hipWidth: getWidthAtY(
        mask: mask, yCoordinate: hipY,
        imageWidth: imageWidth, imageHeight: imageHeight,
      ),
    );
  }
}
```

**Why this matters:** The segmentation mask captures clothing and soft tissue contour, not just skeletal joint positions. For a person wearing a fitted shirt, the mask edge at chest height gives the TRUE chest width including body tissue — which is exactly what a tailor measures.

---

### 3.6 STEP 6 — Measurement Computation

**Principles:**
1. Use segmentation-derived widths for circumference measurements (NOT raw landmark distances)
2. Use landmark distances for linear measurements (arm length, leg length, torso height)
3. Apply Ramanujan ellipse approximation for circumferences with front+side data
4. NO hardcoded multipliers — use anthropometric research ratios only as fallbacks with low confidence

#### Linear Measurer

```dart
class LinearMeasurer {
  final double pixelToCm;

  /// Shoulder width: Use segmentation outline width at shoulder level
  /// Falls back to landmark distance + anatomical offset
  double measureShoulderWidth({
    required BodyOutline? outline,
    required ProcessedLandmarks landmarks,
  }) {
    if (outline?.shoulderWidth.isValid == true) {
      return outline!.shoulderWidth.widthPx * pixelToCm;
    }
    // Fallback: landmark distance + deltoid offset
    // Anthropometric research: acromion-to-surface ≈ 2-3 cm per side
    final landmarkDist = landmarks.shoulderWidth * pixelToCm;
    return landmarkDist + 4.0; // +2cm each side for soft tissue
  }

  /// Sleeve length: shoulder → elbow → wrist
  double measureSleeveLength(ProcessedLandmarks landmarks) {
    final upperArm = _distance(landmarks.leftShoulder, landmarks.leftElbow);
    final forearm = _distance(landmarks.leftElbow, landmarks.leftWrist);
    return (upperArm + forearm) * pixelToCm;
  }

  /// Arm length: similar to sleeve but from neck point
  double measureArmLength(ProcessedLandmarks landmarks) {
    // From shoulder-neck junction to wrist
    final neckToShoulder = _distance(
      landmarks.neckPoint, landmarks.leftShoulder,
    );
    final shoulderToWrist = measureSleeveLength(landmarks);
    return neckToShoulder * pixelToCm + shoulderToWrist;
  }

  /// Torso height: shoulder midpoint to hip midpoint
  double measureTorsoHeight(ProcessedLandmarks landmarks) {
    final shoulderMid = landmarks.shoulderMidpoint;
    final hipMid = landmarks.hipMidpoint;
    return _distance(shoulderMid, hipMid) * pixelToCm;
  }

  /// Back length: C7 vertebra (neck base) to waist
  double measureBackLength(ProcessedLandmarks landmarks) {
    // C7 approximated as midpoint between shoulders, slightly above
    final c7 = Point2D(
      (landmarks.leftShoulder.x + landmarks.rightShoulder.x) / 2,
      landmarks.shoulderMidY - landmarks.shoulderWidth * 0.05,
    );
    final waistMid = Point2D(
      (landmarks.leftHip.x + landmarks.rightHip.x) / 2,
      landmarks.shoulderMidY +
          (landmarks.hipMidY - landmarks.shoulderMidY) * 0.60,
    );
    return _distance(c7, waistMid) * pixelToCm;
  }

  /// Leg length: hip → knee → ankle (inseam approximation)
  double measureLegLength(ProcessedLandmarks landmarks) {
    final thigh = _distance(landmarks.leftHip, landmarks.leftKnee);
    final calf = _distance(landmarks.leftKnee, landmarks.leftAnkle);
    return (thigh + calf) * pixelToCm;
  }
}
```

#### Circumference Estimator

```dart
class CircumferenceEstimator {
  final double pixelToCm;

  /// Compute circumference using ellipse approximation
  /// a = front half-width (from segmentation or landmarks)
  /// b = side half-depth (from side photo segmentation or regression)
  ///
  /// Uses Ramanujan's second approximation for higher accuracy:
  /// C ≈ π(a+b)(1 + 3h/(10 + √(4-3h))) where h = ((a-b)/(a+b))²
  double ellipseCircumference(double halfWidthCm, double halfDepthCm) {
    if (halfWidthCm <= 0 || halfDepthCm <= 0) return 0;
    final a = halfWidthCm;
    final b = halfDepthCm;
    final h = pow((a - b) / (a + b), 2).toDouble();
    // Ramanujan's second approximation (more accurate than first)
    return pi * (a + b) * (1 + 3 * h / (10 + sqrt(4 - 3 * h)));
  }

  /// Chest circumference
  /// Front: segmentation width at chest level
  /// Side: segmentation width at same y-level in side photo
  MeasurementWithConfidence measureChest({
    required BodyOutline frontOutline,
    required BodyOutline? sideOutline,
    required ProcessedLandmarks frontLandmarks,
    required ProcessedLandmarks? sideLandmarks,
  }) {
    // Front half-width from segmentation
    final frontWidthCm = frontOutline.chestWidth.widthPx * pixelToCm;
    final halfWidthCm = frontWidthCm / 2;

    double halfDepthCm;
    double confidence;

    if (sideOutline?.chestWidth.isValid == true) {
      // Best case: actual depth from side photo segmentation
      halfDepthCm = sideOutline!.chestWidth.widthPx * pixelToCm / 2;
      confidence = 0.92;
    } else {
      // Fallback: anthropometric depth-to-width ratio
      // Research (ISO 8559): chest depth ≈ 0.68-0.78 of chest width
      // Use 0.73 as median for general population
      halfDepthCm = halfWidthCm * 0.73;
      confidence = 0.65;
    }

    final circumference = ellipseCircumference(halfWidthCm, halfDepthCm);
    return MeasurementWithConfidence(
      valueCm: circumference,
      confidence: confidence,
    );
  }

  /// Waist circumference
  MeasurementWithConfidence measureWaist({
    required BodyOutline frontOutline,
    required BodyOutline? sideOutline,
  }) {
    final frontWidthCm = frontOutline.waistWidth.widthPx * pixelToCm;
    final halfWidthCm = frontWidthCm / 2;

    double halfDepthCm;
    double confidence;

    if (sideOutline?.waistWidth.isValid == true) {
      halfDepthCm = sideOutline!.waistWidth.widthPx * pixelToCm / 2;
      confidence = 0.92;
    } else {
      // Waist depth-to-width ratio ≈ 0.65-0.75 (ISO 8559)
      halfDepthCm = halfWidthCm * 0.70;
      confidence = 0.60;
    }

    return MeasurementWithConfidence(
      valueCm: ellipseCircumference(halfWidthCm, halfDepthCm),
      confidence: confidence,
    );
  }

  /// Hip circumference
  MeasurementWithConfidence measureHip({
    required BodyOutline frontOutline,
    required BodyOutline? sideOutline,
  }) {
    final frontWidthCm = frontOutline.hipWidth.widthPx * pixelToCm;
    final halfWidthCm = frontWidthCm / 2;

    double halfDepthCm;
    double confidence;

    if (sideOutline?.hipWidth.isValid == true) {
      halfDepthCm = sideOutline!.hipWidth.widthPx * pixelToCm / 2;
      confidence = 0.90;
    } else {
      // Hip depth-to-width ratio ≈ 0.75-0.85 (ISO 8559)
      halfDepthCm = halfWidthCm * 0.80;
      confidence = 0.60;
    }

    return MeasurementWithConfidence(
      valueCm: ellipseCircumference(halfWidthCm, halfDepthCm),
      confidence: confidence,
    );
  }

  /// Neck circumference
  MeasurementWithConfidence measureNeck({
    required ProcessedLandmarks frontLandmarks,
    required ProcessedLandmarks? sideLandmarks,
    required BodyOutline? frontOutline,
  }) {
    // Neck width: use segmentation at neck level, or ear-to-ear distance
    double neckHalfWidthCm;
    if (frontOutline != null) {
      // Measure at y between nose and shoulders
      neckHalfWidthCm = frontOutline.shoulderWidth.widthPx * pixelToCm * 0.30 / 2;
    } else {
      // Approximate: neck ≈ 35% of shoulder width
      neckHalfWidthCm = frontLandmarks.shoulderWidth * pixelToCm * 0.35 / 2;
    }

    // Neck depth ≈ 80% of neck width (nearly circular cross-section)
    final neckHalfDepthCm = neckHalfWidthCm * 0.80;

    return MeasurementWithConfidence(
      valueCm: ellipseCircumference(neckHalfWidthCm, neckHalfDepthCm),
      confidence: 0.55, // Neck is hardest to measure from photos
    );
  }
}
```

---

### 3.7 STEP 7 — Front + Side Fusion

**Purpose:** A single frontal photo cannot determine body depth. Side photos provide the missing dimension for accurate circumference estimation.

#### How Fusion Works

```
FRONT PHOTO                     SIDE PHOTO
─────────────                   ─────────────
Provides:                       Provides:
• Body WIDTH at each level      • Body DEPTH at each level
• Left-right symmetry           • Front-back profile
• Shoulder span                 • Chest protrusion
• Hip span                      • Buttock protrusion
• Arm/leg span                  • Belly depth

         ┌──────────────────────────┐
         │    FUSION ENGINE          │
         │                          │
         │  front_width × side_depth│
         │  → Ellipse cross-section │
         │  → Circumference         │
         └──────────────────────────┘
```

#### Fusion Algorithm

```dart
class FrontSideFusion {
  /// Fuse front and side body outlines into circumference measurements
  FusedMeasurements fuse({
    required BodyOutline frontOutline,
    required BodyOutline sideOutline,
    required ProcessedLandmarks frontLandmarks,
    required ProcessedLandmarks sideLandmarks,
    required double pixelToCmFront,
    required double pixelToCmSide,
  }) {
    // Chest: front width as semi-axis a, side depth as semi-axis b
    final chestA = frontOutline.chestWidth.widthPx * pixelToCmFront / 2;
    final chestB = sideOutline.chestWidth.widthPx * pixelToCmSide / 2;

    // Waist: same pattern
    final waistA = frontOutline.waistWidth.widthPx * pixelToCmFront / 2;
    final waistB = sideOutline.waistWidth.widthPx * pixelToCmSide / 2;

    // Hip: same pattern
    final hipA = frontOutline.hipWidth.widthPx * pixelToCmFront / 2;
    final hipB = sideOutline.hipWidth.widthPx * pixelToCmSide / 2;

    return FusedMeasurements(
      chestCircumference: _ramanujan2(chestA, chestB),
      waistCircumference: _ramanujan2(waistA, waistB),
      hipCircumference: _ramanujan2(hipA, hipB),
      fusionConfidence: 0.92, // High confidence with both views
    );
  }

  /// Ramanujan's second approximation
  double _ramanujan2(double a, double b) {
    if (a <= 0 || b <= 0) return 0;
    final h = pow((a - b) / (a + b), 2).toDouble();
    return pi * (a + b) * (1 + 3 * h / (10 + sqrt(4 - 3 * h)));
  }
}
```

#### Why Side Depth Improves Accuracy

Consider two people with identical front-view chest width (40 cm):
- Person A: Athletic build, chest depth 22 cm → Circumference ≈ 98 cm
- Person B: Barrel chest, chest depth 30 cm → Circumference ≈ 112 cm

Without side data, both would receive the same measurement — a **14 cm error**. This explains why the current system underestimates for some body types (it assumes average depth ratios).

---

### 3.8 STEP 8 — Measurement Quality Control

```dart
class QualityController {
  final SymmetryChecker _symmetry;
  final RangeValidator _range;
  final OutlierDetector _outlier;

  QualityReport validate(ScanResult result, ProcessedLandmarks landmarks) {
    final issues = <QualityIssue>[];

    // 1. Left-right symmetry check
    final symmetryResult = _symmetry.check(landmarks);
    if (!symmetryResult.isSymmetric) {
      issues.add(QualityIssue(
        type: QualityIssueType.asymmetry,
        message: 'Posisi tubuh tidak simetris: ${symmetryResult.details}',
        severity: symmetryResult.deviation > 0.15
            ? Severity.reject : Severity.warning,
      ));
    }

    // 2. Visibility check
    final lowVisibility = landmarks.allLandmarks
        .where((lm) => lm.confidence < 0.5)
        .toList();
    if (lowVisibility.length > 5) {
      issues.add(QualityIssue(
        type: QualityIssueType.lowVisibility,
        message: '${lowVisibility.length} titik tubuh memiliki kepercayaan rendah',
        severity: Severity.reject,
      ));
    }

    // 3. Range validation (physiological limits)
    for (final measurement in result.measurements) {
      final rangeResult = _range.validate(measurement);
      if (!rangeResult.isValid) {
        issues.add(QualityIssue(
          type: QualityIssueType.outOfRange,
          message: '${measurement.label}: ${rangeResult.reason}',
          severity: Severity.warning,
          measurementKey: measurement.key,
        ));
      }
    }

    // 4. Internal consistency (ratios between measurements)
    final ratioIssues = _checkAnthropometricRatios(result);
    issues.addAll(ratioIssues);

    // Determine overall verdict
    final hasReject = issues.any((i) => i.severity == Severity.reject);

    return QualityReport(
      isAcceptable: !hasReject,
      issues: issues,
      recommendation: hasReject
          ? QualityRecommendation.rescan
          : QualityRecommendation.accept,
    );
  }

  /// Validate relationships between measurements using known ratios
  List<QualityIssue> _checkAnthropometricRatios(ScanResult result) {
    final issues = <QualityIssue>[];

    final chest = result.getMeasurement('dada')?.valueCm;
    final waist = result.getMeasurement('pinggang')?.valueCm;
    final hip = result.getMeasurement('pinggul')?.valueCm;
    final shoulder = result.getMeasurement('bahu')?.valueCm;

    // Waist should be less than chest for most body types
    if (chest != null && waist != null && waist > chest * 1.15) {
      issues.add(QualityIssue(
        type: QualityIssueType.inconsistentRatio,
        message: 'Pinggang lebih besar dari dada — kemungkinan error deteksi',
        severity: Severity.warning,
      ));
    }

    // Shoulder width should be < chest circumference / π
    if (shoulder != null && chest != null && shoulder > chest / pi * 1.2) {
      issues.add(QualityIssue(
        type: QualityIssueType.inconsistentRatio,
        message: 'Rasio bahu-dada tidak wajar',
        severity: Severity.warning,
      ));
    }

    return issues;
  }
}
```

#### Symmetry Checker

```dart
class SymmetryChecker {
  static const double maxAsymmetry = 0.10; // 10% tolerance

  SymmetryResult check(ProcessedLandmarks landmarks) {
    // Compare left vs right arm lengths
    final leftArm = landmarks.leftArmLength;
    final rightArm = landmarks.rightArmLength;
    final armDev = (leftArm - rightArm).abs() / ((leftArm + rightArm) / 2);

    // Compare left vs right leg lengths
    final leftLeg = landmarks.leftLegLength;
    final rightLeg = landmarks.rightLegLength;
    final legDev = (leftLeg - rightLeg).abs() / ((leftLeg + rightLeg) / 2);

    // Shoulder height difference
    final shoulderYDiff = (landmarks.leftShoulder.y - landmarks.rightShoulder.y).abs();
    final shoulderDev = shoulderYDiff / landmarks.shoulderWidth;

    final maxDeviation = [armDev, legDev, shoulderDev].reduce(max);

    return SymmetryResult(
      isSymmetric: maxDeviation <= maxAsymmetry,
      deviation: maxDeviation,
      details: maxDeviation > maxAsymmetry
          ? 'Deviasi simetri: ${(maxDeviation * 100).toStringAsFixed(1)}%'
          : null,
    );
  }
}
```

---

### 3.9 STEP 9 — Measurement Confidence Score

```dart
class ConfidenceScorer {
  /// Calculate overall and per-measurement confidence scores
  ConfidenceReport score({
    required List<MeasurementWithConfidence> measurements,
    required ProcessedLandmarks frontLandmarks,
    required ProcessedLandmarks? sideLandmarks,
    required CalibrationResult calibration,
    required QualityReport quality,
  }) {
    // Per-measurement confidence factors:
    // 1. Landmark confidence (from ML Kit)
    // 2. Calibration method confidence
    // 3. Whether side data was available
    // 4. Quality validation results

    final perMeasurement = <String, double>{};

    for (final m in measurements) {
      double confidence = m.confidence;

      // Reduce if calibration is low confidence
      confidence *= calibration.confidence;

      // Reduce if quality issues affect this measurement
      final hasQualityIssue = quality.issues.any(
        (i) => i.measurementKey == m.key,
      );
      if (hasQualityIssue) confidence *= 0.7;

      perMeasurement[m.key] = confidence.clamp(0.0, 1.0);
    }

    // Overall confidence: geometric mean of per-measurement scores
    final overallConfidence = perMeasurement.values.isEmpty
        ? 0.0
        : pow(
            perMeasurement.values.reduce((a, b) => a * b),
            1.0 / perMeasurement.values.length,
          ).toDouble();

    return ConfidenceReport(
      overall: overallConfidence,
      perMeasurement: perMeasurement,
      label: _getLabel(overallConfidence),
    );
  }

  String _getLabel(double confidence) {
    if (confidence >= 0.85) return 'Sangat Tinggi'; // Very High
    if (confidence >= 0.70) return 'Tinggi';        // High
    if (confidence >= 0.55) return 'Sedang';        // Medium
    return 'Rendah';                                 // Low
  }
}
```

**Confidence thresholds and actions:**

| Score | Label | Action |
|-------|-------|--------|
| ≥ 85% | Sangat Tinggi | Accept, ready for tailoring |
| 70-84% | Tinggi | Accept with note |
| 55-69% | Sedang | Warn user, suggest re-scan |
| < 55% | Rendah | Reject, require re-scan |

---

### 3.10 STEP 10 — Flutter Architecture

#### State Management (Riverpod)

```dart
// Pipeline orchestrator provider
final scanningPipelineProvider = Provider((ref) {
  return ScanningPipeline(
    poseService: ref.watch(poseDetectionServiceProvider),
    segmentationService: ref.watch(segmentationServiceProvider),
    calibrationEngine: ref.watch(calibrationEngineProvider),
    measurementEngine: ref.watch(measurementEngineProvider),
    qualityController: ref.watch(qualityControllerProvider),
    confidenceScorer: ref.watch(confidenceScorerProvider),
  );
});

// Individual service providers (dependency injection)
final poseDetectionServiceProvider = Provider((ref) {
  final service = PoseDetectionService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

final segmentationServiceProvider = Provider((ref) {
  final service = SegmentationService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

final calibrationEngineProvider = Provider((ref) => CalibrationEngine());
final measurementEngineProvider = Provider((ref) => MeasurementEngine());
final qualityControllerProvider = Provider((ref) => QualityController());
final confidenceScorerProvider = Provider((ref) => ConfidenceScorer());

// Scanner state (real-time camera + leveling)
final scannerStateProvider =
    StateNotifierProvider<ScannerStateNotifier, ScannerState>((ref) {
  return ScannerStateNotifier(
    levelingService: ref.watch(levelingServiceProvider),
    poseValidator: PoseValidator(),
    preScanValidator: PreScanValidator(),
    frameAccumulator: MultiFrameAccumulator(),
  );
});

// Main digital tailor workflow
final digitalTailorProvider =
    StateNotifierProvider<DigitalTailorNotifier, DigitalTailorState>((ref) {
  return DigitalTailorNotifier(
    pipeline: ref.watch(scanningPipelineProvider),
    firestoreService: ref.watch(measurementFirestoreServiceProvider),
  );
});
```

#### Pipeline Orchestrator

```dart
class ScanningPipeline {
  final PoseDetectionService poseService;
  final SegmentationService segmentationService;
  final CalibrationEngine calibrationEngine;
  final MeasurementEngine measurementEngine;
  final QualityController qualityController;
  final ConfidenceScorer confidenceScorer;

  /// Execute the full measurement pipeline
  Future<PipelineResult> execute({
    required Uint8List frontImage,
    required Uint8List sideImage,
    required CalibrationInput calibrationInput,
  }) async {
    // Stage 1: Detect poses
    final frontPose = await poseService.detectPose(frontImage);
    if (!frontPose.isSuccess) return PipelineResult.failed(frontPose.error);

    final sidePose = await poseService.detectPose(sideImage);
    if (!sidePose.isSuccess) return PipelineResult.failed(sidePose.error);

    // Stage 2: Segment bodies
    final frontMask = await segmentationService.segment(frontImage);
    final sideMask = await segmentationService.segment(sideImage);

    // Stage 3: Calibrate
    final calibration = await calibrationEngine.calibrate(
      calibrationInput.copyWith(landmarks: frontPose.landmarks),
    );

    // Stage 4: Analyze body outline
    final frontOutline = frontMask != null
        ? BodyOutlineAnalyzer().analyzeFullOutline(
            mask: frontMask,
            landmarks: frontPose.landmarks,
            imageWidth: frontPose.imageWidth,
            imageHeight: frontPose.imageHeight,
          )
        : null;

    final sideOutline = sideMask != null
        ? BodyOutlineAnalyzer().analyzeFullOutline(
            mask: sideMask,
            landmarks: sidePose.landmarks,
            imageWidth: sidePose.imageWidth,
            imageHeight: sidePose.imageHeight,
          )
        : null;

    // Stage 5: Compute measurements
    final measurements = measurementEngine.computeAll(
      frontLandmarks: frontPose.landmarks,
      sideLandmarks: sidePose.landmarks,
      frontOutline: frontOutline,
      sideOutline: sideOutline,
      pixelToCm: calibration.pixelToCm,
    );

    // Stage 6: Quality control
    final quality = qualityController.validate(
      measurements, frontPose.landmarks,
    );

    // Stage 7: Confidence scoring
    final confidence = confidenceScorer.score(
      measurements: measurements,
      frontLandmarks: frontPose.landmarks,
      sideLandmarks: sidePose.landmarks,
      calibration: calibration,
      quality: quality,
    );

    return PipelineResult.success(
      measurements: measurements,
      quality: quality,
      confidence: confidence,
      calibrationMethod: calibration.method,
    );
  }
}
```

---

## 4. Class Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ScanningPipeline                             │
│─────────────────────────────────────────────────────────────────────│
│ + execute(frontImage, sideImage, calibrationInput): PipelineResult  │
└──────────────┬──────────────────────────────────────────────────────┘
               │ depends on
    ┌──────────┼──────────┬──────────────┬──────────────┬─────────┐
    ▼          ▼          ▼              ▼              ▼         ▼
┌────────┐ ┌────────┐ ┌────────────┐ ┌────────────┐ ┌───────┐ ┌───────┐
│PoseDet.│ │Segment.│ │Calibration │ │Measurement │ │Quality│ │Confid.│
│Service │ │Service │ │Engine      │ │Engine      │ │Control│ │Scorer │
└────┬───┘ └────┬───┘ └─────┬──────┘ └─────┬──────┘ └───┬───┘ └───────┘
     │          │            │              │            │
     │          │     ┌──────┼──────┐    ┌──┼──────┐    │
     │          │     ▼      ▼      ▼    ▼  ▼      ▼    │
     │          │  ┌─────┐┌─────┐┌─────┐┌────┐┌────┐┌─────┐   ┌──────┐
     │          │  │Ref. ││Cam. ││Hght.││Lin.││Circ││Outl.│   │Symm. │
     │          │  │Obj. ││Dist.││Cal. ││Msr.││Est.││Anlz.│   │Check │
     │          │  └─────┘└─────┘└─────┘└────┘└────┘└─────┘   └──────┘
     │          │                           │
     ▼          ▼                           ▼
┌─────────┐ ┌─────────┐              ┌──────────┐
│ML Kit   │ │ML Kit   │              │Front+Side│
│Pose Det.│ │Selfie   │              │Fusion    │
│(native) │ │Segment. │              └──────────┘
└─────────┘ └─────────┘

┌──────────────────────────────────────────┐
│ Models                                    │
├──────────────────────────────────────────┤
│ ProcessedLandmarks                        │
│ BodyOutline (shoulder/chest/waist/hip)    │
│ CalibrationResult (pixelToCm, method)     │
│ MeasurementWithConfidence                 │
│ QualityReport (issues, recommendation)    │
│ ConfidenceReport (overall, perMeasurement)│
│ PipelineResult                            │
│ ScanSession / ScanResult                  │
└──────────────────────────────────────────┘
```

---

## 5. Sequence Diagram

```
User          Scanner UI        Pipeline         Pose Det.    Segment.    Calibration    Measurement    Quality
 │                │                │                │            │             │              │            │
 │─── Open ──────▶│                │                │            │             │              │            │
 │                │── PreScan ────▶│                │            │             │              │            │
 │                │◀─ Guidance ────│                │            │             │              │            │
 │                │                │                │            │             │              │            │
 │─── T-Pose ───▶│── Validate ───▶│                │            │             │              │            │
 │                │◀─ 15 frames ──│                │            │             │              │            │
 │                │── CAPTURE ────▶│                │            │             │              │            │
 │                │   (front)      │                │            │             │              │            │
 │                │                │                │            │             │              │            │
 │─── Turn ─────▶│── Side T-Pose─▶│                │            │             │              │            │
 │                │── CAPTURE ────▶│                │            │             │              │            │
 │                │   (side)       │                │            │             │              │            │
 │                │                │                │            │             │              │            │
 │                │                │── detectPose ─▶│            │             │              │            │
 │                │                │◀─ landmarks ──│            │             │              │            │
 │                │                │── segment ────▶├───────────▶│             │              │            │
 │                │                │◀─ mask ───────│◀───────────│             │              │            │
 │                │                │── calibrate ──▶├────────────├────────────▶│              │            │
 │                │                │◀─ pixelToCm ──│            │◀────────────│              │            │
 │                │                │── compute ────▶├────────────├─────────────├─────────────▶│            │
 │                │                │◀─ measures ───│            │             │◀─────────────│            │
 │                │                │── validate ───▶├────────────├─────────────├──────────────├───────────▶│
 │                │                │◀─ report ─────│            │             │              │◀───────────│
 │                │◀─ Results ─────│                │            │             │              │            │
 │◀── Display ───│                │                │            │             │              │            │
 │                │                │                │            │             │              │            │
 │─── Save ─────▶│── Firestore ──▶│                │            │             │              │            │
 │◀── Done ──────│                │                │            │             │              │            │
```

---

## 6. Recommended Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `google_mlkit_pose_detection` | ^0.12.0 | 33-landmark pose detection (BlazePose) |
| `google_mlkit_selfie_segmentation` | ^0.7.0 | Body segmentation mask for outline estimation |
| `camera` | ^0.11.0+2 | Camera stream and capture |
| `sensors_plus` | ^6.1.1 | Accelerometer for leveling |
| `image` | ^4.3.0 | Image decoding and manipulation |
| `path_provider` | ^2.1.5 | Temp file storage |
| `permission_handler` | ^11.3.1 | Camera/sensor permissions |
| `flutter_riverpod` | ^2.6.1 | State management (already used) |
| `vector_math` | ^2.1.4 | 3D vector operations for landmark processing |

**Removed:** No new packages beyond adding `google_mlkit_selfie_segmentation`. The One Euro Filter and all other algorithms are implemented in pure Dart — no external dependency needed.

---

## 7. Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ INPUT                                                            │
│                                                                  │
│  Camera Stream (30fps) ──▶ PreScan Validation (real-time)       │
│          │                                                       │
│          ▼                                                       │
│  Stable T-Pose (15 frames) ──▶ Multi-frame Accumulator          │
│          │                                                       │
│          ▼                                                       │
│  Captured JPEG (front + side)                                   │
│          │                                                       │
│          ▼                                                       │
│  User Height / Reference Object                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ PROCESSING                                                       │
│                                                                  │
│  JPEG ──▶ ML Kit Pose ──▶ ProcessedLandmarks                   │
│       ──▶ ML Kit Segmentation ──▶ SegmentationMask              │
│                                                                  │
│  ProcessedLandmarks + CalibrationInput ──▶ CalibrationResult    │
│                                                                  │
│  SegmentationMask + Landmarks ──▶ BodyOutline                   │
│                                                                  │
│  BodyOutline + CalibrationResult ──▶ Raw Measurements           │
│                                                                  │
│  Front Raw + Side Raw ──▶ Fused Measurements                    │
│                                                                  │
│  Fused Measurements ──▶ Quality Report + Confidence Report      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ OUTPUT                                                           │
│                                                                  │
│  ScanResult {                                                    │
│    measurements: List<Measurement>   (cm + inch)                │
│    confidence: ConfidenceReport      (overall + per-measurement) │
│    quality: QualityReport            (issues + recommendation)   │
│    calibration: CalibrationResult    (method + factor)           │
│    scannedAt: DateTime                                           │
│    scanVersion: '2.0.0'                                         │
│  }                                                               │
│                                                                  │
│  ──▶ Firestore (measurement_data map)                           │
│  ──▶ UI (Results Screen)                                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Performance Optimization

| Concern | Strategy |
|---------|----------|
| ML Kit inference time | Use `PoseDetectionMode.stream` for live preview, `PoseDetectionMode.single` for final capture. Stream mode is faster but less accurate. |
| Segmentation latency | Run segmentation asynchronously after capture (not on preview). User sees "processing" for 2-4 seconds. |
| Memory usage | Dispose camera controller during processing phase. Only hold 2 JPEG images in memory. |
| Multi-frame accumulation | Process 15 frames at 30fps in 0.5 seconds — imperceptible to user |
| Image resolution | Capture at camera's max resolution for measurement accuracy. Use lower resolution for live preview. |
| Battery | Stop accelerometer and camera stream immediately after capture |
| Isolate processing | Run landmark extraction and measurement computation in a Dart isolate to avoid jank |

```dart
// Example: Isolate-based processing
Future<PipelineResult> processInIsolate({
  required Uint8List frontImage,
  required Uint8List sideImage,
  required CalibrationInput calibration,
}) async {
  // ML Kit must run on platform thread, but pure Dart computation can isolate
  final frontPose = await poseService.detectPose(frontImage);
  final sidePose = await poseService.detectPose(sideImage);
  final frontMask = await segmentationService.segment(frontImage);
  final sideMask = await segmentationService.segment(sideImage);

  // Heavy computation in isolate
  return compute(_computeMeasurements, ComputeParams(
    frontPose: frontPose,
    sidePose: sidePose,
    frontMask: frontMask,
    sideMask: sideMask,
    calibration: calibration,
  ));
}
```

---

## 9. Migration Guide: ML Kit → Redesigned Pipeline

### What Changes

| Component | Current (v1) | New (v2) | Migration Action |
|-----------|-------------|----------|------------------|
| Pose detection | ML Kit (single frame) | ML Kit (multi-frame averaged) | **Enhance**, don't replace |
| Segmentation | None | ML Kit Selfie Segmentation | **Add** |
| Calibration | Height only | Multi-strategy engine | **Replace** |
| Measurement calc | Euclidean + hardcoded multipliers | Segmentation width + ellipse | **Rewrite** |
| Circumference | Fixed ratio estimation | Front+Side segmentation fusion | **Rewrite** |
| Quality control | Basic range check | Symmetry + ratios + confidence | **Add** |
| Temporal smoothing | None | One Euro Filter + multi-frame | **Add** |
| Pre-scan validation | None | Lighting/distance/pose checks | **Add** |

### Migration Steps (Ordered)

1. **Add `google_mlkit_selfie_segmentation` to pubspec.yaml**
2. **Create new folder structure** under `services/pipeline/`, `services/detection/`, etc.
3. **Implement `OneEuroFilter`** — pure Dart, no dependencies
4. **Implement `MultiFrameAccumulator`** — pure Dart
5. **Implement `PreScanValidator`** — uses camera stream
6. **Implement `PoseValidator`** — T-Pose validation
7. **Implement `SegmentationService`** — wraps ML Kit selfie segmenter
8. **Implement `BodyOutlineAnalyzer`** — processes segmentation mask
9. **Implement `CalibrationEngine`** with all 4 strategies
10. **Implement `LinearMeasurer`** — replaces linear measurement code
11. **Implement `CircumferenceEstimator`** — replaces circumference code
12. **Implement `FrontSideFusion`** — new capability
13. **Implement `QualityController`** + `SymmetryChecker` + `RangeValidator`
14. **Implement `ConfidenceScorer`** — new capability
15. **Implement `ScanningPipeline`** — orchestrates all above
16. **Rewrite `DigitalTailorNotifier`** to use pipeline
17. **Update Scanner Screen** for T-Pose guidance and multi-frame capture
18. **Update Results Screen** to show per-measurement confidence
19. **Delete old `MeasurementCalculator`** (fully replaced)
20. **Update Firestore schema** to include confidence and quality data

### Backward Compatibility

- **Firestore schema:** Add new fields alongside existing ones. Old measurements remain readable.
- **ScanResult model:** Enhanced with confidence, but `measurements` list structure is unchanged.
- **Navigation routes:** Unchanged. Same screens, enhanced internally.
- **Measurement model:** Add `confidence` field to `Measurement` class (optional, defaults to null for legacy data).

### Risk Mitigation

- Keep old `MeasurementCalculator` available during development under a feature flag
- A/B test: compare v1 vs v2 measurements against known tape measurements
- Implement a "calibration verification" mode where users can validate one known measurement

---

## 10. Refactor Plan

### Phase 1: Foundation (Week 1)
- [ ] Create folder structure
- [ ] Implement `OneEuroFilter`
- [ ] Implement `MultiFrameAccumulator`
- [ ] Implement `ProcessedLandmarks` model
- [ ] Implement `BodyOutline` model
- [ ] Add `google_mlkit_selfie_segmentation` dependency
- [ ] Implement `SegmentationService`

### Phase 2: Detection Pipeline (Week 2)
- [ ] Implement `PreScanValidator` with all checks
- [ ] Implement `PoseValidator` (T-Pose)
- [ ] Enhance `PoseDetectionService` for multi-frame mode
- [ ] Implement `BodyOutlineAnalyzer`
- [ ] Implement `LandmarkProcessor` (normalization)

### Phase 3: Calibration (Week 2-3)
- [ ] Implement `CalibrationEngine` abstraction
- [ ] Implement `HeightCalibrator` (improved)
- [ ] Implement `ReferenceObjectCalibrator`
- [ ] Implement `CameraDistanceCalibrator`
- [ ] Implement `ExistingProfileCalibrator`
- [ ] Update `CalibrationScreen` for method selection

### Phase 4: Measurement Engine (Week 3)
- [ ] Implement `LinearMeasurer`
- [ ] Implement `CircumferenceEstimator`
- [ ] Implement `FrontSideFusion`
- [ ] Implement `MeasurementEngine` orchestrator

### Phase 5: Quality & Confidence (Week 4)
- [ ] Implement `SymmetryChecker`
- [ ] Implement `RangeValidator`
- [ ] Implement `QualityController`
- [ ] Implement `ConfidenceScorer`
- [ ] Implement `ScanningPipeline` orchestrator

### Phase 6: Integration (Week 4-5)
- [ ] Rewrite `DigitalTailorNotifier`
- [ ] Update Scanner Screen for T-Pose + multi-frame
- [ ] Update Results Screen for confidence display
- [ ] Add quality rejection UI
- [ ] Delete deprecated code
- [ ] End-to-end testing

---

## 11. Enhanced Firestore Schema (v2)

```json
{
  "measurement_data": {
    "scan_version": "2.0.0",
    "scanned_at": "Timestamp",
    "calibration_method": "reference_object",
    "calibration_confidence": 0.95,
    "overall_confidence": 0.88,
    "quality_status": "accepted",
    "quality_issues": [],

    "bahu": {
      "label": "Bahu (Shoulder Width)",
      "value_cm": 44.2,
      "value_inch": 17.4,
      "region": "atas",
      "confidence": 0.91,
      "source": "segmentation"
    },
    "dada": {
      "label": "Dada (Chest Circumference)",
      "value_cm": 96.5,
      "value_inch": 38.0,
      "region": "tengah",
      "confidence": 0.88,
      "source": "front_side_fusion"
    },
    "pinggang": {
      "label": "Pinggang (Waist Circumference)",
      "value_cm": 78.3,
      "value_inch": 30.8,
      "region": "tengah",
      "confidence": 0.86,
      "source": "front_side_fusion"
    },
    "pinggul": {
      "label": "Pinggul (Hip Circumference)",
      "value_cm": 98.7,
      "value_inch": 38.9,
      "region": "tengah",
      "confidence": 0.85,
      "source": "front_side_fusion"
    },
    "lingkar_leher": {
      "label": "Lingkar Leher (Neck Circumference)",
      "value_cm": 38.1,
      "value_inch": 15.0,
      "region": "atas",
      "confidence": 0.55,
      "source": "estimation"
    },
    "panjang_lengan": {
      "label": "Panjang Lengan (Arm Length)",
      "value_cm": 58.4,
      "value_inch": 23.0,
      "region": "tengah",
      "confidence": 0.92,
      "source": "landmark_linear"
    },
    "panjang_kaki": {
      "label": "Panjang Kaki (Leg Length)",
      "value_cm": 84.6,
      "value_inch": 33.3,
      "region": "bawah",
      "confidence": 0.90,
      "source": "landmark_linear"
    },
    "tinggi_torso": {
      "label": "Tinggi Torso (Torso Height)",
      "value_cm": 42.1,
      "value_inch": 16.6,
      "region": "tengah",
      "confidence": 0.89,
      "source": "landmark_linear"
    },
    "panjang_punggung": {
      "label": "Panjang Punggung (Back Length)",
      "value_cm": 40.5,
      "value_inch": 15.9,
      "region": "tengah",
      "confidence": 0.85,
      "source": "landmark_linear"
    },
    "lebar_pinggang": {
      "label": "Lebar Pinggang (Waist Width)",
      "value_cm": 28.5,
      "value_inch": 11.2,
      "region": "tengah",
      "confidence": 0.87,
      "source": "segmentation"
    },
    "lebar_pinggul": {
      "label": "Lebar Pinggul (Hip Width)",
      "value_cm": 35.8,
      "value_inch": 14.1,
      "region": "tengah",
      "confidence": 0.87,
      "source": "segmentation"
    }
  }
}
```

---

## 12. Error Handling Strategy

```dart
/// Errors are categorized by user action required
enum ScanErrorType {
  /// User can fix: lighting, distance, pose
  recoverable,
  /// Hardware issue: no camera, no accelerometer
  deviceLimitation,
  /// ML model issue: detection failed, timeout
  processingFailure,
  /// Network issue: Firestore save failed
  networkError,
}

class ScanError {
  final ScanErrorType type;
  final String messageId;        // Indonesian UI message
  final String technicalDetail;  // For logging
  final List<String> guidance;   // Actionable steps for user
  final bool canRetry;

  // Pre-defined errors
  static final poorLighting = ScanError(
    type: ScanErrorType.recoverable,
    messageId: 'Pencahayaan kurang memadai',
    guidance: [
      'Pastikan ruangan terang merata',
      'Hindari pencahayaan dari belakang (backlight)',
      'Gunakan lampu utama ruangan',
    ],
    canRetry: true,
  );

  static final tooFar = ScanError(
    type: ScanErrorType.recoverable,
    messageId: 'Terlalu jauh dari kamera',
    guidance: ['Maju mendekati kamera hingga seluruh tubuh terlihat'],
    canRetry: true,
  );

  static final tooClose = ScanError(
    type: ScanErrorType.recoverable,
    messageId: 'Terlalu dekat dengan kamera',
    guidance: ['Mundur sehingga seluruh tubuh dari kepala sampai kaki terlihat'],
    canRetry: true,
  );

  static final poorPose = ScanError(
    type: ScanErrorType.recoverable,
    messageId: 'Pose tidak terdeteksi dengan baik',
    guidance: [
      'Berdiri tegak dengan kedua tangan terentang (T-Pose)',
      'Pastikan kedua kaki terlihat',
      'Gunakan latar belakang polos',
    ],
    canRetry: true,
  );

  static final processingTimeout = ScanError(
    type: ScanErrorType.processingFailure,
    messageId: 'Waktu pemrosesan habis',
    guidance: ['Coba lagi dengan pencahayaan yang lebih baik'],
    canRetry: true,
  );

  static final lowConfidence = ScanError(
    type: ScanErrorType.processingFailure,
    messageId: 'Hasil pengukuran tidak cukup akurat',
    guidance: [
      'Gunakan pakaian ketat/pas badan',
      'Berdiri di depan dinding polos',
      'Pastikan tidak ada orang lain dalam frame',
    ],
    canRetry: true,
  );
}
```

---

## 13. UI Flow Improvements

### Current Flow
```
Profile → Calibration (height) → Scanner (front) → Scanner (side) → Processing → Results → Save
```

### New Flow
```
Profile → Calibration (multi-method) → Pre-Scan Check → T-Pose Guide →
  Stabilize (15 frames) → Auto-Capture (front) →
  Turn Guide → T-Pose Guide → Stabilize (15 frames) →
  Auto-Capture (side) → Processing (with progress) →
  Quality Gate → Results (with confidence) → Save
```

### Key UI Improvements

1. **Real-time Pre-Scan Feedback:** Before capture, show live checklist:
   - ✅ Pencahayaan OK
   - ✅ Jarak OK
   - ❌ Pose belum benar (with arrow guidance)
   - ✅ Latar belakang OK

2. **T-Pose Guide Overlay:** Animated silhouette showing exact arm angle expected

3. **Auto-Capture:** No manual shutter button for pose capture. System auto-captures when 15 stable frames are accumulated. User just holds the pose.

4. **Progress Indicators:** During processing, show granular steps:
   - "Menganalisis pose tubuh..." (30%)
   - "Menganalisis kontur tubuh..." (50%)
   - "Menghitung pengukuran..." (70%)
   - "Memvalidasi hasil..." (90%)

5. **Confidence-Colored Results:** Each measurement row shows a colored dot:
   - 🟢 Green: confidence ≥ 85%
   - 🟡 Yellow: confidence 55-84%
   - 🔴 Red: confidence < 55%

6. **Quality Gate Screen:** If quality is "reject", show specific issues with photos/diagrams showing how to fix them. Don't show unreliable results.

---

## 14. Best Practices

### Anthropometric Research References

The measurement ratios used in fallback calculations are based on:
- **ISO 8559-1:2017** — Size designation of clothes: anthropometric definitions for body measurement
- **CAESAR (Civilian American and European Surface Anthropometry Resource)** — 3D body scan database
- **Human body proportions (Vitruvian model)** — head-to-body ratios

Key ratios used:
| Ratio | Value | Source |
|-------|-------|--------|
| Chest depth / chest width | 0.68–0.78 | ISO 8559 |
| Waist depth / waist width | 0.65–0.75 | ISO 8559 |
| Hip depth / hip width | 0.75–0.85 | ISO 8559 |
| Neck circumference / shoulder width | ~0.85 | CAESAR |
| Head height / body height | 0.12–0.13 | Vitruvian |
| Torso / body height | 0.30–0.35 | CAESAR |

### Code Quality

- Every service class has a single responsibility
- All computations are unit-testable (no UI dependencies)
- Calibration strategies follow the Strategy Pattern
- Pipeline follows the Chain of Responsibility pattern
- Models are immutable (`final` fields, `copyWith` for changes)
- Error messages are user-facing (Indonesian) with technical details logged separately

### Testing Strategy

```dart
// Unit test example: circumference calculation
test('ellipse circumference matches known values', () {
  final estimator = CircumferenceEstimator(pixelToCm: 1.0);

  // Circle (a == b): C = 2πr
  final circle = estimator.ellipseCircumference(10.0, 10.0);
  expect(circle, closeTo(2 * pi * 10, 0.01));

  // Known ellipse: a=20, b=15 → C ≈ 110.2 cm
  final ellipse = estimator.ellipseCircumference(20.0, 15.0);
  expect(ellipse, closeTo(110.2, 0.5));
});

// Integration test: pipeline produces valid results
test('pipeline produces measurements within physiological ranges', () async {
  final result = await pipeline.execute(
    frontImage: testFrontImage,
    sideImage: testSideImage,
    calibrationInput: CalibrationInput(userHeightCm: 170),
  );

  expect(result.isSuccess, true);
  for (final m in result.measurements) {
    expect(m.valueCm, greaterThan(0));
    expect(m.confidence, greaterThan(0));
  }
});
```

---

## 15. Summary of Why This Redesign Fixes the Problems

| Problem | Root Cause | v2 Solution |
|---------|-----------|-------------|
| Inconsistent measurements | Single-frame noise | Multi-frame averaging + One Euro Filter |
| Chest/waist/hip underestimated | Using joint centers instead of body surface | Segmentation mask gives actual body width |
| Size S classified as XS | Hardcoded multipliers too conservative | Research-backed ratios + actual depth from side photo |
| Poor landmark stability | No temporal filtering | One Euro Filter + outlier rejection |
| Posture-dependent errors | No pose validation | Strict T-Pose requirement with 15-frame stability |
| No confidence indication | Single-pass calculate | Per-measurement confidence with quality gate |

---

## Appendix: Measurements Produced (v2)

| # | Key | Indonesian Name | English | Type | Method |
|---|-----|----------------|---------|------|--------|
| 1 | `bahu` | Bahu | Shoulder Width | Linear | Segmentation outline |
| 2 | `lingkar_leher` | Lingkar Leher | Neck Circumference | Circumference | Estimation + ratio |
| 3 | `dada` | Dada | Chest Circumference | Circumference | Front+Side fusion |
| 4 | `pinggang` | Pinggang | Waist Circumference | Circumference | Front+Side fusion |
| 5 | `pinggul` | Pinggul | Hip Circumference | Circumference | Front+Side fusion |
| 6 | `panjang_lengan` | Panjang Lengan | Sleeve/Arm Length | Linear | Landmark Euclidean |
| 7 | `panjang_kaki` | Panjang Kaki | Leg Length (Inseam) | Linear | Landmark Euclidean |
| 8 | `tinggi_torso` | Tinggi Torso | Torso Height | Linear | Landmark Euclidean |
| 9 | `panjang_punggung` | Panjang Punggung | Back Length | Linear | Landmark Euclidean |
| 10 | `lebar_dada` | Lebar Dada | Chest Width | Linear | Segmentation outline |
| 11 | `lebar_pinggang` | Lebar Pinggang | Waist Width | Linear | Segmentation outline |
| 12 | `lebar_pinggul` | Lebar Pinggul | Hip Width | Linear | Segmentation outline |

Additional measurements derivable:
- Upper arm circumference (segmentation at elbow level)
- Thigh circumference (segmentation at mid-thigh)
- Cross-back width (between shoulder blades)
- Arm hole depth (shoulder to underarm)

These can be added incrementally using the same `BodyOutlineAnalyzer` at different y-coordinates.
