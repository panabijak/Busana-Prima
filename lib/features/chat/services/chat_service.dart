import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/conversation.dart';
import '../models/chat_message.dart';

/// Service for managing order-based conversations and messages.
///
/// Firestore structure:
///   conversations/{conversationId}
///   conversations/{conversationId}/messages/{messageId}
///
/// Key rule: ONE conversation per order. If a conversation already
/// exists for an orderId, it is reused (never duplicated).
class ChatService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Kak Dah's UID — the single tailor in the system.
  static const String tailorUid = 'ZF6sJA84xjgLdWZ4RVbnapPuozc2';
  static const String tailorName = 'Busana Prima Tailor';

  ChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _conversationsRef =>
      _firestore.collection('conversations');

  CollectionReference _messagesRef(String conversationId) =>
      _conversationsRef.doc(conversationId).collection('messages');

  // ─── Conversation Management ────────────────────────────────────────────

  /// Get or create a conversation for a specific order.
  ///
  /// Ensures only ONE conversation per order. If one already exists,
  /// returns it. Otherwise creates a new one.
  Future<Conversation> getOrCreateConversation({
    required String orderId,
    required String orderNumber,
    required String customerId,
    required String customerName,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    // Check if conversation already exists for this order
    final existing = await _conversationsRef
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      debugPrint('[ChatService] Reusing conversation for order: $orderId');
      return Conversation.fromFirestore(existing.docs.first);
    }

    // Create new conversation
    final now = DateTime.now();
    final conversation = Conversation(
      id: '', // Will be set by Firestore
      orderId: orderId,
      orderNumber: orderNumber,
      customerId: customerId,
      customerName: customerName,
      tailorId: tailorUid,
      tailorName: tailorName,
      unreadCount: {customerId: 0, tailorUid: 0},
      status: ConversationStatus.active,
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await _conversationsRef.add(conversation.toMap());
    debugPrint(
      '[ChatService] Created conversation ${docRef.id} for order: $orderId',
    );

    // Send system message to welcome the conversation
    await _sendSystemMessage(
      conversationId: docRef.id,
      text: 'Conversation started for Order $orderNumber',
    );

    return Conversation(
      id: docRef.id,
      orderId: conversation.orderId,
      orderNumber: conversation.orderNumber,
      customerId: conversation.customerId,
      customerName: conversation.customerName,
      tailorId: conversation.tailorId,
      tailorName: conversation.tailorName,
      unreadCount: conversation.unreadCount,
      status: conversation.status,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
    );
  }

  /// Stream all conversations for the current user (customer side).
  /// Ordered by most recent activity.
  Stream<List<Conversation>> userConversationsStream() {
    if (_userId == null) return Stream.value([]);

    return _conversationsRef
        .where('customerId', isEqualTo: _userId)
        .where('status', isEqualTo: 'active')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => Conversation.fromFirestore(doc)).toList(),
        );
  }

  /// Stream a single conversation by order ID.
  /// Returns null if no conversation exists yet.
  Stream<Conversation?> conversationByOrderStream(String orderId) {
    if (_userId == null) return Stream.value(null);

    return _conversationsRef
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return Conversation.fromFirestore(snap.docs.first);
        });
  }

  /// Get the total unread message count across all conversations.
  Stream<int> totalUnreadStream() {
    if (_userId == null) return Stream.value(0);

    return _conversationsRef
        .where('customerId', isEqualTo: _userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) {
          int total = 0;
          for (final doc in snap.docs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final unread = data['unreadCount'] as Map<String, dynamic>? ?? {};
            total += (unread[_userId] as num?)?.toInt() ?? 0;
          }
          return total;
        });
  }

  // ─── Messaging ──────────────────────────────────────────────────────────

  /// Send a text or media message.
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
    MessageMetadata? metadata,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final now = DateTime.now();
    final message = ChatMessage(
      id: '',
      senderId: _userId!,
      senderRole: SenderRole.customer, // This app is customer-only
      type: type,
      content: content,
      metadata: metadata,
      status: MessageStatus.sent,
      readBy: {_userId!: now},
      createdAt: now,
    );

    // Write message to subcollection
    final docRef = await _messagesRef(conversationId).add(message.toMap());

    // Update conversation's lastMessage and increment unread for tailor
    final lastMessageText = type == MessageType.text
        ? content
        : type.displayLabel;

    await _conversationsRef.doc(conversationId).update({
      'lastMessage': {
        'text': lastMessageText,
        'senderId': _userId,
        'type': type.toFirestore(),
        'timestamp': Timestamp.fromDate(now),
      },
      'updatedAt': Timestamp.fromDate(now),
      // Increment tailor's unread count (the receiver)
      'unreadCount.$tailorUid': FieldValue.increment(1),
    });

    debugPrint(
      '[ChatService] Message sent: ${docRef.id} (type: ${type.toFirestore()})',
    );

    return ChatMessage(
      id: docRef.id,
      senderId: message.senderId,
      senderRole: message.senderRole,
      type: message.type,
      content: message.content,
      metadata: message.metadata,
      status: message.status,
      readBy: message.readBy,
      createdAt: message.createdAt,
    );
  }

  /// Stream messages for a conversation (paginated, most recent first).
  Stream<List<ChatMessage>> messagesStream(
    String conversationId, {
    int limit = 50,
  }) {
    return _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList(),
        );
  }

  /// Load older messages before a specific timestamp (for pagination).
  Future<List<ChatMessage>> loadOlderMessages(
    String conversationId, {
    required DateTime before,
    int limit = 20,
  }) async {
    final snap = await _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();

    return snap.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
  }

  /// Mark all messages in a conversation as read by the current user.
  /// Also resets the unread counter.
  Future<void> markAsRead(String conversationId) async {
    if (_userId == null) return;

    // Reset the unread count for the current user
    await _conversationsRef.doc(conversationId).update({
      'unreadCount.$_userId': 0,
    });

    debugPrint('[ChatService] Marked conversation $conversationId as read');
  }

  // ─── Private Helpers ────────────────────────────────────────────────────

  /// Send a system message (e.g. "Conversation started for Order #BP-1001").
  Future<void> _sendSystemMessage({
    required String conversationId,
    required String text,
  }) async {
    final now = DateTime.now();
    await _messagesRef(conversationId).add({
      'senderId': 'system',
      'senderRole': 'system',
      'type': 'system',
      'content': text,
      'status': 'sent',
      'readBy': {},
      'createdAt': Timestamp.fromDate(now),
    });
  }
}
