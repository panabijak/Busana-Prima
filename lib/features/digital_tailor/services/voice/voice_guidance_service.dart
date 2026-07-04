import 'package:flutter_tts/flutter_tts.dart';

/// Smart voice guidance engine for the body scanning experience.
///
/// Speaks contextual guidance so users don't need to constantly look
/// at the screen while positioning themselves for a scan.
///
/// Uses on-device TTS — no internet required.
class VoiceGuidanceService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  String? _lastSpoken;

  /// Initialize TTS engine with English language settings.
  Future<void> initialize() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5); // Slightly slower for clarity
      await _tts.setVolume(0.9);
      await _tts.setPitch(1.0);

      _tts.setCompletionHandler(() => _isSpeaking = false);
      _tts.setStartHandler(() => _isSpeaking = true);
      _tts.setCancelHandler(() => _isSpeaking = false);

      _isInitialized = true;
    } catch (_) {
      // TTS unavailable on this device — silent fallback
      _isInitialized = false;
    }
  }

  /// Speak a guidance message.
  ///
  /// [force] bypasses the deduplication check (for critical announcements).
  Future<void> speak(String message, {bool force = false}) async {
    if (!_isInitialized) return;
    if (!force && _lastSpoken == message && _isSpeaking) return;

    _lastSpoken = message;
    await _tts.stop();
    await _tts.speak(message);
  }

  /// Stop any currently playing speech.
  Future<void> stop() async {
    if (!_isInitialized) return;
    await _tts.stop();
    _isSpeaking = false;
  }

  /// Whether TTS is currently speaking.
  bool get isSpeaking => _isSpeaking;

  /// Release TTS resources.
  Future<void> dispose() async {
    await _tts.stop();
  }
}

/// Pre-defined guidance messages in English.
/// Kept as constants for consistent, testable text.
class GuidanceMessages {
  GuidanceMessages._();

  // Pre-scan
  static const String welcome =
      'Welcome to Digital Tailor. '
      'Make sure you are standing in a well-lit area with a plain background.';
  static const String setupReady =
      'Ready to scan. Place your phone upright and stand 2 metres from the camera.';

  // Distance
  static const String moveBack = 'Step back a little';
  static const String moveCloser = 'Step forward a little';

  // Position
  static const String moveLeft = 'Move slightly to the left';
  static const String moveRight = 'Move slightly to the right';
  static const String centerBody = 'Centre your body in the frame';

  // Pose — A-Pose
  static const String aPoseInstruction =
      'Please stand with both arms open slightly, '
      'about 30 degrees from your body. Feet shoulder-width apart.';
  static const String raiseLeftArm = 'Raise your left arm slightly';
  static const String raiseRightArm = 'Raise your right arm slightly';
  static const String lowerArms = 'Lower both arms slightly';
  static const String levelShoulders = 'Level both shoulders';
  static const String standStraight = 'Stand up straight';
  static const String showFeet =
      'Make sure both feet are visible in the camera';
  static const String faceCamera = 'Face your body towards the camera';

  // Leveling
  static const String tiltDevice = 'Hold your phone upright';

  // Stability
  static const String holdStill = 'Perfect. Please hold still.';
  static const String poseGood = 'Good pose. Hold this position.';
  static const String almostReady = 'Almost ready.';

  // Countdown
  static const String countThree = 'Three';
  static const String countTwo = 'Two';
  static const String countOne = 'One';
  static const String capture = 'Capture';

  // Transitions
  static const String frontCaptured =
      'Front photo captured successfully. '
      'Now please turn sideways and face your left shoulder towards the camera.';
  static const String sidePoseInstruction =
      'Stand sideways. Arms straight at your sides.';

  // Processing
  static const String processingStart =
      'Analysing your body measurements. Please wait a moment.';
  static const String processingComplete =
      'Measurement complete. Please review your results.';

  // Errors
  static const String poorLighting =
      'Poor lighting. Please find a brighter spot.';
  static const String detectionFailed =
      'Failed to detect pose. Make sure your full body is visible.';
  static const String scanFailed = 'Scan failed. Please try again.';
}
