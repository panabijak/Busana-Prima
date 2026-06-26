# Design Document: Digital Tailor Module

## Architecture Overview

The Digital Tailor module follows the existing Busana Prima feature architecture:

```
lib/features/digital_tailor/
├── models/
│   ├── measurement.dart        # Single measurement data model
│   ├── scan_session.dart       # Scanning workflow state
│   └── scan_result.dart        # Complete scan results
├── providers/
│   └── digital_tailor_provider.dart  # Riverpod state management
├── screens/
│   ├── calibration_screen.dart       # Height input for calibration
│   ├── scanner_screen.dart           # Camera + leveling + silhouette
│   ├── results_screen.dart           # Review & save measurements
│   └── measurement_profile_screen.dart # View stored measurements
├── services/
│   ├── leveling_service.dart              # Accelerometer monitoring
│   ├── pose_detection_service.dart        # ML Kit pose detection
│   ├── measurement_calculator.dart        # Anthropometric formulas
│   └── measurement_firestore_service.dart # Firestore persistence
└── widgets/
    └── silhouette_overlay.dart    # Camera overlay with CustomPainter
```

## State Management

Uses `StateNotifierProvider<DigitalTailorNotifier, DigitalTailorState>` following the existing pattern in the profile feature.

### State Flow
```
Calibration → Front Capture → Side Capture → Processing → Results → Save
```

## Key Technical Decisions

### 1. Calibration Method
- Primary: User-provided height (cm) mapped against detected body height in pixels
- Pixel-to-cm ratio = userHeight / detectedBodyHeightPixels
- Applied uniformly to all landmark distance calculations

### 2. Measurement Formulas
- **Linear measurements** (Bahu, Panjang Lengan, Panjang Kaki): Euclidean distance between landmarks × pixelToCm
- **Circumference measurements** (Dada, Pinggang, Pinggul, Lingkar Leher): Ramanujan ellipse approximation using front-width (a) and side-depth (b)
  - C ≈ π × (3(a+b) - √((3a+b)(a+3b)))

### 3. Leveling System
- Accelerometer sampled at ~30 Hz via `sensors_plus`
- Acceptable deviation: ±5° from vertical
- Stability requirement: 300ms within range before enabling capture
- Haptic feedback on level confirmation

### 4. Pose Detection
- Uses `google_mlkit_pose_detection` with `PoseDetectionModel.accurate`
- Requires 13 key landmarks with confidence ≥ 0.5
- Processes front and side images independently

### 5. Firestore Schema
```json
{
  "measurement_data": {
    "scanned_at": Timestamp,
    "confidence_score": 0.82,
    "scan_version": "1.0.0",
    "bahu": {
      "label": "Bahu (Shoulder Width)",
      "value_cm": 42.5,
      "value_inch": 16.7,
      "region": "atas"
    },
    "dada": { ... },
    "pinggang": { ... },
    ...
  }
}
```

## Navigation Routes

| Route | Screen | Purpose |
|-------|--------|---------|
| `/digital-tailor/measurements` | MeasurementProfileScreen | View stored data or CTA |
| `/digital-tailor/calibration` | CalibrationScreen | Height input |
| `/digital-tailor/scanner` | ScannerScreen | Camera capture |
| `/digital-tailor/results` | ResultsScreen | Review & save |

## Dependencies Added

- `camera: ^0.11.0+2` — Camera access
- `google_mlkit_pose_detection: ^0.12.0` — Pose landmark detection
- `sensors_plus: ^6.1.1` — Accelerometer for leveling
- `image: ^4.3.0` — Image decoding for ML Kit input
- `path_provider: ^2.1.5` — Temporary file storage
- `permission_handler: ^11.3.1` — Camera permission management

## Error Handling Strategy

1. No accelerometer → Skip leveling, show warning, allow capture
2. Pose detection failure → Prompt retake with guidance (max 3 attempts)
3. Firestore save failure → Retain results in memory, retry button (unlimited)
4. Out-of-range measurements → Flag with warning indicator, don't discard
