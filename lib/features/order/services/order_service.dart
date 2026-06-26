import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../cart/models/cart_item.dart';
import '../models/order_model.dart';

/// Service for creating and managing orders in Firestore.
///
/// Collection: orders/{orderId}
/// Also stores a copy under: users/{uid}/orders/{orderId} for fast user queries.
///
/// Payment is SIMULATED for FYP demonstration:
/// - Generates realistic transaction IDs and reference numbers
/// - Simulates processing delay (2-3 seconds)
/// - Always approves (configurable for failure testing)
class OrderService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  OrderService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  /// Generate a unique order number: BP-YYYY-XXXX
  String _generateOrderNumber() {
    final now = DateTime.now();
    final random = Random().nextInt(9000) + 1000;
    return 'BP-${now.year}-$random';
  }

  /// Generate a realistic transaction ID (simulates payment gateway).
  String _generateTransactionId() {
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final id = List.generate(
      16,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'TXN-$id';
  }

  /// Generate a realistic reference number.
  String _generateReferenceNumber() {
    final now = DateTime.now();
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  /// Simulate payment processing with realistic delay.
  /// Returns a PaymentRecord on success.
  ///
  /// The simulation:
  /// 1. "Processing Payment..." — 1.5s delay
  /// 2. "Validating Transaction..." — 1s delay
  /// 3. "Payment Approved" — instant
  ///
  /// Set [simulateFailure] to true to test failure path.
  Future<PaymentRecord> simulatePayment({
    required double amount,
    required PaymentMethod paymentMethod,
    required PaymentTerms paymentTerms,
    double totalOrderAmount = 0.0,
    double balanceRemaining = 0.0,
    bool simulateFailure = false,
  }) async {
    // Step 1: Processing
    await Future.delayed(const Duration(milliseconds: 1500));

    // Step 2: Validating
    await Future.delayed(const Duration(milliseconds: 1000));

    if (simulateFailure) {
      throw Exception('Payment declined. Please try again.');
    }

    // Step 3: Approved
    final record = PaymentRecord(
      transactionId: _generateTransactionId(),
      referenceNumber: _generateReferenceNumber(),
      paymentMethod: paymentMethod,
      paymentTerms: paymentTerms,
      amount: amount,
      totalAmount: totalOrderAmount,
      balanceRemaining: balanceRemaining,
      status: 'approved',
      paidAt: DateTime.now(),
    );

    debugPrint('[OrderService] Payment simulated: ${record.transactionId}');
    return record;
  }

  /// Create a complete order from cart items after payment simulation.
  ///
  /// This method:
  /// 1. Creates the order document in `orders` collection
  /// 2. Stores a reference in `users/{uid}/orders/{orderId}`
  /// 3. Returns the created BusanaOrder
  Future<BusanaOrder> createOrder({
    required List<CartItem> cartItems,
    required PaymentRecord payment,
    required DeliveryMethod deliveryMethod,
    required FabricDeliveryMethod fabricDeliveryMethod,
    required String shippingAddress,
    required String customerName,
    required String customerPhone,
    Map<String, dynamic>? addressSnapshot,
    DateTime? fabricDropoffDate,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');
    if (cartItems.isEmpty) throw Exception('Cart is empty');

    final orderNumber = _generateOrderNumber();
    final now = DateTime.now();

    // Calculate totals
    double tailorFeeTotal = 0;
    double fabricTotal = 0;
    final orderItems = <OrderItem>[];

    for (final cartItem in cartItems) {
      // Base price is tailor fee; fabric cost is extra if tailor provides
      final baseTailorFee = cartItem.fabricType == 'tailor'
          ? cartItem.unitPrice -
                50.0 // Deduct fabric cost from unit price
          : cartItem.unitPrice;
      final fabricCost = cartItem.fabricType == 'tailor'
          ? 50.0 * cartItem.quantity
          : 0.0;

      tailorFeeTotal += baseTailorFee * cartItem.quantity;
      fabricTotal += fabricCost;

      orderItems.add(
        OrderItem(
          productId: cartItem.productId,
          productName: cartItem.productName,
          productImageUrl: cartItem.productImageUrl,
          fabricType: cartItem.fabricType,
          selectedColor: cartItem.selectedColor,
          measurementProfileId: cartItem.measurementProfileId,
          sizeLabel: cartItem.sizeLabel,
          quantity: cartItem.quantity,
          unitPrice: cartItem.unitPrice,
          status: ItemStatus.newOrder,
        ),
      );
    }

    final totalAmount = tailorFeeTotal + fabricTotal;

    // Backend enforcement: validate payment amount matches payment terms
    final expectedPayable = payment.paymentTerms == PaymentTerms.deposit50
        ? double.parse((totalAmount * 0.5).toStringAsFixed(2))
        : totalAmount;
    final expectedBalance = totalAmount - expectedPayable;

    // Override payment record with server-validated amounts (tamper-proof)
    final validatedPayment = PaymentRecord(
      transactionId: payment.transactionId,
      referenceNumber: payment.referenceNumber,
      paymentMethod: payment.paymentMethod,
      paymentTerms: payment.paymentTerms,
      amount: expectedPayable,
      totalAmount: totalAmount,
      balanceRemaining: double.parse(expectedBalance.toStringAsFixed(2)),
      status: payment.status,
      paidAt: payment.paidAt,
    );

    final order = BusanaOrder(
      id: '', // Will be set after Firestore creates the doc
      customerId: _userId!,
      customerName: customerName,
      customerPhone: customerPhone,
      items: orderItems,
      payment: validatedPayment,
      deliveryMethod: deliveryMethod,
      fabricDeliveryMethod: fabricDeliveryMethod,
      shippingAddress: shippingAddress,
      addressSnapshot: addressSnapshot,
      fabricDropoffDate: fabricDropoffDate,
      tailorFeeTotal: tailorFeeTotal,
      fabricTotal: fabricTotal,
      totalAmount: totalAmount,
      status: OrderStatus.pending,
      orderDate: now,
      orderNumber: orderNumber,
    );

    // Write to main orders collection
    final docRef = await _firestore.collection('orders').add(order.toMap());

    // Also store a reference under user's subcollection for fast queries
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('orders')
        .doc(docRef.id)
        .set({
          'orderRef': docRef.id,
          'orderNumber': orderNumber,
          'totalAmount': totalAmount,
          'status': OrderStatus.pending.toFirestore(),
          'orderDate': Timestamp.fromDate(now),
          'itemCount': orderItems.length,
        });

    debugPrint('[OrderService] Order created: ${docRef.id} ($orderNumber)');

    // Return with the actual Firestore ID
    return BusanaOrder(
      id: docRef.id,
      customerId: order.customerId,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      items: order.items,
      payment: order.payment,
      deliveryMethod: order.deliveryMethod,
      fabricDeliveryMethod: order.fabricDeliveryMethod,
      shippingAddress: order.shippingAddress,
      addressSnapshot: order.addressSnapshot,
      fabricDropoffDate: order.fabricDropoffDate,
      tailorFeeTotal: order.tailorFeeTotal,
      fabricTotal: order.fabricTotal,
      totalAmount: order.totalAmount,
      status: order.status,
      orderDate: order.orderDate,
      orderNumber: order.orderNumber,
    );
  }

  /// Stream all orders for the current user.
  Stream<List<BusanaOrder>> userOrdersStream() {
    if (_userId == null) return Stream.value([]);
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: _userId)
        .orderBy('orderDate', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => BusanaOrder.fromFirestore(doc)).toList(),
        );
  }

  /// Get a single order by ID.
  Future<BusanaOrder?> getOrder(String orderId) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (!doc.exists) return null;
    return BusanaOrder.fromFirestore(doc);
  }

  /// Cancel an order. Backend-validated: fetches latest status from Firestore
  /// before allowing cancellation.
  ///
  /// Rules:
  /// - Only allowed if order_status is pending or confirmed
  /// - If ANY item has reached cutting or beyond, cancellation is blocked
  /// - Order is marked CANCELLED (never deleted)
  /// - Audit fields stored: cancelled_at, cancelled_by
  /// - Refund status marked as PENDING (manual processing)
  ///
  /// Throws [Exception] if cancellation is not allowed.
  Future<void> cancelOrder(String orderId) async {
    if (_userId == null) throw Exception('User not authenticated');

    // Step 1: Fetch latest order state from Firestore (never trust frontend)
    final docRef = _firestore.collection('orders').doc(orderId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('Order not found');

    final data = doc.data() as Map<String, dynamic>;
    final currentStatus = OrderStatus.fromString(data['status']);

    // Step 2: Validate order-level status
    if (!currentStatus.isCancellable) {
      throw Exception(
        'Order cannot be cancelled because production has already started.',
      );
    }

    // Step 3: Validate item-level status (if any item reached cutting+)
    final items = (data['items'] as List<dynamic>?) ?? [];
    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      final itemStatus = ItemStatus.fromString(itemMap['status']);
      if (!itemStatus.isCancellable) {
        throw Exception(
          'Order cannot be cancelled because production has already started.',
        );
      }
    }

    // Step 4: Calculate refund amount
    final payment = data['payment'] as Map<String, dynamic>?;
    final paidAmount = (payment?['amount'] as num?)?.toDouble() ?? 0.0;

    // Step 5: Update order to CANCELLED with audit trail
    await docRef.update({
      'status': OrderStatus.cancelled.toFirestore(),
      'cancelled_at': FieldValue.serverTimestamp(),
      'cancelled_by': _userId,
      'refund_status': paidAmount > 0 ? 'pending' : 'none',
      'refund_amount': paidAmount,
    });

    // Step 6: Update user's order reference subcollection
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('orders')
        .doc(orderId)
        .update({'status': OrderStatus.cancelled.toFirestore()});

    // Step 7: Create audit log entry
    await _firestore.collection('order_events').add({
      'event_type': 'ORDER_CANCELLED',
      'order_id': orderId,
      'user_id': _userId,
      'timestamp': FieldValue.serverTimestamp(),
      'previous_status': currentStatus.toFirestore(),
      'refund_amount': paidAmount,
    });

    debugPrint('[OrderService] Order cancelled: $orderId');
  }
}
