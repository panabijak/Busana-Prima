import 'package:cloud_firestore/cloud_firestore.dart';

/// Category model for the Busana Prima product catalog.
/// Maps to Firestore `categories` collection.
///
/// Firestore schema:
/// ```
/// categories/{categoryId}
///   ├── name: String        — "Kurung" | "Kebaya" | "Dress" | "Blouse" | "Custom"
///   ├── imageUrl: String    — Category cover image
///   ├── description: String — Short description
///   ├── order: num          — Display order (lower = first)
///   └── isActive: bool      — Toggle visibility
/// ```
class Category {
  final String id;
  final String name;
  final String? imageUrl;
  final String? description;
  final int order;
  final bool isActive;

  const Category({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
    this.order = 0,
    this.isActive = true,
  });

  factory Category.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Category(
      id: doc.id,
      name: data['name'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      description: data['description'] as String?,
      order: (data['order'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}
