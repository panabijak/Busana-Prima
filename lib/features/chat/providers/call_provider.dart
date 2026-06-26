import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/call_log.dart';
import '../services/call_service.dart';

/// Singleton CallService provider.
final callServiceProvider = Provider<CallService>((ref) {
  return CallService();
});

/// Stream of call logs for a specific conversation.
final callLogsProvider = StreamProvider.family<List<CallLog>, String>((
  ref,
  conversationId,
) {
  final callService = ref.watch(callServiceProvider);
  return callService.callLogsStream(conversationId);
});

/// Stream of all call logs for the current user.
final userCallLogsProvider = StreamProvider<List<CallLog>>((ref) {
  final callService = ref.watch(callServiceProvider);
  return callService.userCallLogsStream();
});
