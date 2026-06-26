import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages Firebase Cloud Messaging tokens for push notifications
class FcmTokenManager {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize FCM and request permissions
  Future<void> initialize({bool requestPermission = true}) async {
    if (requestPermission) {
      await _requestNotificationPermission();
    }

    // Get initial token
    final token = await _messaging.getToken();
    if (token != null) {
      _onTokenReceived(token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_onTokenReceived);
  }

  /// Request notification permission
  Future<void> _requestNotificationPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional notification permission');
    } else {
      print('User declined or has not granted notification permission');
    }
  }

  /// Handle new FCM token
  Future<void> _onTokenReceived(String token) async {
    print('FCM Token: $token');
    // Token should be saved to Firestore when user is authenticated
    // This is handled by the SessionManager
  }

  /// Save FCM token to Firestore for a specific user and device
  Future<void> saveTokenToFirestore({
    required String userId,
    required String deviceId,
    required String token,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('fcmTokens')
          .doc(deviceId)
          .set({
            'token': token,
            'deviceId': deviceId,
            'updatedAt': FieldValue.serverTimestamp(),
            'platform': await _getPlatform(),
          }, SetOptions(merge: true));

      print('FCM token saved for user $userId, device $deviceId');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Remove FCM token from Firestore
  Future<void> removeTokenFromFirestore({
    required String userId,
    required String deviceId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('fcmTokens')
          .doc(deviceId)
          .delete();

      print('FCM token removed for user $userId, device $deviceId');
    } catch (e) {
      print('Error removing FCM token: $e');
    }
  }

  /// Get current FCM token
  Future<String?> getCurrentToken() async {
    return await _messaging.getToken();
  }

  /// Get platform information
  Future<String> _getPlatform() async {
    // You can use Platform.isAndroid, Platform.isIOS, etc.
    // For simplicity, returning a string
    return 'mobile';
  }

  /// Subscribe to topics (optional)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  /// Unsubscribe from topics (optional)
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  /// Handle background messages
  static Future<void> setupBackgroundMessageHandler() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Background message handler
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    print('Handling a background message: ${message.messageId}');
    // Handle background message here
  }

  /// Configure foreground message handling
  void configureForegroundMessageHandling({
    required Function(RemoteMessage) onMessage,
    required Function(RemoteMessage?) onMessageOpenedApp,
  }) {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(onMessage);

    // When the app is opened from a terminated state
    FirebaseMessaging.onMessageOpenedApp.listen(onMessageOpenedApp);
  }

  /// Get notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    return await _messaging.getNotificationSettings();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    await _messaging.deleteToken();
    print('FCM token deleted');
  }
}
