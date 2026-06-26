import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing session data in Firestore
class SessionFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create or update a device session in Firestore
  Future<void> createOrUpdateSession({
    required String userId,
    required String deviceId,
    required Map<String, dynamic> deviceInfo,
    String? fcmToken,
  }) async {
    final sessionData = {
      'deviceId': deviceId,
      'deviceName': deviceInfo['deviceName'] ?? 'Unknown Device',
      'platform': deviceInfo['platform'] ?? 'unknown',
      'platformVersion': deviceInfo['platformVersion'] ?? '',
      'appVersion': deviceInfo['appVersion'] ?? '',
      'lastActive': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'ipAddress': deviceInfo['ipAddress'], // Optional, would need IP service
    };

    // Update session document
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .doc(deviceId)
        .set(sessionData, SetOptions(merge: true));

    // Update FCM token if provided
    if (fcmToken != null) {
      await _updateFcmToken(userId, deviceId, fcmToken);
    }

    // Update user's last active timestamp
    await _firestore.collection('users').doc(userId).update({
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update FCM token for a device
  Future<void> _updateFcmToken(
    String userId,
    String deviceId,
    String fcmToken,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('fcmTokens')
        .doc(deviceId)
        .set({
          'token': fcmToken,
          'updatedAt': FieldValue.serverTimestamp(),
          'deviceId': deviceId,
        }, SetOptions(merge: true));
  }

  /// Get all active sessions for a user
  Future<List<Map<String, dynamic>>> getUserSessions(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
        'lastActive': (data['lastActive'] as Timestamp?)?.toDate(),
        'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
      };
    }).toList();
  }

  /// Check if a specific session is still active
  Future<bool> isSessionActive(String userId, String deviceId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .doc(deviceId)
        .get();

    if (!doc.exists) return false;
    return doc.data()?['isActive'] == true;
  }

  /// Deactivate a session (logout from specific device)
  Future<void> deactivateSession(String userId, String deviceId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .doc(deviceId)
        .update({
          'isActive': false,
          'deactivatedAt': FieldValue.serverTimestamp(),
        });

    // Remove FCM token
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('fcmTokens')
        .doc(deviceId)
        .delete();
  }

  /// Deactivate all sessions (logout from all devices)
  Future<void> deactivateAllSessions(String userId) async {
    final batch = _firestore.batch();

    // Get all active sessions
    final sessionsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .where('isActive', isEqualTo: true)
        .get();

    // Deactivate each session
    for (final doc in sessionsSnapshot.docs) {
      batch.update(doc.reference, {
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Clear all FCM tokens
    final tokensSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('fcmTokens')
        .get();

    for (final doc in tokensSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Update last active timestamp for a session
  Future<void> updateLastActive(String userId, String deviceId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .doc(deviceId)
        .update({'lastActive': FieldValue.serverTimestamp()});
  }

  /// Check for expired sessions (older than 30 days)
  Future<List<String>> getExpiredSessions(String userId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .where('lastActive', isLessThan: thirtyDaysAgo)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Clean up expired sessions
  Future<void> cleanupExpiredSessions(String userId) async {
    final expiredSessions = await getExpiredSessions(userId);

    for (final deviceId in expiredSessions) {
      await deactivateSession(userId, deviceId);
    }
  }

  /// Get session count for a user
  Future<int> getActiveSessionCount(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.size;
  }

  /// Check if user has reached session limit (e.g., 5 devices)
  Future<bool> hasReachedSessionLimit(String userId, {int limit = 5}) async {
    final count = await getActiveSessionCount(userId);
    return count >= limit;
  }

  /// Get the oldest active session
  Future<Map<String, dynamic>?> getOldestSession(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();
    return {
      'id': doc.id,
      ...data,
      'lastActive': (data['lastActive'] as Timestamp?)?.toDate(),
      'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
    };
  }
}
