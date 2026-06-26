import 'package:firebase_auth/firebase_auth.dart';

/// Represents the current authentication session state
class SessionState {
  final bool isAuthenticated;
  final User? user;
  final String? deviceId;
  final DateTime? sessionCreatedAt;
  final DateTime? lastActiveAt;
  final bool isLoading;
  final String? error;
  final bool isSessionValid;
  final bool requiresReauthentication;

  const SessionState({
    this.isAuthenticated = false,
    this.user,
    this.deviceId,
    this.sessionCreatedAt,
    this.lastActiveAt,
    this.isLoading = false,
    this.error,
    this.isSessionValid = false,
    this.requiresReauthentication = false,
  });

  /// Check if there's a persistent session that can be restored
  bool get hasPersistentSession => deviceId != null && isAuthenticated;

  /// Check if session is expired (more than 30 days inactive)
  bool get isExpired {
    if (lastActiveAt == null) return false;
    final now = DateTime.now();
    return now.difference(lastActiveAt!).inDays > 30;
  }

  /// Check if session is about to expire (within 5 days)
  bool get isExpiringSoon {
    if (lastActiveAt == null) return false;
    final now = DateTime.now();
    return now.difference(lastActiveAt!).inDays > 25;
  }

  SessionState copyWith({
    bool? isAuthenticated,
    User? user,
    String? deviceId,
    DateTime? sessionCreatedAt,
    DateTime? lastActiveAt,
    bool? isLoading,
    String? error,
    bool? isSessionValid,
    bool? requiresReauthentication,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return SessionState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: clearUser ? null : (user ?? this.user),
      deviceId: deviceId ?? this.deviceId,
      sessionCreatedAt: sessionCreatedAt ?? this.sessionCreatedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSessionValid: isSessionValid ?? this.isSessionValid,
      requiresReauthentication:
          requiresReauthentication ?? this.requiresReauthentication,
    );
  }

  /// Initial loading state
  static const SessionState initial = SessionState();

  /// Loading state
  static const SessionState loading = SessionState(isLoading: true);

  /// Error state factory
  factory SessionState.error(String message) {
    return SessionState(error: message, isLoading: false);
  }

  /// Authenticated state factory
  factory SessionState.authenticated({
    required User user,
    required String deviceId,
    DateTime? sessionCreatedAt,
    DateTime? lastActiveAt,
  }) {
    return SessionState(
      isAuthenticated: true,
      user: user,
      deviceId: deviceId,
      sessionCreatedAt: sessionCreatedAt ?? DateTime.now(),
      lastActiveAt: lastActiveAt ?? DateTime.now(),
      isSessionValid: true,
    );
  }
}
