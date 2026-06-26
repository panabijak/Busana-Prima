import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';

/// Firestore service for shopping cart operations.
/// Stores cart items at: users/{userId}/cart/{docId}
class CartService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CartService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _cartRef {
    return _firestore.collection('users').doc(_userId).collection('cart');
  }

  /// Stream all cart items for the current user, ordered by addedAt.
  Stream<List<CartItem>> cartItemsStream() {
    if (_userId == null) return Stream.value([]);
    return _cartRef.orderBy('addedAt', descending: false).snapshots().map((
      snap,
    ) {
      debugPrint('[CartService] Fetched ${snap.docs.length} cart items');
      return snap.docs.map((doc) => CartItem.fromFirestore(doc)).toList();
    });
  }

  /// Add an item to the cart.
  /// If an identical item exists (same productId + measurementProfileId + fabricType),
  /// increments quantity instead of creating a duplicate.
  Future<String> addToCart({
    required String productId,
    required String productName,
    required String productImageUrl,
    required String fabricType,
    required String selectedColor,
    String? measurementProfileId,
    String? sizeLabel,
    required double unitPrice,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    // Check for existing duplicate (same product + fabric + measurement)
    final existingSnap = await _cartRef
        .where('productId', isEqualTo: productId)
        .where('fabricType', isEqualTo: fabricType)
        .where('measurementProfileId', isEqualTo: measurementProfileId)
        .get();

    if (existingSnap.docs.isNotEmpty) {
      // Merge: increment quantity on the existing item
      final existingDoc = existingSnap.docs.first;
      final currentQty = (existingDoc.data()['quantity'] as num?)?.toInt() ?? 1;
      await _cartRef.doc(existingDoc.id).update({'quantity': currentQty + 1});
      debugPrint(
        '[CartService] Merged duplicate cart item: ${existingDoc.id} (qty: ${currentQty + 1})',
      );
      return existingDoc.id;
    }

    final doc = await _cartRef.add({
      'productId': productId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'fabricType': fabricType,
      'selectedColor': selectedColor,
      'measurementProfileId': measurementProfileId,
      'sizeLabel': sizeLabel,
      'quantity': 1,
      'unitPrice': unitPrice,
      'addedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[CartService] Added cart item: ${doc.id}');
    return doc.id;
  }

  /// Update the quantity of a cart item.
  Future<void> updateQuantity(String cartItemId, int quantity) async {
    if (_userId == null) return;
    if (quantity < 1) {
      await removeFromCart(cartItemId);
      return;
    }
    await _cartRef.doc(cartItemId).update({'quantity': quantity});
  }

  /// Remove an item from the cart.
  Future<void> removeFromCart(String cartItemId) async {
    if (_userId == null) return;
    await _cartRef.doc(cartItemId).delete();
    debugPrint('[CartService] Removed cart item: $cartItemId');
  }

  /// Remove only specific items from the cart (partial checkout).
  /// Only deletes the items whose IDs are in [cartItemIds].
  Future<void> removeItems(List<String> cartItemIds) async {
    if (_userId == null) return;
    if (cartItemIds.isEmpty) return;

    final batch = _firestore.batch();
    for (final id in cartItemIds) {
      batch.delete(_cartRef.doc(id));
    }
    await batch.commit();
    debugPrint(
      '[CartService] Removed ${cartItemIds.length} checked-out item(s)',
    );
  }

  /// Clear all items from the cart (after successful order).
  Future<void> clearCart() async {
    if (_userId == null) return;
    final snap = await _cartRef.get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    debugPrint('[CartService] Cart cleared');
  }

  /// Get the current cart item count.
  Future<int> getCartCount() async {
    if (_userId == null) return 0;
    final snap = await _cartRef.count().get();
    return snap.count ?? 0;
  }
}
