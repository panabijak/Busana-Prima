import 'package:cloud_firestore/cloud_firestore.dart';

/// Record of a voice or video call between customer and tailor.
///
/// Firestore collection: call_logs/{callId}
class CallLog {
  final String id;
  final String conversationId;
  final String orderId;
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final CallType callType;
  final CallStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int duration; // seconds

  const CallLog({
    required this.id,
    required this.conversationId,
    required this.orderId,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required this.callType,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.duration = 0,
  });

  /// Human-readable duration (e.g. "2:05").
  String get durationLabel {
    if (duration == 0) return '';
    final mins = duration ~/ 60;
    final secs = duration % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  /// Whether the call was missed (not answered).
  bool get isMissed => status == CallStatus.missed;

  factory CallLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CallLog(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      orderId: data['orderId'] ?? '',
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      callType: CallType.fromString(data['callType']),
      status: CallStatus.fromString(data['status']),
      startedAt: _parseTimestamp(data['startedAt']) ?? DateTime.now(),
      endedAt: _parseTimestamp(data['endedAt']),
      duration: (data['duration'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'conversationId': conversationId,
    'orderId': orderId,
    'callerId': callerId,
    'callerName': callerName,
    'receiverId': receiverId,
    'receiverName': receiverName,
    'callType': callType.toFirestore(),
    'status': status.toFirestore(),
    'startedAt': Timestamp.fromDate(startedAt),
    'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    'duration': duration,
  };

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Type of call.
enum CallType {
  voice,
  video;

  static CallType fromString(String? value) {
    if (value == 'video') return CallType.video;
    return CallType.voice;
  }

  String toFirestore() {
    switch (this) {
      case CallType.voice:
        return 'voice';
      case CallType.video:
        return 'video';
    }
  }

  String get label {
    switch (this) {
      case CallType.voice:
        return 'Voice Call';
      case CallType.video:
        return 'Video Call';
    }
  }
}

/// Status of the call.
enum CallStatus {
  ringing,
  completed,
  missed,
  declined;

  static CallStatus fromString(String? value) {
    switch (value) {
      case 'completed':
        return CallStatus.completed;
      case 'missed':
        return CallStatus.missed;
      case 'declined':
        return CallStatus.declined;
      default:
        return CallStatus.ringing;
    }
  }

  String toFirestore() {
    switch (this) {
      case CallStatus.ringing:
        return 'ringing';
      case CallStatus.completed:
        return 'completed';
      case CallStatus.missed:
        return 'missed';
      case CallStatus.declined:
        return 'declined';
    }
  }

  String get label {
    switch (this) {
      case CallStatus.ringing:
        return 'Ringing';
      case CallStatus.completed:
        return 'Completed';
      case CallStatus.missed:
        return 'Missed';
      case CallStatus.declined:
        return 'Declined';
    }
  }
}
