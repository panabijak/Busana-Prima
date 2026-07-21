import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

DateTime? parseEstimatedCompletionDate(Map<String, dynamic> map) {
  final raw = map['estimatedCompletionDate'] ??
      map['estimated_completion_date'] ??
      map['estimatedCompletionAt'] ??
      map['estimated_completion_at'];
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

/// Order status enum matching Firestore string values.
enum OrderStatus {
  pending,
  confirmed,
  inProgress,
  ready,
  outForDelivery,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending Acceptance';
      case OrderStatus.confirmed:
        return 'Accepted';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.ready:
        return 'All Outfits Ready';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.completed:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  static OrderStatus fromString(String? value) {
    if (value == null || value.isEmpty) return OrderStatus.pending;
    final normalized = value.toLowerCase().replaceAll(' ', '_');

    switch (normalized) {
      case 'pending_acceptance':
      case 'pending':
      case 'new':
      case 'new_order':
        return OrderStatus.pending;
      case 'accepted':
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'in_progress':
        return OrderStatus.inProgress;
      case 'all_outfits_ready':
        return OrderStatus.ready;
      case 'out_for_delivery':
        return OrderStatus.outForDelivery;
      case 'ready':
        return OrderStatus.ready;
      case 'delivered':
      case 'completed':
        return OrderStatus.completed;
      case 'rejected':
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  String toFirestore() {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.inProgress:
        return 'in_progress';
      case OrderStatus.ready:
        return 'all_outfits_ready';
      case OrderStatus.outForDelivery:
        return 'out_for_delivery';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Whether this order-level status allows cancellation.
  /// Only allowed before production (CUTTING) begins.
  bool get isCancellable {
    return this == OrderStatus.pending || this == OrderStatus.confirmed;
  }
}

/// Delivery method for the order.
enum DeliveryMethod {
  shipToAddress,
  selfCollection;

  String get label {
    switch (this) {
      case DeliveryMethod.shipToAddress:
        return 'Ship orders to address';
      case DeliveryMethod.selfCollection:
        return 'Self-collection / Pickup';
    }
  }

  static DeliveryMethod fromString(String? value) {
    if (value == 'self_collection') return DeliveryMethod.selfCollection;
    return DeliveryMethod.shipToAddress;
  }

  String toFirestore() {
    switch (this) {
      case DeliveryMethod.shipToAddress:
        return 'ship_to_address';
      case DeliveryMethod.selfCollection:
        return 'self_collection';
    }
  }
}

/// Fabric delivery method (how customer sends fabric to tailor).
enum FabricDeliveryMethod {
  dropOffAtBoutique,
  selfShipping;

  String get label {
    switch (this) {
      case FabricDeliveryMethod.dropOffAtBoutique:
        return 'Drop off at boutique';
      case FabricDeliveryMethod.selfShipping:
        return 'Self-shipping (You drop off to courier)';
    }
  }

  static FabricDeliveryMethod fromString(String? value) {
    if (value == 'self_shipping') return FabricDeliveryMethod.selfShipping;
    return FabricDeliveryMethod.dropOffAtBoutique;
  }

  String toFirestore() {
    switch (this) {
      case FabricDeliveryMethod.dropOffAtBoutique:
        return 'drop_off_at_boutique';
      case FabricDeliveryMethod.selfShipping:
        return 'self_shipping';
    }
  }
}

/// Payment terms selection.
enum PaymentTerms {
  deposit50,
  fullPayment;

  String get label {
    switch (this) {
      case PaymentTerms.deposit50:
        return 'Deposit (50%)';
      case PaymentTerms.fullPayment:
        return 'Full Payment';
    }
  }

  static PaymentTerms fromString(String? value) {
    if (value == 'full_payment') return PaymentTerms.fullPayment;
    return PaymentTerms.deposit50;
  }

  String toFirestore() {
    switch (this) {
      case PaymentTerms.deposit50:
        return 'deposit_50';
      case PaymentTerms.fullPayment:
        return 'full_payment';
    }
  }
}

/// Payment method selection.
enum PaymentMethod {
  visa,
  mastercard,
  duitNowQR;

  String get label {
    switch (this) {
      case PaymentMethod.visa:
        return 'Visa';
      case PaymentMethod.mastercard:
        return 'Mastercard';
      case PaymentMethod.duitNowQR:
        return 'DuitNow QR';
    }
  }

  static PaymentMethod fromString(String? value) {
    switch (value) {
      case 'mastercard':
        return PaymentMethod.mastercard;
      case 'duitnow_qr':
        return PaymentMethod.duitNowQR;
      default:
        return PaymentMethod.visa;
    }
  }

  String toFirestore() {
    switch (this) {
      case PaymentMethod.visa:
        return 'visa';
      case PaymentMethod.mastercard:
        return 'mastercard';
      case PaymentMethod.duitNowQR:
        return 'duitnow_qr';
    }
  }
}

/// Order-level delivery tracking from tailor app.
enum DeliveryStatus {
  none,
  awaitingReady,
  outForDelivery,
  delivered;

  String get label {
    switch (this) {
      case DeliveryStatus.none:
        return 'Not started';
      case DeliveryStatus.awaitingReady:
        return 'Awaiting ready';
      case DeliveryStatus.outForDelivery:
        return 'Out for Delivery';
      case DeliveryStatus.delivered:
        return 'Delivered';
    }
  }

  static DeliveryStatus fromString(String? value) {
    if (value == null || value.isEmpty) return DeliveryStatus.none;
    switch (value.toUpperCase()) {
      case 'AWAITING_READY':
      case 'PENDING':
        return DeliveryStatus.awaitingReady;
      case 'OUT_FOR_DELIVERY':
        return DeliveryStatus.outForDelivery;
      case 'DELIVERED':
        return DeliveryStatus.delivered;
      default:
        return DeliveryStatus.none;
    }
  }
}

/// Per-item tailoring status for tracking individual garment progress.
enum ItemStatus {
  newOrder,
  accepted,
  waitingFabric,
  cutting,
  sewing,
  fitting,
  adjustment,
  qc,
  ready,
  delivered;

  String get label {
    switch (this) {
      case ItemStatus.newOrder:
        return 'New';
      case ItemStatus.accepted:
        return 'Accepted';
      case ItemStatus.waitingFabric:
        return 'Fabric Received';
      case ItemStatus.cutting:
        return 'Cutting';
      case ItemStatus.sewing:
        return 'Sewing';
      case ItemStatus.fitting:
        return 'Fitting';
      case ItemStatus.adjustment:
        return 'Adjustment';
      case ItemStatus.qc:
        return 'Quality Check';
      case ItemStatus.ready:
        return 'Ready';
      case ItemStatus.delivered:
        return 'Delivered';
    }
  }

  static ItemStatus fromString(String? value) {
    if (value == null || value.isEmpty) return ItemStatus.newOrder;
    final normalized = value.toLowerCase().replaceAll(' ', '_');

    switch (normalized) {
      case 'accepted':
        return ItemStatus.newOrder;
      case 'waiting_fabric':
      case 'fabric_received':
      case 'waiting fabric':
        return ItemStatus.waitingFabric;
      case 'cutting':
        return ItemStatus.cutting;
      case 'sewing':
        return ItemStatus.sewing;
      case 'fitting':
        return ItemStatus.fitting;
      case 'adjustment':
        return ItemStatus.adjustment;
      case 'qc':
      case 'quality_check':
        return ItemStatus.qc;
      case 'ready':
        return ItemStatus.ready;
      case 'delivered':
        return ItemStatus.delivered;
      case 'new':
      case 'new_order':
      case 'pending':
      default:
        return ItemStatus.newOrder;
    }
  }

  String toFirestore() {
    switch (this) {
      case ItemStatus.newOrder:
        return 'new';
      case ItemStatus.accepted:
        return 'accepted';
      case ItemStatus.waitingFabric:
        return 'fabric_received';
      case ItemStatus.cutting:
        return 'cutting';
      case ItemStatus.sewing:
        return 'sewing';
      case ItemStatus.fitting:
        return 'fitting';
      case ItemStatus.adjustment:
        return 'adjustment';
      case ItemStatus.qc:
        return 'qc';
      case ItemStatus.ready:
        return 'ready';
      case ItemStatus.delivered:
        return 'delivered';
    }
  }

  /// Whether cancellation is allowed at this stage
  bool get isCancellable {
    return this == ItemStatus.newOrder ||
        this == ItemStatus.accepted ||
        this == ItemStatus.waitingFabric;
  }
}

/// Single order item within an order.
class OrderItem {
  final String productId;
  final String productName;
  final String productImageUrl;
  final String fabricType;
  final String selectedColor;
  final String? measurementProfileId;
  final String? sizeLabel;
  final int quantity;
  final double unitPrice;
  final ItemStatus status;
  final int? progressPercentage;
  final double? storedProgress;
  final DateTime? estimatedCompletionAt;
  final bool fittingRequired;
  final bool alterationRequired;
  final String? skipReason;
  final String? tailorNotes;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.productImageUrl,
    required this.fabricType,
    required this.selectedColor,
    this.measurementProfileId,
    this.sizeLabel,
    required this.quantity,
    required this.unitPrice,
    this.status = ItemStatus.newOrder,
    this.progressPercentage,
    this.storedProgress,
    this.estimatedCompletionAt,
    this.fittingRequired = false,
    this.alterationRequired = false,
    this.skipReason,
    this.tailorNotes,
  });

  double get lineTotal => unitPrice * quantity;

  /// Tailor-assigned ETA — Firestore `items[].estimatedCompletionDate`.
  DateTime? get estimatedCompletionDate => estimatedCompletionAt;

  String get fabricLabel =>
      fabricType == 'tailor' ? "Tailor's Fabric" : 'Own Fabric';

  /// Get the dynamic workflow steps for this item based on flow flags.
  List<ItemStatus> get workflowSteps {
    final steps = <ItemStatus>[
      ItemStatus.newOrder,
      ItemStatus.accepted,
      ItemStatus.waitingFabric,
      ItemStatus.cutting,
      ItemStatus.sewing,
    ];
    if (fittingRequired) steps.add(ItemStatus.fitting);
    if (alterationRequired) steps.add(ItemStatus.adjustment);
    steps.addAll([ItemStatus.qc, ItemStatus.ready, ItemStatus.delivered]);
    return steps;
  }

  /// Progress value (0.0 to 1.0). Prefers tailor-written progress when available.
  double get progress {
    if (storedProgress != null) return storedProgress!.clamp(0.0, 1.0);
    if (progressPercentage != null) {
      return (progressPercentage!.clamp(0, 100)) / 100;
    }
    final steps = workflowSteps;
    final currentIndex = steps.indexOf(status);
    if (currentIndex < 0) return 0.0;
    return (currentIndex + 1) / steps.length;
  }

  /// Progress percentage as int (0–100).
  int get progressPercent =>
      progressPercentage ?? (progress * 100).round();

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'productImageUrl': productImageUrl,
    'fabricType': fabricType,
    'selectedColor': selectedColor,
    'measurementProfileId': measurementProfileId,
    'sizeLabel': sizeLabel,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'status': status.toFirestore(),
    if (estimatedCompletionAt != null)
      'estimatedCompletionDate': Timestamp.fromDate(estimatedCompletionAt!),
    'fittingRequired': fittingRequired,
    'alterationRequired': alterationRequired,
    'skipReason': skipReason,
    'tailorNotes': tailorNotes,
  };

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final rawStage = map['productionStage'] ?? map['status'];
    final parsedStatus = ItemStatus.fromString(rawStage?.toString());
    debugPrint(
      '[OrderItem] Parsing: ${map['productName']} | '
      'raw stage="$rawStage" → parsed=$parsedStatus',
    );
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImageUrl: map['productImageUrl'] ?? '',
      fabricType: map['fabricType'] ?? 'own',
      selectedColor: map['selectedColor'] ?? '',
      measurementProfileId: map['measurementProfileId'],
      sizeLabel: map['sizeLabel'],
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      status: parsedStatus,
      progressPercentage: (map['progressPercentage'] as num?)?.toInt(),
      storedProgress: (map['progress'] as num?)?.toDouble(),
      estimatedCompletionAt: parseEstimatedCompletionDate(map),
      fittingRequired: map['fittingRequired'] ?? false,
      alterationRequired: map['alterationRequired'] ?? false,
      skipReason: map['skipReason'],
      tailorNotes: map['tailorNotes'],
    );
  }
}

/// Payment record stored alongside the order.
class PaymentRecord {
  final String transactionId;
  final String referenceNumber;
  final PaymentMethod paymentMethod;
  final PaymentTerms paymentTerms;
  final double amount; // Amount actually paid (may be 50% deposit)
  final double totalAmount; // Full order total
  final double balanceRemaining; // Remaining to pay (0 if full payment)
  final String status; // 'approved', 'failed', 'pending'
  final DateTime paidAt;

  const PaymentRecord({
    required this.transactionId,
    required this.referenceNumber,
    required this.paymentMethod,
    required this.paymentTerms,
    required this.amount,
    this.totalAmount = 0.0,
    this.balanceRemaining = 0.0,
    required this.status,
    required this.paidAt,
  });

  Map<String, dynamic> toMap() => {
    'transactionId': transactionId,
    'referenceNumber': referenceNumber,
    'paymentMethod': paymentMethod.toFirestore(),
    'paymentTerms': paymentTerms.toFirestore(),
    'amount': amount,
    'totalAmount': totalAmount,
    'balanceRemaining': balanceRemaining,
    'status': status,
    'paidAt': Timestamp.fromDate(paidAt),
  };

  factory PaymentRecord.fromMap(Map<String, dynamic> map) => PaymentRecord(
    transactionId: map['transactionId'] ?? '',
    referenceNumber: map['referenceNumber'] ?? '',
    paymentMethod: PaymentMethod.fromString(map['paymentMethod']),
    paymentTerms: PaymentTerms.fromString(map['paymentTerms']),
    amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
    balanceRemaining: (map['balanceRemaining'] as num?)?.toDouble() ?? 0.0,
    status: map['status'] ?? 'pending',
    paidAt: (map['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

/// Full order model stored in Firestore: orders/{orderId}
class BusanaOrder {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final List<OrderItem> items;
  final PaymentRecord? payment;
  final DeliveryMethod deliveryMethod;
  final FabricDeliveryMethod fabricDeliveryMethod;
  final String shippingAddress;
  final Map<String, dynamic>? addressSnapshot;
  final DateTime? fabricDropoffDate;
  final double tailorFeeTotal;
  final double fabricTotal;
  final double totalAmount;
  final OrderStatus status;
  final DeliveryStatus deliveryStatus;
  final DateTime orderDate;
  final String orderNumber;
  final DateTime? estimatedCompletionAt;

  const BusanaOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    this.payment,
    required this.deliveryMethod,
    required this.fabricDeliveryMethod,
    required this.shippingAddress,
    this.addressSnapshot,
    this.fabricDropoffDate,
    required this.tailorFeeTotal,
    required this.fabricTotal,
    required this.totalAmount,
    required this.status,
    this.deliveryStatus = DeliveryStatus.none,
    required this.orderDate,
    required this.orderNumber,
    this.estimatedCompletionAt,
  });

  /// Order-level ETA set when tailor accepts the order.
  DateTime? get estimatedCompletionDate => estimatedCompletionAt;

  /// Customer-facing order status — deliveryStatus overrides when active.
  String get displayStatusLabel {
    switch (deliveryStatus) {
      case DeliveryStatus.outForDelivery:
        return 'Out for Delivery';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.awaitingReady:
      case DeliveryStatus.none:
        return status.label;
    }
  }

  Map<String, dynamic> toMap() => {
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'items': items.map((i) => i.toMap()).toList(),
    'payment': payment?.toMap(),
    'deliveryMethod': deliveryMethod.toFirestore(),
    'fabricDeliveryMethod': fabricDeliveryMethod.toFirestore(),
    'shippingAddress': shippingAddress,
    'addressSnapshot': addressSnapshot,
    'fabricDropoffDate': fabricDropoffDate != null
        ? Timestamp.fromDate(fabricDropoffDate!)
        : null,
    'tailorFeeTotal': tailorFeeTotal,
    'fabricTotal': fabricTotal,
    'totalAmount': totalAmount,
    'status': status.toFirestore(),
    'orderDate': Timestamp.fromDate(orderDate),
    'orderNumber': orderNumber,
    if (estimatedCompletionAt != null)
      'estimatedCompletionDate': Timestamp.fromDate(estimatedCompletionAt!),
  };

  factory BusanaOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BusanaOrder(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      items:
          (data['items'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      payment: data['payment'] != null
          ? PaymentRecord.fromMap(data['payment'] as Map<String, dynamic>)
          : null,
      deliveryMethod: DeliveryMethod.fromString(data['deliveryMethod']),
      fabricDeliveryMethod: FabricDeliveryMethod.fromString(
        data['fabricDeliveryMethod'],
      ),
      shippingAddress: data['shippingAddress'] ?? '',
      addressSnapshot: data['addressSnapshot'] as Map<String, dynamic>?,
      fabricDropoffDate: (data['fabricDropoffDate'] as Timestamp?)?.toDate(),
      tailorFeeTotal: (data['tailorFeeTotal'] as num?)?.toDouble() ?? 0.0,
      fabricTotal: (data['fabricTotal'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: OrderStatus.fromString(
        data['orderStatus'] ?? data['status'],
      ),
      deliveryStatus: DeliveryStatus.fromString(
        data['deliveryStatus'] as String?,
      ),
      orderDate: (data['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      orderNumber: data['orderNumber'] ?? '',
      estimatedCompletionAt: parseEstimatedCompletionDate(data),
    );
  }
}
