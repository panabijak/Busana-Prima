import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/call_log.dart';
import 'chat_service.dart';

/// Service for managing voice/video calls via ZegoCloud.
///
/// This service handles:
/// - Initiating calls (generating room IDs)
/// - Logging calls to Firestore
/// - Retrieving call history per conversation
///
/// ZegoCloud integration uses their prebuilt Call Kit UI component,
/// so actual call signaling and UI is handled by the SDK.
/// This service manages the app-specific call metadata and logs.
class CallService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CallService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;
  String get _userName => _auth.currentUser?.displayName ?? 'Customer';

  /// ZegoCloud credentials.
  static const int zegoAppId = 1760134576;
  static const String zegoAppSign =
      '25d1f2b54a44fa8290edbdc66ace534fbf069d07aec4b931d47eb12afb6ccc36';

  /// Generate a unique call/room ID based on conversation.
  /// ZegoCloud requires alphanumeric + underscore only.
  String generateCallId(String conversationId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Clean conversation ID to only contain valid characters
    final cleanId = conversationId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    return 'call_${cleanId}_$timestamp';
  }

  /// Get the Zego user ID for the current user.
  /// Must be consistent across sessions for ZegoCloud to identify the user.
  String get zegoUserId => _userId ?? 'anonymous';

  /// Get the Zego user name for display.
  String get zegoUserName => _userName;

  /// Tailor's Zego user ID (Kak Dah).
  String get tailorZegoUserId => ChatService.tailorUid;

  /// Tailor's display name.
  String get tailorZegoUserName => ChatService.tailorName;

  // ─── Call Logging ───────────────────────────────────────────────────────

  /// Log a call that was initiated.
  Future<String> logCallStarted({
    required String conversationId,
    required String orderId,
    required CallType callType,
    required String receiverId,
    required String receiverName,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final callLog = CallLog(
      id: '',
      conversationId: conversationId,
      orderId: orderId,
      callerId: _userId!,
      callerName: _userName,
      receiverId: receiverId,
      receiverName: receiverName,
      callType: callType,
      status: CallStatus.ringing,
      startedAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('call_logs')
        .add(callLog.toMap());
    debugPrint('[CallService] Call logged: ${docRef.id} (${callType.label})');
    return docRef.id;
  }

  /// Update call log when call is completed.
  Future<void> logCallCompleted({
    required String callLogId,
    required int durationSeconds,
  }) async {
    await _firestore.collection('call_logs').doc(callLogId).update({
      'status': CallStatus.completed.toFirestore(),
      'endedAt': Timestamp.fromDate(DateTime.now()),
      'duration': durationSeconds,
    });
    debugPrint(
      '[CallService] Call completed: $callLogId (${durationSeconds}s)',
    );
  }

  /// Update call log when call is missed.
  Future<void> logCallMissed({required String callLogId}) async {
    await _firestore.collection('call_logs').doc(callLogId).update({
      'status': CallStatus.missed.toFirestore(),
      'endedAt': Timestamp.fromDate(DateTime.now()),
    });
    debugPrint('[CallService] Call missed: $callLogId');
  }

  /// Update call log when call is declined.
  Future<void> logCallDeclined({required String callLogId}) async {
    await _firestore.collection('call_logs').doc(callLogId).update({
      'status': CallStatus.declined.toFirestore(),
      'endedAt': Timestamp.fromDate(DateTime.now()),
    });
    debugPrint('[CallService] Call declined: $callLogId');
  }

  // ─── Call History ───────────────────────────────────────────────────────

  /// Stream call logs for a specific conversation.
  Stream<List<CallLog>> callLogsStream(String conversationId) {
    return _firestore
        .collection('call_logs')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('startedAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) => CallLog.fromFirestore(doc)).toList(),
        );
  }

  /// Get recent call logs for the current user (across all conversations).
  Stream<List<CallLog>> userCallLogsStream() {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('call_logs')
        .where('callerId', isEqualTo: _userId)
        .orderBy('startedAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) => CallLog.fromFirestore(doc)).toList(),
        );
  }
}
