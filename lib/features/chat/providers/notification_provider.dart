import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';

/// Singleton provider for the ChatNotificationService.
final chatNotificationServiceProvider = Provider<ChatNotificationService>((
  ref,
) {
  return ChatNotificationService();
});

/// Provider to check if notifications are enabled.
final notificationsEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(chatNotificationServiceProvider);
  return service.areNotificationsEnabled();
});
