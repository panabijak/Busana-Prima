import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/chat/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(chatBackgroundMessageHandler);

  // Initialize chat notifications
  final notificationService = ChatNotificationService();
  await notificationService.initialize();

  // Ensure FCM token is registered (even if SessionManager hasn't run yet)
  await _registerFcmToken();

  // Handle deep-link from notification tap
  notificationService.onNotificationTap = (data) {
    final orderId = data['orderId'] as String?;
    if (orderId != null && orderId.isNotEmpty) {
      appRouter.push('/orders/$orderId/chat');
    }
  };

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: BusanaPrimaApp()));
}

/// Root application widget
class BusanaPrimaApp extends StatelessWidget {
  const BusanaPrimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Busana Prima',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}

/// Register FCM token to Firestore so Cloud Functions can send pushes.
/// This runs early to ensure the token is available even before
/// SessionManager fully initializes.
Future<void> _registerFcmToken() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[FCM] No user signed in, skipping token registration');
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      debugPrint('[FCM] Failed to get FCM token (DEVELOPER_ERROR?)');
      debugPrint('[FCM] Check SHA-1 fingerprint in Firebase Console');
      return;
    }

    // Store under users/{uid}/fcmTokens/{simple_device_id}
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('fcmTokens')
        .doc('primary')
        .set({
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
          'deviceId': 'primary',
          'platform': 'android',
        }, SetOptions(merge: true));

    debugPrint('[FCM] Token registered for user ${user.uid}');

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc('primary')
          .set({
            'token': newToken,
            'updatedAt': FieldValue.serverTimestamp(),
            'deviceId': 'primary',
            'platform': 'android',
          }, SetOptions(merge: true));
      debugPrint('[FCM] Token refreshed and saved');
    });
  } catch (e) {
    debugPrint('[FCM] Error registering token: $e');
  }
}
