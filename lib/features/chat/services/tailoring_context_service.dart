import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../order/models/order_model.dart';
import '../models/conversation.dart';

/// Service for sending tailoring-specific system messages and context
/// updates within order-linked conversations.
///
/// This service bridges the order workflow with the communication center.
/// When tailoring status changes happen (via tailor's admin panel/Rowy),
/// system messages are automatically sent to inform the customer.
class TailoringContextService {
  final FirebaseFirestore _firestore;

  TailoringContextService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Send a system message when order status changes.
  /// Called from a Firestore trigger or when the app detects a status change.
  Future<void> notifyStatusChange({
    required String orderId,
    required OrderStatus oldStatus,
    required OrderStatus newStatus,
  }) async {
    final conversationId = await _getConversationIdForOrder(orderId);
    if (conversationId == null) return;

    final message = _buildStatusChangeMessage(oldStatus, newStatus);
    await _sendSystemMessage(conversationId, message);
  }

  /// Send a system message when a specific item's status changes.
  Future<void> notifyItemStatusChange({
    required String orderId,
    required String productName,
    required ItemStatus oldStatus,
    required ItemStatus newStatus,
  }) async {
    final conversationId = await _getConversationIdForOrder(orderId);
    if (conversationId == null) return;

    final message = _buildItemStatusMessage(productName, newStatus);
    await _sendSystemMessage(conversationId, message);
  }

  /// Send a system message for fitting schedule.
  Future<void> notifyFittingScheduled({
    required String orderId,
    required DateTime fittingDate,
    required String productName,
  }) async {
    final conversationId = await _getConversationIdForOrder(orderId);
    if (conversationId == null) return;

    final dateStr =
        '${fittingDate.day}/${fittingDate.month}/${fittingDate.year}';
    final message =
        '📅 Fitting session scheduled for "$productName" on $dateStr';
    await _sendSystemMessage(conversationId, message);
  }

  /// Send a system message for fabric received.
  Future<void> notifyFabricReceived({required String orderId}) async {
    final conversationId = await _getConversationIdForOrder(orderId);
    if (conversationId == null) return;

    await _sendSystemMessage(
      conversationId,
      '✅ Fabric received! Tailoring will begin shortly.',
    );
  }

  /// Send a system message when tailor adds notes.
  Future<void> notifyTailorNote({
    required String orderId,
    required String note,
  }) async {
    final conversationId = await _getConversationIdForOrder(orderId);
    if (conversationId == null) return;

    await _sendSystemMessage(conversationId, '📝 Tailor note: $note');
  }

  // ─── Private Helpers ────────────────────────────────────────────────────

  /// Find the conversation ID for an order.
  Future<String?> _getConversationIdForOrder(String orderId) async {
    try {
      final snap = await _firestore
          .collection('conversations')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      return snap.docs.first.id;
    } catch (e) {
      debugPrint('[TailoringContextService] Error finding conversation: $e');
      return null;
    }
  }

  /// Write a system message to the conversation's messages subcollection.
  Future<void> _sendSystemMessage(String conversationId, String text) async {
    final now = DateTime.now();
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
          'senderId': 'system',
          'senderRole': 'system',
          'type': MessageType.system.toFirestore(),
          'content': text,
          'status': 'sent',
          'readBy': {},
          'createdAt': Timestamp.fromDate(now),
        });

    // Update lastMessage on conversation
    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': {
        'text': text,
        'senderId': 'system',
        'type': 'system',
        'timestamp': Timestamp.fromDate(now),
      },
      'updatedAt': Timestamp.fromDate(now),
    });

    debugPrint(
      '[TailoringContextService] System message sent to $conversationId',
    );
  }

  /// Build a human-readable message for order status change.
  String _buildStatusChangeMessage(
    OrderStatus oldStatus,
    OrderStatus newStatus,
  ) {
    switch (newStatus) {
      case OrderStatus.confirmed:
        return '✅ Your order has been confirmed! Tailoring will begin soon.';
      case OrderStatus.inProgress:
        return '🧵 Your order is now in progress. The tailor has started working on your outfit.';
      case OrderStatus.ready:
        return '🎉 Great news! Your order is ready for collection/delivery.';
      case OrderStatus.completed:
        return '✨ Order completed! Thank you for choosing Busana Prima.';
      case OrderStatus.cancelled:
        return '❌ Your order has been cancelled.';
      default:
        return 'Order status updated to: ${newStatus.label}';
    }
  }

  /// Build a human-readable message for item status change.
  String _buildItemStatusMessage(String productName, ItemStatus newStatus) {
    switch (newStatus) {
      case ItemStatus.waitingFabric:
        return '🧵 Waiting for fabric for "$productName"';
      case ItemStatus.cutting:
        return '✂️ Cutting started for "$productName"';
      case ItemStatus.sewing:
        return '🪡 Sewing in progress for "$productName"';
      case ItemStatus.fitting:
        return '👗 "$productName" is ready for fitting';
      case ItemStatus.adjustment:
        return '🔧 Adjustments being made to "$productName"';
      case ItemStatus.qc:
        return '🔍 Quality check in progress for "$productName"';
      case ItemStatus.ready:
        return '✅ "$productName" is ready!';
      case ItemStatus.delivered:
        return '📦 "$productName" has been delivered';
      default:
        return '"$productName" status: ${newStatus.label}';
    }
  }
}
