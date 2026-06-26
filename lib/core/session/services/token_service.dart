import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing authentication tokens
class TokenService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _refreshTokenKey = 'firebase_refresh_token';
  static const String _deviceIdKey = 'device_id';
  static const String _sessionCreatedKey = 'session_created_at';

  /// Store refresh token securely
  Future<void> storeRefreshToken(String refreshToken) async {
    await _secureStorage.write(
      key: _refreshTokenKey,
      value: refreshToken,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      iOptions: const IOSOptions(accessibility: KeychainAccessibility.unlocked),
    );
  }

  /// Get stored refresh token
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  /// Store device ID
  Future<void> storeDeviceId(String deviceId) async {
    await _secureStorage.write(key: _deviceIdKey, value: deviceId);
  }

  /// Get stored device ID
  Future<String?> getDeviceId() async {
    return await _secureStorage.read(key: _deviceIdKey);
  }

  /// Store session creation time
  Future<void> storeSessionCreatedAt(DateTime timestamp) async {
    await _secureStorage.write(
      key: _sessionCreatedKey,
      value: timestamp.toIso8601String(),
    );
  }

  /// Get session creation time
  Future<DateTime?> getSessionCreatedAt() async {
    final value = await _secureStorage.read(key: _sessionCreatedKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Clear all stored tokens and session data
  Future<void> clearAllTokens() async {
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _deviceIdKey);
    await _secureStorage.delete(key: _sessionCreatedKey);
  }

  /// Check if Firebase ID token needs refresh
  Future<bool> needsTokenRefresh() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final tokenResult = await user.getIdTokenResult();
      final expiryTime = tokenResult.expirationTime;
      final now = DateTime.now();

      // Refresh if token expires in less than 5 minutes
      if (expiryTime != null) {
        return expiryTime.difference(now).inMinutes < 5;
      }
    } catch (e) {
      // If we can't check, assume it needs refresh
      return true;
    }

    return false;
  }

  /// Force refresh Firebase ID token
  Future<String?> refreshIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final idToken = await user.getIdToken(true); // Force refresh
      return idToken;
    } catch (e) {
      return null;
    }
  }

  /// Validate current session by checking token validity
  Future<bool> validateSession() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Check if token is valid
      await user.getIdToken(true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current Firebase ID token
  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      return await user.getIdToken();
    } catch (e) {
      return null;
    }
  }

  /// Check if user has a persistent session (has refresh token)
  Future<bool> hasPersistentSession() async {
    final refreshToken = await getRefreshToken();
    final deviceId = await getDeviceId();
    return refreshToken != null && deviceId != null;
  }

  /// Get session age in days
  Future<int?> getSessionAgeInDays() async {
    final createdAt = await getSessionCreatedAt();
    if (createdAt == null) return null;

    final now = DateTime.now();
    return now.difference(createdAt).inDays;
  }

  /// Check if session is expired (more than 30 days)
  Future<bool> isSessionExpired() async {
    final age = await getSessionAgeInDays();
    return age != null && age > 30;
  }

  /// Check if session is expiring soon (25-30 days)
  Future<bool> isSessionExpiringSoon() async {
    final age = await getSessionAgeInDays();
    return age != null && age > 25;
  }
}
