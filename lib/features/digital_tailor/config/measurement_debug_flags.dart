import 'package:flutter/foundation.dart';

/// Whether the measurement-engine debug panel is visible.
///
/// Works **without USB** after you install the APK — no `flutter run` needed.
///
/// ```bash
/// flutter run --dart-define=MEASUREMENT_DEBUG=true
/// flutter build apk --dart-define=MEASUREMENT_DEBUG=true
/// ```
///
/// Default: same as [kDebugMode] (on while `flutter run` debug, off in release).
/// Set the dart-define to `true` to keep debug on a standalone installed build.
const bool kMeasurementDebugEnabled = bool.fromEnvironment(
  'MEASUREMENT_DEBUG',
  defaultValue: kDebugMode,
);
