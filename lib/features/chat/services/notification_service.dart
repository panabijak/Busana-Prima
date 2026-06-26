import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for handling push notifications related to chat.
///
/// Responsibilities:
/// - Display local notifications when app is in foreground
/// - Handle notification taps (deep-linking to order chat)
/// - Parse incoming FCM messages for chat events
/// - Provide notification channel setup for Android
///
/// Works alongside the existing FcmTokenManager (which handles
/// token registration). This service handles message display/routing.
class ChatNotificationService {
  static final ChatNotificationService _instance =
      ChatNotificationService._internal();
  factory ChatNotificationService() => _instance;
  ChatNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Callback when a notification is tapped.
  /// Passes the payload data (orderId, conversationId).
  void Function(Map<String, dynamic> data)? onNotificationTap;

  // ─── Initialization ─────────────────────────────────────────────────────

  /// Initialize the notification service.
  /// Call this once during app startup (after Firebase.initializeApp).
  Future<void> initialize() async {
    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create Android notification channel
    await _createNotificationChannel();

    // Configure FCM message handlers
    _configureFcmHandlers();

    debugPrint('[ChatNotificationService] Initialized');
  }

  /// Create the Android notification channel for chat messages.
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'busana_prima_chat',
      'Chat Messages',
      description: 'Notifications for new messages from your tailor',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // ─── FCM Handlers ──────────────────────────────────────────────────────

  /// Configure foreground and background FCM message handling.
  void _configureFcmHandlers() {
    // Foreground messages — show local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // When user taps notification while app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Check if app was opened from a terminated state via notification
    _checkInitialMessage();
  }

  /// Handle FCM message when app is in foreground.
  /// Shows a local notification so the user can see it.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint(
      '[ChatNotificationService] Foreground message: ${message.messageId}',
    );

    final data = message.data;
    final notification = message.notification;

    // Only show notification if it's a chat-related message
    if (data['type'] == 'new_message' ||
        data['type'] == 'missed_call' ||
        data['type'] == 'new_attachment') {
      await _showLocalNotification(
        title: notification?.title ?? _buildTitle(data),
        body: notification?.body ?? _buildBody(data),
        payload: data,
      );
    }
  }

  /// Handle notification tap when app is in background/terminated.
  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint(
      '[ChatNotificationService] Notification opened: ${message.messageId}',
    );
    _navigateFromNotification(message.data);
  }

  /// Check if app was launched from a notification.
  Future<void> _checkInitialMessage() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[ChatNotificationService] App opened from notification');
      // Delay slightly to let router initialize
      await Future.delayed(const Duration(milliseconds: 500));
      _navigateFromNotification(initialMessage.data);
    }
  }

  // ─── Local Notification Display ─────────────────────────────────────────

  /// Show a local notification with chat-specific styling.
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'busana_prima_chat',
      'Chat Messages',
      channelDescription: 'Notifications for new messages from your tailor',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use a unique ID based on timestamp
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: jsonEncode(payload),
    );
  }

  // ─── Notification Response ──────────────────────────────────────────────

  /// Called when user taps a local notification.
  void _onNotificationResponse(NotificationResponse response) {
    debugPrint(
      '[ChatNotificationService] Notification tapped: ${response.payload}',
    );
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateFromNotification(data);
      } catch (e) {
        debugPrint('[ChatNotificationService] Failed to parse payload: $e');
      }
    }
  }

  /// Navigate to the appropriate screen based on notification data.
  void _navigateFromNotification(Map<String, dynamic> data) {
    if (onNotificationTap != null) {
      onNotificationTap!(data);
    }
  }

  // ─── Notification Content Builders ──────────────────────────────────────

  /// Build notification title from FCM data payload.
  String _buildTitle(Map<String, dynamic> data) {
    final type = data['type'];
    switch (type) {
      case 'new_message':
        return 'New Message';
      case 'missed_call':
        return 'Missed Call';
      case 'new_attachment':
        return 'New Attachment';
      default:
        return 'Busana Prima';
    }
  }

  /// Build notification body from FCM data payload.
  String _buildBody(Map<String, dynamic> data) {
    final type = data['type'];
    final orderNumber = data['orderNumber'] ?? '';

    switch (type) {
      case 'new_message':
        final message = data['message'] ?? 'sent a message';
        return orderNumber.isNotEmpty
            ? 'Tailor $message — Order $orderNumber'
            : 'Tailor $message';
      case 'missed_call':
        final callType = data['callType'] ?? 'voice';
        return 'Missed $callType call — Order $orderNumber';
      case 'new_attachment':
        return 'Tailor shared a file — Order $orderNumber';
      default:
        return 'You have a new notification';
    }
  }

  // ─── Topic Subscriptions ────────────────────────────────────────────────

  /// Subscribe to order-specific notification topic.
  /// Topic format: "order_{orderId}"
  Future<void> subscribeToOrder(String orderId) async {
    final topic = 'order_$orderId';
    await FirebaseMessaging.instance.subscribeToTopic(topic);
    debugPrint('[ChatNotificationService] Subscribed to topic: $topic');
  }

  /// Unsubscribe from order-specific notification topic.
  Future<void> unsubscribeFromOrder(String orderId) async {
    final topic = 'order_$orderId';
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    debugPrint('[ChatNotificationService] Unsubscribed from topic: $topic');
  }

  // ─── Permission Check ──────────────────────────────────────────────────

  /// Check if notifications are enabled.
  Future<bool> areNotificationsEnabled() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Request notification permission (if not already granted).
  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}

/// Background message handler — must be top-level function.
/// This is called when FCM messages arrive while the app is terminated.
@pragma('vm:entry-point')
Future<void> chatBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[ChatNotification] Background message: ${message.messageId}');
  // Background messages are handled automatically by FCM
  // The system notification tray will show them
  // No local notification needed here
}
