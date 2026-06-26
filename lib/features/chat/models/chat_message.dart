import 'package:cloud_firestore/cloud_firestore.dart';

import 'conversation.dart';

/// A single message within a conversation.
///
/// Firestore path: conversations/{conversationId}/messages/{messageId}
class ChatMessage {
  final String id;
  final String senderId;
  final SenderRole senderRole;
  final MessageType type;
  final String content; // Text content or download URL for media
  final MessageMetadata? metadata;
  final MessageStatus status;
  final Map<String, DateTime> readBy;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.type,
    required this.content,
    this.metadata,
    this.status = MessageStatus.sent,
    this.readBy = const {},
    required this.createdAt,
  });

  /// Whether this message was sent by the given user.
  bool isSentBy(String userId) => senderId == userId;

  /// Whether the message has been read by a specific user.
  bool isReadBy(String userId) => readBy.containsKey(userId);

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderRole: SenderRole.fromString(data['senderRole']),
      type: MessageType.fromString(data['type']),
      content: data['content'] ?? '',
      metadata: data['metadata'] != null
          ? MessageMetadata.fromMap(data['metadata'] as Map<String, dynamic>)
          : null,
      status: MessageStatus.fromString(data['status']),
      readBy: _parseReadBy(data['readBy']),
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'senderRole': senderRole.toFirestore(),
    'type': type.toFirestore(),
    'content': content,
    'metadata': metadata?.toMap(),
    'status': status.toFirestore(),
    'readBy': readBy.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static Map<String, DateTime> _parseReadBy(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return value.map((k, v) {
        DateTime dt;
        if (v is Timestamp) {
          dt = v.toDate();
        } else if (v is DateTime) {
          dt = v;
        } else {
          dt = DateTime.now();
        }
        return MapEntry(k.toString(), dt);
      });
    }
    return {};
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Metadata for media/file messages.
class MessageMetadata {
  final String? fileName;
  final int? fileSize; // bytes
  final String? mimeType;
  final int? duration; // seconds (for video)
  final String? thumbnailUrl;
  final int? width;
  final int? height;

  const MessageMetadata({
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.duration,
    this.thumbnailUrl,
    this.width,
    this.height,
  });

  /// Human-readable file size (e.g. "2.4 MB").
  String get fileSizeLabel {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Human-readable duration (e.g. "1:23").
  String get durationLabel {
    if (duration == null) return '';
    final mins = duration! ~/ 60;
    final secs = duration! % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  factory MessageMetadata.fromMap(Map<String, dynamic> map) => MessageMetadata(
    fileName: map['fileName'] as String?,
    fileSize: (map['fileSize'] as num?)?.toInt(),
    mimeType: map['mimeType'] as String?,
    duration: (map['duration'] as num?)?.toInt(),
    thumbnailUrl: map['thumbnailUrl'] as String?,
    width: (map['width'] as num?)?.toInt(),
    height: (map['height'] as num?)?.toInt(),
  );

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (fileName != null) map['fileName'] = fileName;
    if (fileSize != null) map['fileSize'] = fileSize;
    if (mimeType != null) map['mimeType'] = mimeType;
    if (duration != null) map['duration'] = duration;
    if (thumbnailUrl != null) map['thumbnailUrl'] = thumbnailUrl;
    if (width != null) map['width'] = width;
    if (height != null) map['height'] = height;
    return map;
  }
}

/// Who sent the message.
enum SenderRole {
  customer,
  tailor;

  static SenderRole fromString(String? value) {
    if (value == 'tailor') return SenderRole.tailor;
    return SenderRole.customer;
  }

  String toFirestore() {
    switch (this) {
      case SenderRole.customer:
        return 'customer';
      case SenderRole.tailor:
        return 'tailor';
    }
  }
}

/// Delivery/read status of a message.
enum MessageStatus {
  sent,
  delivered,
  seen;

  static MessageStatus fromString(String? value) {
    switch (value) {
      case 'delivered':
        return MessageStatus.delivered;
      case 'seen':
        return MessageStatus.seen;
      default:
        return MessageStatus.sent;
    }
  }

  String toFirestore() {
    switch (this) {
      case MessageStatus.sent:
        return 'sent';
      case MessageStatus.delivered:
        return 'delivered';
      case MessageStatus.seen:
        return 'seen';
    }
  }
}
