import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import './models/session_state.dart';
import './services/device_info_service.dart';
import './services/token_service.dart';
import './services/session_firestore_service.dart';
import './services/fcm_token_manager.dart';

/// Main session manager that coordinates all session-related operations
class SessionManager extends ChangeNotifier {
  final DeviceInfoService _deviceInfoService;
  final TokenService _tokenService;
  final SessionFirestoreService _firestoreService;
  final FcmTokenManager _fcmTokenManager;

  SessionState _state = SessionState.initial;
  StreamSubscription<User?>? _authStateSubscription;

  SessionManager({
    DeviceInfoService? deviceInfoService,
    TokenService? tokenService,
    SessionFirestoreService? firestoreService,
    FcmTokenManager? fcmTokenManager,
  }) : _deviceInfoService = deviceInfoService ?? DeviceInfoService(),
       _tokenService = tokenService ?? TokenService(),
       _firestoreService = firestoreService ?? SessionFirestoreService(),
       _fcmTokenManager = fcmTokenManager ?? FcmTokenManager() {
    _initialize();
  }

  /// Current session state
  SessionState get state => _state;

  /// Initialize session manager
  Future<void> _initialize() async {
    // Listen to auth state changes
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthStateChange,
      onError: (error) {
        _updateState(_state.copyWith(error: error.toString()));
      },
    );

    // Initialize FCM
    await _fcmTokenManager.initialize(requestPermission: false);
  }

  /// Handle authentication state changes
  Future<void> _handleAuthStateChange(User? user) async {
    if (user == null) {
      // User signed out
      _updateState(SessionState.initial);
      return;
    }

    // User is signed in
    await _handleUserSignedIn(user);
  }

  /// Handle user sign in
  Future<void> _handleUserSignedIn(User user) async {
    try {
      _updateState(_state.copyWith(isLoading: true));

      // Get device information
      final deviceInfo = await _deviceInfoService.getDeviceInfo();
      final deviceId = deviceInfo['deviceId'] as String;

      // Store tokens and device info
      await _storeSessionData(user, deviceId);

      // Create/update session in Firestore
      final fcmToken = await _fcmTokenManager.getCurrentToken();
      await _firestoreService.createOrUpdateSession(
        userId: user.uid,
        deviceId: deviceId,
        deviceInfo: deviceInfo,
        fcmToken: fcmToken,
      );

      // Update state
      _updateState(
        SessionState.authenticated(
          user: user,
          deviceId: deviceId,
          sessionCreatedAt: await _tokenService.getSessionCreatedAt(),
          lastActiveAt: DateTime.now(),
        ),
      );

      // Clean up expired sessions
      await _firestoreService.cleanupExpiredSessions(user.uid);
    } catch (e) {
      _updateState(SessionState.error('Failed to establish session: $e'));
    }
  }

  /// Store session data locally
  Future<void> _storeSessionData(User user, String deviceId) async {
    // Note: Firebase doesn't expose refresh tokens directly in Flutter
    // We'll store a custom token or rely on Firebase's built-in persistence
    await _tokenService.storeDeviceId(deviceId);
    await _tokenService.storeSessionCreatedAt(DateTime.now());

    // For Firebase, the refresh token is managed internally
    // We can store a custom session identifier if needed
  }

  /// Initialize session on app startup
  Future<void> initializeSession() async {
    try {
      _updateState(_state.copyWith(isLoading: true));

      // Check if we have a persistent session
      final hasPersistentSession = await _tokenService.hasPersistentSession();

      if (!hasPersistentSession) {
        // No persistent session, stay in initial state
        _updateState(SessionState.initial);
        return;
      }

      // Check if Firebase has a cached user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // User is already authenticated by Firebase
        await _handleUserSignedIn(currentUser);
      } else {
        // No cached user, need to sign in
        _updateState(SessionState.initial);
      }
    } catch (e) {
      _updateState(SessionState.error('Session initialization failed: $e'));
    }
  }

  /// Validate current session
  Future<bool> validateSession() async {
    if (!_state.isAuthenticated) return false;

    try {
      // Check token validity
      final isValid = await _tokenService.validateSession();

      if (!isValid) {
        _updateState(_state.copyWith(requiresReauthentication: true));
        return false;
      }

      // Check if session is still active in Firestore
      final isActive = await _firestoreService.isSessionActive(
        _state.user!.uid,
        _state.deviceId!,
      );

      if (!isActive) {
        // Session was revoked remotely
        await logout();
        return false;
      }

      // Update last active timestamp
      await _firestoreService.updateLastActive(
        _state.user!.uid,
        _state.deviceId!,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update last active timestamp
  Future<void> updateLastActive() async {
    if (!_state.isAuthenticated) return;

    try {
      await _firestoreService.updateLastActive(
        _state.user!.uid,
        _state.deviceId!,
      );

      _updateState(_state.copyWith(lastActiveAt: DateTime.now()));
    } catch (e) {
      // Silent fail for last active update
    }
  }

  /// Logout from current device
  Future<void> logout() async {
    if (_state.isAuthenticated && _state.deviceId != null) {
      try {
        // Deactivate session in Firestore
        await _firestoreService.deactivateSession(
          _state.user!.uid,
          _state.deviceId!,
        );

        // Remove FCM token
        await _fcmTokenManager.removeTokenFromFirestore(
          userId: _state.user!.uid,
          deviceId: _state.deviceId!,
        );
      } catch (e) {
        // Continue with local cleanup even if Firestore fails
      }
    }

    // Clear local tokens
    await _tokenService.clearAllTokens();

    // Sign out from Firebase
    await FirebaseAuth.instance.signOut();

    // Update state
    _updateState(SessionState.initial);
  }

  /// Logout from all devices
  Future<void> logoutAllDevices() async {
    if (_state.isAuthenticated) {
      try {
        // Deactivate all sessions in Firestore
        await _firestoreService.deactivateAllSessions(_state.user!.uid);
      } catch (e) {
        // Continue with local cleanup
      }
    }

    // Clear local tokens
    await _tokenService.clearAllTokens();

    // Sign out from Firebase
    await FirebaseAuth.instance.signOut();

    // Update state
    _updateState(SessionState.initial);
  }

  /// Get all active sessions for current user
  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    if (!_state.isAuthenticated) return [];

    try {
      return await _firestoreService.getUserSessions(_state.user!.uid);
    } catch (e) {
      return [];
    }
  }

  /// Revoke a specific session (for admin/remote logout)
  Future<void> revokeSession(String deviceId) async {
    if (!_state.isAuthenticated) return;

    try {
      await _firestoreService.deactivateSession(_state.user!.uid, deviceId);

      // If this is the current device, logout locally
      if (deviceId == _state.deviceId) {
        await logout();
      }
    } catch (e) {
      // Handle error
    }
  }

  /// Check session expiration
  Future<void> checkSessionExpiration() async {
    if (!_state.isAuthenticated) return;

    final isExpired = await _tokenService.isSessionExpired();
    final isExpiringSoon = await _tokenService.isSessionExpiringSoon();

    if (isExpired) {
      // Auto-logout expired session
      await logout();
    } else if (isExpiringSoon) {
      // Notify that session is expiring soon
      _updateState(_state.copyWith(requiresReauthentication: true));
    }
  }

  /// Refresh ID token if needed
  Future<void> refreshTokenIfNeeded() async {
    if (!_state.isAuthenticated) return;

    final needsRefresh = await _tokenService.needsTokenRefresh();
    if (needsRefresh) {
      await _tokenService.refreshIdToken();
    }
  }

  /// Update state and notify listeners
  void _updateState(SessionState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  /// Cleanup resources
  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
