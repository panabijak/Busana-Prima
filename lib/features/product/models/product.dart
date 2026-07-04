import 'package:cloud_firestore/cloud_firestore.dart';

/// Product data model for the Busana Prima catalog.
/// Maps directly to Firestore `products` collection documents.
///
/// This is a bespoke tailoring system, NOT standard e-commerce.
/// The `price` field represents the BASE tailoring fee (starting price).
/// Final price is calculated per order item based on:
/// - Customer body size / measurements
/// - Fabric type (customer-provided or tailor-provided)
/// - Design complexity / customization requests
/// - Additional tailoring adjustments
///
/// Firestore schema:
/// ```
/// products/{productId}
///   ├── name: String              — "Kurung Pahang Pastel"
///   ├── category: String          — "Kurung" | "Kebaya" | "Dress" | "Blouse" | "Custom"
///   ├── price: num                — Base tailoring fee in MYR (starting price, e.g. 199.00)
///   ├── imageUrl: String/File     — Full-size product image (Rowy Image/File type)
///   ├── thumbnailUrl: String/File — Smaller image for grid cards (optional)
///   ├── description: String       — Product details / fabric info
///   ├── isActive: bool            — Toggle visibility without deleting
///   ├── isTopChoice: bool         — Featured on home screen "Top Choice" section
///   ├── fabricType: String        — e.g. "Lace", "Silk", "Cotton"
///   ├── availableColors: [String] — e.g. ["Pastel Pink", "Navy", "White"]
///   ├── order: num                — Sort priority (lower = shown first)
///   └── createdAt: Timestamp      — Server timestamp on creation
/// ```
class Product {
  final String id;
  final String name;
  final String category;

  /// Base tailoring fee — the starting price for sewing this design.
  /// Final price is determined during checkout after measurements & fabric selection.
  final double basePrice;
  final String imageUrl;
  final String? thumbnailUrl;

  /// Transparent (cut-out) PNG of the garment used by the Virtual Try-On
  /// feature. Only products that support Try-On populate this field; it is
  /// `null` for every other product.
  final String? transparentUrl;
  final String? description;
  final bool isActive;
  final bool isTopChoice;
  final String? fabricType;
  final List<String> availableColors;
  final int order;
  final DateTime? createdAt;

  const Product({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.basePrice,
    this.category = 'All',
    this.thumbnailUrl,
    this.transparentUrl,
    this.description,
    this.isActive = true,
    this.isTopChoice = false,
    this.fabricType,
    this.availableColors = const [],
    this.order = 0,
    this.createdAt,
  });

  /// Construct from a Firestore document snapshot.
  /// Handles both camelCase (Flutter convention) and snake_case (Rowy convention) field names.
  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Product(
      id: doc.id,
      name: _parseString(data['name'] ?? data['title']),
      imageUrl: _parseString(
        data['imageUrl'] ?? data['image_url'] ?? data['image'],
      ),
      thumbnailUrl: _parseStringOrNull(
        data['thumbnailUrl'] ?? data['thumbnail_url'] ?? data['thumbnail'],
      ),
      transparentUrl: _parseStringOrNull(
        data['transparentUrl'] ??
            data['transparent_url'] ??
            data['transparent'],
      ),
      basePrice:
          (data['price'] ?? data['basePrice'] ?? data['base_price'] as num?)
              ?.toDouble() ??
          0.0,
      category: _parseString(data['category'] ?? data['type'], fallback: 'All'),
      description: _parseStringOrNull(data['description'] ?? data['desc']),
      isActive: _parseBool(
        data['isActive'] ?? data['is_active'] ?? data['active'],
        defaultValue: true,
      ),
      isTopChoice: _parseBool(
        data['isTopChoice'] ?? data['is_top_choice'] ?? data['topChoice'],
        defaultValue: false,
      ),
      fabricType: _parseStringOrNull(
        data['fabricType'] ?? data['fabric_type'] ?? data['fabric'],
      ),
      availableColors: _parseStringList(
        data['availableColors'] ?? data['available_colors'] ?? data['colors'],
      ),
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: _parseTimestamp(
        data['createdAt'] ?? data['created_at'] ?? data['_createdAt'],
      ),
    );
  }

  /// Safely parse a String from dynamic value (handles List, null, Rowy file upload objects, etc.)
  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value.isEmpty ? fallback : value;
    if (value is List) {
      if (value.isEmpty) return fallback;
      final first = value.first;
      // Rowy file upload stores as [{downloadURL: "...", name: "..."}]
      if (first is Map) {
        return (first['downloadURL'] ??
                first['url'] ??
                first['src'] ??
                fallback)
            .toString();
      }
      return first.toString();
    }
    if (value is Map) {
      return (value['downloadURL'] ?? value['url'] ?? value['src'] ?? fallback)
          .toString();
    }
    return value.toString();
  }

  /// Safely parse a nullable String from dynamic value.
  static String? _parseStringOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is List) {
      if (value.isEmpty) return null;
      final first = value.first;
      if (first is Map) {
        final url = first['downloadURL'] ?? first['url'] ?? first['src'];
        return url?.toString();
      }
      return first.toString();
    }
    if (value is Map) {
      final url = value['downloadURL'] ?? value['url'] ?? value['src'];
      return url?.toString();
    }
    return value.toString();
  }

  /// Safely parse a List<String> from dynamic value.
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) return [value];
    return const [];
  }

  /// Parse various boolean representations (bool, String "true"/"false", int 1/0).
  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return defaultValue;
  }

  /// Parse Timestamp from various formats (Timestamp, String, Map).
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Serialize to a Firestore-compatible map (for admin writes).
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'price': basePrice,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'transparentUrl': transparentUrl,
      'description': description,
      'isActive': isActive,
      'isTopChoice': isTopChoice,
      'fabricType': fabricType,
      'availableColors': availableColors,
      'order': order,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// The display image — prefers thumbnail for grid cards, falls back to full image.
  String get displayImage => thumbnailUrl ?? imageUrl;

  /// Whether this product supports the Virtual Try-On experience.
  /// True only when a non-empty transparent garment PNG is available.
  bool get supportsTryOn =>
      transparentUrl != null && transparentUrl!.trim().isNotEmpty;

  /// Formatted base price with "From" prefix for catalog display.
  /// Final price is only determined during checkout.
  String get formattedPrice {
    final priceStr = basePrice == basePrice.roundToDouble()
        ? 'RM${basePrice.toStringAsFixed(0)}'
        : 'RM${basePrice.toStringAsFixed(2)}';
    return 'From $priceStr';
  }
}
