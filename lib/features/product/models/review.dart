import 'package:cloud_firestore/cloud_firestore.dart';

/// Review model for product reviews.
/// Maps to Firestore `reviews` collection (managed via Rowy).
///
/// Firestore schema:
/// ```
/// reviews/{reviewId}
///   ├── productId: String        — ID produk yang dinilai
///   ├── customerId: String       — UID pelanggan yang tulis review
///   ├── orderItemId: String      — ID resit/tempahan baju
///   ├── rating: Number           — Bintang 1-5
///   ├── comment: String (Long)   — Pendapat pelanggan
///   ├── createdAt: Tracked Field — Auto timestamp by Rowy
///   └── media: File[]            — Gambar/video OOTD (Rowy File type)
/// ```
class Review {
  final String id;
  final String productId;
  final String customerId;
  final String? orderItemId;
  final int rating;
  final String comment;
  final DateTime? createdAt;
  final List<String> mediaUrls;

  const Review({
    required this.id,
    required this.productId,
    required this.customerId,
    required this.rating,
    required this.comment,
    this.orderItemId,
    this.createdAt,
    this.mediaUrls = const [],
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Review(
      id: doc.id,
      productId: _parseString(data['productId'] ?? data['product_id']),
      customerId: _parseString(data['customerId'] ?? data['customer_id']),
      orderItemId: _parseStringOrNull(
        data['orderItemId'] ?? data['order_item_id'],
      ),
      rating: (data['rating'] as num?)?.toInt() ?? 5,
      comment: _parseString(data['comment'] ?? data['review'] ?? data['text']),
      createdAt: _parseTimestamp(
        data['createdAt'] ?? data['created_at'] ?? data['_createdAt'],
      ),
      mediaUrls: _parseFileUrls(
        data['media'] ?? data['images'] ?? data['mediaUrl'],
      ),
    );
  }

  /// Parse Rowy File type: [{downloadURL: "...", name: "...", type: "..."}]
  static List<String> _parseFileUrls(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((item) {
            if (item is Map) {
              return (item['downloadURL'] ?? item['url'] ?? item['src'] ?? '')
                  .toString();
            }
            if (item is String) return item;
            return '';
          })
          .where((url) => url.isNotEmpty)
          .toList();
    }
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }

  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  static String? _parseStringOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    return value.toString();
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
