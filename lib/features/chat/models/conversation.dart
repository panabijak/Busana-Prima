import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a conversation linked to a specific order.
///
/// Firestore collection: conversations/{conversationId}
/// One conversation per order — enforced at creation time.
class Conversation {
  final String id;
  final String orderId;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String tailorId;
  final String tailorName;
  final LastMessage? lastMessage;
  final Map<String, int> unreadCount;
  final ConversationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.tailorId,
    this.tailorName = 'Kak Dah',
    this.lastMessage,
    this.unreadCount = const {},
    this.status = ConversationStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether there are unread messages for a specific user.
  int unreadFor(String userId) => unreadCount[userId] ?? 0;

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Conversation(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      orderNumber: data['orderNumber'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      tailorId: data['tailorId'] ?? '',
      tailorName: data['tailorName'] ?? 'Kak Dah',
      lastMessage: _parseLastMessage(data['lastMessage']),
      unreadCount: _parseUnreadCount(data['unreadCount']),
      status: ConversationStatus.fromString(data['status']),
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'orderNumber': orderNumber,
    'customerId': customerId,
    'customerName': customerName,
    'tailorId': tailorId,
    'tailorName': tailorName,
    'lastMessage': lastMessage?.toMap(),
    'unreadCount': unreadCount,
    'status': status.toFirestore(),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  static Map<String, int> _parseUnreadCount(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return value.map((k, v) {
        final intVal = v is num ? v.toInt() : 0;
        return MapEntry(k.toString(), intVal);
      });
    }
    return {};
  }

  static LastMessage? _parseLastMessage(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      return LastMessage.fromMap(value);
    }
    if (value is Map) {
      return LastMessage.fromMap(Map<String, dynamic>.from(value));
    }
    // If tailor app stored it as a plain string, wrap it
    if (value is String) {
      return LastMessage(
        text: value,
        senderId: '',
        type: MessageType.text,
        timestamp: DateTime.now(),
      );
    }
    return null;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Denormalized last message stored on the conversation document.
/// Avoids reading the messages subcollection for the conversation list.
class LastMessage {
  final String text;
  final String senderId;
  final MessageType type;
  final DateTime timestamp;

  const LastMessage({
    required this.text,
    required this.senderId,
    required this.type,
    required this.timestamp,
  });

  factory LastMessage.fromMap(Map<String, dynamic> map) => LastMessage(
    text: map['text'] ?? '',
    senderId: map['senderId'] ?? '',
    type: MessageType.fromString(map['type']),
    timestamp: Conversation._parseTimestamp(map['timestamp']) ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'text': text,
    'senderId': senderId,
    'type': type.toFirestore(),
    'timestamp': Timestamp.fromDate(timestamp),
  };
}

/// Conversation status.
enum ConversationStatus {
  active,
  archived;

  static ConversationStatus fromString(String? value) {
    if (value == 'archived') return ConversationStatus.archived;
    return ConversationStatus.active;
  }

  String toFirestore() {
    switch (this) {
      case ConversationStatus.active:
        return 'active';
      case ConversationStatus.archived:
        return 'archived';
    }
  }
}

/// Message type enum (shared with ChatMessage model).
enum MessageType {
  text,
  image,
  video,
  file,
  system;

  static MessageType fromString(String? value) {
    switch (value) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'file':
        return MessageType.file;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  String toFirestore() {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.video:
        return 'video';
      case MessageType.file:
        return 'file';
      case MessageType.system:
        return 'system';
    }
  }

  /// Display label for system messages and attachment previews.
  String get displayLabel {
    switch (this) {
      case MessageType.text:
        return '';
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.file:
        return '📄 Document';
      case MessageType.system:
        return '';
    }
  }
}
