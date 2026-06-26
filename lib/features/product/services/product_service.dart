import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/category.dart';
import '../models/product.dart';
import '../models/review.dart';

/// Service class for product catalog Firestore operations.
/// Provides clean fetch methods for the Home Screen and catalog pages.
class ProductService {
  final FirebaseFirestore _firestore;

  ProductService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // ─── Products ──────────────────────────────────────────────────────────

  /// Stream all active products, ordered by sort priority.
  /// Temporarily removes isActive filter for debugging.
  Stream<List<Product>> activeProductsStream() {
    return _firestore.collection('products').snapshots().map((snap) {
      debugPrint(
        '[ProductService] Fetched ${snap.docs.length} docs from "products" collection',
      );
      if (snap.docs.isEmpty) {
        debugPrint(
          '[ProductService] WARNING: Collection is EMPTY! Check: '
          '1) Collection name is "products" (lowercase) in Firebase Console '
          '2) User is authenticated '
          '3) Firestore rules allow read',
        );
      }
      for (final doc in snap.docs) {
        final data = doc.data();
        debugPrint(
          '[ProductService] Doc "${doc.id}" imageUrl type=${data['imageUrl']?.runtimeType}, value=${data['imageUrl']}',
        );
      }
      // NOTE: isActive filter temporarily removed for debugging
      // Products will show regardless of isActive field
      final products = snap.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
      products.sort((a, b) => a.order.compareTo(b.order));
      debugPrint(
        '[ProductService] Returning ${products.length} products (no isActive filter)',
      );
      return products;
    });
  }

  /// Stream "Top Choice" products for the Home Screen.
  Stream<List<Product>> topChoicesStream() {
    return _firestore.collection('products').snapshots().map((snap) {
      final products = snap.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
      products.sort((a, b) => a.order.compareTo(b.order));
      return products;
    });
  }

  /// Stream active products filtered by category name.
  Stream<List<Product>> productsByCategoryStream(String category) {
    if (category == 'All') return activeProductsStream();

    return _firestore.collection('products').snapshots().map((snap) {
      debugPrint('[ProductService] Filtering by category: "$category"');
      final products = snap.docs
          .map((doc) => Product.fromFirestore(doc))
          .where((p) => p.category.toLowerCase() == category.toLowerCase())
          .toList();
      products.sort((a, b) => a.order.compareTo(b.order));
      debugPrint(
        '[ProductService] ${products.length} products in category "$category"',
      );
      return products;
    });
  }

  /// Fetch a single product by ID.
  Future<Product?> getProduct(String productId) async {
    final doc = await _firestore.collection('products').doc(productId).get();
    if (!doc.exists) return null;
    return Product.fromFirestore(doc);
  }

  // ─── Categories ────────────────────────────────────────────────────────

  /// Stream all active categories, ordered by display priority.
  Stream<List<Category>> categoriesStream() {
    return _firestore.collection('categories').snapshots().map((snap) {
      final categories = snap.docs
          .map((doc) => Category.fromFirestore(doc))
          .toList();
      categories.sort((a, b) => a.order.compareTo(b.order));
      return categories;
    });
  }

  // ─── Reviews ───────────────────────────────────────────────────────────

  /// Stream reviews for a specific product, ordered by newest first.
  Stream<List<Review>> reviewsForProductStream(String productId) {
    return _firestore.collection('reviews').snapshots().map((snap) {
      final reviews = snap.docs
          .map((doc) => Review.fromFirestore(doc))
          .where((r) => r.productId == productId)
          .toList();
      // Sort by createdAt descending (newest first)
      reviews.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      return reviews;
    });
  }

  /// Get average rating and count for a product.
  Future<({double average, int count})> getProductRating(
    String productId,
  ) async {
    final snap = await _firestore.collection('reviews').get();
    final reviews = snap.docs
        .map((doc) => Review.fromFirestore(doc))
        .where((r) => r.productId == productId)
        .toList();
    if (reviews.isEmpty) return (average: 0.0, count: 0);
    final total = reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return (average: total / reviews.length, count: reviews.length);
  }
}
