import 'package:cloud_firestore/cloud_firestore.dart';

/// Shipping address model stored in Firestore: users/{uid}/addresses/{addressId}
///
/// Supports multiple addresses per user with a single default.
class ShippingAddress {
  final String id;
  final String customerId;
  final String label; // e.g. "Home", "Office", "Campus"
  final String recipientName;
  final String phone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String postcode;
  final bool isDefault;
  final DateTime? createdAt;

  const ShippingAddress({
    required this.id,
    required this.customerId,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    required this.postcode,
    this.isDefault = false,
    this.createdAt,
  });

  /// Full formatted address for display.
  String get fullAddress {
    final parts = <String>[
      addressLine1,
      if (addressLine2 != null && addressLine2!.isNotEmpty) addressLine2!,
      '$postcode, $city',
      state,
    ];
    return parts.join(', ');
  }

  /// Display string for checkout card.
  String get displayForCheckout {
    return '$recipientName\n$fullAddress\n$phone';
  }

  /// Snapshot map for embedding in order records.
  /// This ensures historical orders keep address data even if user edits later.
  Map<String, dynamic> toOrderSnapshot() => {
    'recipientName': recipientName,
    'phone': phone,
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'city': city,
    'state': state,
    'postcode': postcode,
    'label': label,
  };

  factory ShippingAddress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ShippingAddress(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      label: data['label'] ?? 'Home',
      recipientName: data['recipientName'] ?? '',
      phone: data['phone'] ?? '',
      addressLine1: data['addressLine1'] ?? '',
      addressLine2: data['addressLine2'],
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      postcode: data['postcode'] ?? '',
      isDefault: data['isDefault'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'customerId': customerId,
    'label': label,
    'recipientName': recipientName,
    'phone': phone,
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'city': city,
    'state': state,
    'postcode': postcode,
    'isDefault': isDefault,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  ShippingAddress copyWith({
    String? label,
    String? recipientName,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postcode,
    bool? isDefault,
  }) {
    return ShippingAddress(
      id: id,
      customerId: customerId,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      postcode: postcode ?? this.postcode,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
    );
  }
}
