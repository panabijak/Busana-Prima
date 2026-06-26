import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session_manager.dart';
import '../services/device_info_service.dart';
import '../services/token_service.dart';
import '../services/session_firestore_service.dart';
import '../services/fcm_token_manager.dart';
import '../models/session_state.dart';

/// Provider for DeviceInfoService
final deviceInfoServiceProvider = Provider((ref) => DeviceInfoService());

/// Provider for TokenService
final tokenServiceProvider = Provider((ref) => TokenService());

/// Provider for SessionFirestoreService
final sessionFirestoreServiceProvider = Provider(
  (ref) => SessionFirestoreService(),
);

/// Provider for FcmTokenManager
final fcmTokenManagerProvider = Provider((ref) => FcmTokenManager());

/// Main session manager provider
final sessionManagerProvider = ChangeNotifierProvider<SessionManager>((ref) {
  return SessionManager(
    deviceInfoService: ref.watch(deviceInfoServiceProvider),
    tokenService: ref.watch(tokenServiceProvider),
    firestoreService: ref.watch(sessionFirestoreServiceProvider),
    fcmTokenManager: ref.watch(fcmTokenManagerProvider),
  );
});

/// Session state provider (read-only)
final sessionStateProvider = Provider<SessionState>((ref) {
  return ref.watch(sessionManagerProvider).state;
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(sessionStateProvider).isAuthenticated;
});

/// Current user provider
final currentUserProvider = Provider((ref) {
  return ref.watch(sessionStateProvider).user;
});

/// Session validation provider
final isSessionValidProvider = Provider<bool>((ref) {
  final state = ref.watch(sessionStateProvider);
  return state.isAuthenticated && state.isSessionValid;
});

/// Session loading provider
final isSessionLoadingProvider = Provider<bool>((ref) {
  return ref.watch(sessionStateProvider).isLoading;
});

/// Session error provider
final sessionErrorProvider = Provider<String?>((ref) {
  return ref.watch(sessionStateProvider).error;
});

/// Session requires reauthentication provider
final requiresReauthenticationProvider = Provider<bool>((ref) {
  return ref.watch(sessionStateProvider).requiresReauthentication;
});

/// Session expiration provider
final isSessionExpiringSoonProvider = Provider<bool>((ref) {
  final state = ref.watch(sessionStateProvider);
  return state.isExpiringSoon;
});

/// Session expired provider
final isSessionExpiredProvider = Provider<bool>((ref) {
  final state = ref.watch(sessionStateProvider);
  return state.isExpired;
});

/// Device ID provider
final deviceIdProvider = Provider<String?>((ref) {
  return ref.watch(sessionStateProvider).deviceId;
});

/// Session age provider
final sessionAgeProvider = Provider<int?>((ref) {
  final state = ref.watch(sessionStateProvider);
  if (state.sessionCreatedAt == null) return null;
  final now = DateTime.now();
  return now.difference(state.sessionCreatedAt!).inDays;
});

/// Active sessions provider (for current user)
final activeSessionsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final sessionManager = ref.watch(sessionManagerProvider);
  final state = ref.watch(sessionStateProvider);

  if (!state.isAuthenticated) return [];

  try {
    return await sessionManager.getActiveSessions();
  } catch (e) {
    return [];
  }
});

/// Session count provider
final activeSessionCountProvider = Provider<int>((ref) {
  final sessions = ref.watch(activeSessionsProvider);
  return sessions.value?.length ?? 0;
});

/// Check if user has reached session limit
final hasReachedSessionLimitProvider = Provider<bool>((ref) {
  final count = ref.watch(activeSessionCountProvider);
  return count >= 5; // Limit of 5 concurrent sessions
});

/// Provider for session initialization
final sessionInitializedProvider = FutureProvider<void>((ref) async {
  final sessionManager = ref.watch(sessionManagerProvider);
  await sessionManager.initializeSession();
});

/// Provider for session validation
final validateSessionProvider = FutureProvider.autoDispose<bool>((ref) async {
  final sessionManager = ref.watch(sessionManagerProvider);
  return await sessionManager.validateSession();
});

/// Provider for checking session expiration
final checkSessionExpirationProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final sessionManager = ref.watch(sessionManagerProvider);
  await sessionManager.checkSessionExpiration();
});

/// Provider for token refresh
final refreshTokenProvider = FutureProvider.autoDispose<void>((ref) async {
  final sessionManager = ref.watch(sessionManagerProvider);
  await sessionManager.refreshTokenIfNeeded();
});

/// Provider for logout
final logoutProvider = FutureProvider.autoDispose<void>((ref) async {
  final sessionManager = ref.watch(sessionManagerProvider);
  await sessionManager.logout();
});

/// Provider for logout all devices
final logoutAllDevicesProvider = FutureProvider.autoDispose<void>((ref) async {
  final sessionManager = ref.watch(sessionManagerProvider);
  await sessionManager.logoutAllDevices();
});

/// Provider for updating last active
final updateLastActiveProvider = FutureProvider.autoDispose<void>((ref) async {
  final sessionManager = ref.watch(sessionManagerProvider);
  await sessionManager.updateLastActive();
});

/// Provider for revoking a specific session
final revokeSessionProvider = FutureProvider.family.autoDispose<void, String>((
  ref,
  deviceId,
) async {
  final sessionManager = ref.watch(sessionManagerProvider);
  await sessionManager.revokeSession(deviceId);
});
