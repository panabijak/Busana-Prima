import 'package:flutter/widgets.dart';

import './session_manager.dart';

/// Manages app lifecycle events and coordinates with session management
class AppLifecycleManager extends WidgetsBindingObserver {
  final SessionManager _sessionManager;
  DateTime? _lastBackgroundTime;
  bool _isInBackground = false;

  AppLifecycleManager(this._sessionManager);

  /// Initialize and start observing lifecycle events
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Dispose and stop observing lifecycle events
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;

      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;

      case AppLifecycleState.paused:
        _handleAppPaused();
        break;

      case AppLifecycleState.detached:
        _handleAppDetached();
        break;

      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }
  }

  /// App came to foreground
  void _handleAppResumed() {
    if (_isInBackground) {
      final backgroundDuration = _lastBackgroundTime != null
          ? DateTime.now().difference(_lastBackgroundTime!)
          : Duration.zero;

      // Only validate session if app was in background for more than 30 seconds
      if (backgroundDuration.inSeconds > 30) {
        _sessionManager.validateSession();
      }

      _isInBackground = false;
      _lastBackgroundTime = null;
    }

    // Always update last active when app resumes
    _sessionManager.updateLastActive();

    // Refresh token if needed
    _sessionManager.refreshTokenIfNeeded();
  }

  /// App is transitioning (not in foreground, not in background)
  void _handleAppInactive() {
    // DO NOT logout here - this is a transitional state
    // Examples: switching between apps, showing system dialogs
    _sessionManager.updateLastActive();
  }

  /// App is in background
  void _handleAppPaused() {
    _isInBackground = true;
    _lastBackgroundTime = DateTime.now();

    // Update last active timestamp
    _sessionManager.updateLastActive();
    // DO NOT logout here - normal background state
  }

  /// App is being destroyed (rare on mobile)
  void _handleAppDetached() {
    // Clean up resources, but DO NOT logout
    // This state is rarely reached on mobile
    _sessionManager.updateLastActive();
  }

  /// App is hidden (new in Flutter 3.19+)
  void _handleAppHidden() {
    _isInBackground = true;
    _lastBackgroundTime = DateTime.now();

    _sessionManager.updateLastActive();
    // DO NOT logout here
  }

  /// Check if app was in background for a significant time
  bool get wasInBackgroundForLongTime {
    if (_lastBackgroundTime == null) return false;
    final duration = DateTime.now().difference(_lastBackgroundTime!);
    return duration.inMinutes > 5;
  }

  /// Get time spent in background
  Duration? get backgroundDuration {
    if (_lastBackgroundTime == null) return null;
    return DateTime.now().difference(_lastBackgroundTime!);
  }

  /// Force session validation (e.g., after network reconnect)
  Future<void> forceSessionValidation() async {
    await _sessionManager.validateSession();
  }

  /// Handle network connectivity changes
  void handleNetworkChange(bool isConnected) {
    if (isConnected) {
      // Network restored, validate session
      _sessionManager.validateSession();
      _sessionManager.refreshTokenIfNeeded();
    }
  }

  /// Handle device sleep/wake
  void handleDeviceWake() {
    // Device woke from sleep, validate session
    _sessionManager.validateSession();
  }

  /// Check if session should be validated based on background time
  bool shouldValidateSession() {
    if (backgroundDuration == null) return false;
    return backgroundDuration!.inSeconds > 300; // 5 minutes
  }
}
