import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing user favourites.
/// Stores favourites as subcollection: users/{userId}/favourites/{productId}
class FavouritesService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FavouritesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _favouritesRef {
    return _firestore.collection('users').doc(_userId).collection('favourites');
  }

  /// Stream all favourite product IDs for the current user.
  Stream<List<String>> favouriteIdsStream() {
    if (_userId == null) return Stream.value([]);
    return _favouritesRef.snapshots().map(
      (snap) => snap.docs.map((doc) => doc.id).toList(),
    );
  }

  /// Check if a product is favourited.
  Stream<bool> isFavouritedStream(String productId) {
    if (_userId == null) return Stream.value(false);
    return _favouritesRef.doc(productId).snapshots().map((doc) => doc.exists);
  }

  /// Add a product to favourites.
  Future<void> addFavourite(String productId) async {
    if (_userId == null) return;
    await _favouritesRef.doc(productId).set({
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a product from favourites.
  Future<void> removeFavourite(String productId) async {
    if (_userId == null) return;
    await _favouritesRef.doc(productId).delete();
  }

  /// Toggle favourite status.
  Future<bool> toggleFavourite(String productId) async {
    if (_userId == null) return false;
    final doc = await _favouritesRef.doc(productId).get();
    if (doc.exists) {
      await removeFavourite(productId);
      return false;
    } else {
      await addFavourite(productId);
      return true;
    }
  }
}
