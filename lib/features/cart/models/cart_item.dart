import 'package:cloud_firestore/cloud_firestore.dart';

/// Cart item model stored in Firestore: users/{uid}/cart/{docId}
///
/// Each cart item represents one outfit configuration:
/// - Product reference (productId)
/// - Fabric choice (own fabric vs tailor fabric)
/// - Selected color
/// - Body measurement profile reference
/// - Quantity
/// - Calculated price at the time of adding
class CartItem {
  final String id;
  final String productId;
  final String productName;
  final String productImageUrl;
  final String fabricType; // 'own' or 'tailor'
  final String selectedColor;
  final String? measurementProfileId;
  final String? sizeLabel; // e.g. "M", "L", or custom
  final int quantity;
  final double unitPrice; // Calculated price per item at add time
  final DateTime? addedAt;

  const CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImageUrl,
    required this.fabricType,
    required this.selectedColor,
    this.measurementProfileId,
    this.sizeLabel,
    this.quantity = 1,
    required this.unitPrice,
    this.addedAt,
  });

  /// Construct from Firestore document.
  factory CartItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CartItem(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productImageUrl: data['productImageUrl'] ?? '',
      fabricType: data['fabricType'] ?? 'own',
      selectedColor: data['selectedColor'] ?? '',
      measurementProfileId: data['measurementProfileId'],
      sizeLabel: data['sizeLabel'],
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0.0,
      addedAt: _parseTimestamp(data['addedAt']),
    );
  }

  /// Serialize to Firestore map.
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'fabricType': fabricType,
      'selectedColor': selectedColor,
      'measurementProfileId': measurementProfileId,
      'sizeLabel': sizeLabel,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'addedAt': addedAt != null
          ? Timestamp.fromDate(addedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// Display string for fabric type (for UI subtitle).
  String get fabricLabel =>
      fabricType == 'tailor' ? "Tailor's Fabric" : 'Own Fabric';

  /// Total price for this line item.
  double get lineTotal => unitPrice * quantity;

  /// Create a copy with updated fields.
  CartItem copyWith({int? quantity, double? unitPrice, String? sizeLabel}) {
    return CartItem(
      id: id,
      productId: productId,
      productName: productName,
      productImageUrl: productImageUrl,
      fabricType: fabricType,
      selectedColor: selectedColor,
      measurementProfileId: measurementProfileId,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      addedAt: addedAt,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
