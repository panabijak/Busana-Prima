import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/shipping_address.dart';

/// Firestore service for shipping address CRUD operations.
/// Collection: users/{uid}/addresses/{addressId}
class AddressService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AddressService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _addressesRef {
    return _firestore.collection('users').doc(_userId).collection('addresses');
  }

  /// Stream all addresses for the current user, default first.
  Stream<List<ShippingAddress>> addressesStream() {
    if (_userId == null) return Stream.value([]);
    return _addressesRef.snapshots().map((snap) {
      debugPrint('[AddressService] Fetched ${snap.docs.length} addresses');
      final addresses = snap.docs
          .map((doc) => ShippingAddress.fromFirestore(doc))
          .toList();
      // Sort: default first, then by creation date
      addresses.sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return aTime.compareTo(bTime);
      });
      return addresses;
    });
  }

  /// Get the user's default address (or first available).
  Future<ShippingAddress?> getDefaultAddress() async {
    if (_userId == null) return null;
    final snap = await _addressesRef
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      return ShippingAddress.fromFirestore(snap.docs.first);
    }
    // Fallback: return first address
    final fallback = await _addressesRef.limit(1).get();
    if (fallback.docs.isNotEmpty) {
      return ShippingAddress.fromFirestore(fallback.docs.first);
    }
    return null;
  }

  /// Add a new address. If it's the first address, auto-set as default.
  Future<String> addAddress({
    required String label,
    required String recipientName,
    required String phone,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String postcode,
    bool isDefault = false,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    // If marking as default, unset other defaults first
    if (isDefault) {
      await _clearDefaultFlag();
    }

    // Check if this is the first address (auto-default)
    final count = await _addressesRef.count().get();
    final isFirst = (count.count ?? 0) == 0;

    final doc = await _addressesRef.add({
      'customerId': _userId,
      'label': label,
      'recipientName': recipientName,
      'phone': phone,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'postcode': postcode,
      'isDefault': isDefault || isFirst,
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[AddressService] Added address: ${doc.id} (label: $label)');
    return doc.id;
  }

  /// Update an existing address.
  Future<void> updateAddress({
    required String addressId,
    required String label,
    required String recipientName,
    required String phone,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String postcode,
  }) async {
    if (_userId == null) return;
    await _addressesRef.doc(addressId).update({
      'label': label,
      'recipientName': recipientName,
      'phone': phone,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'postcode': postcode,
    });
    debugPrint('[AddressService] Updated address: $addressId');
  }

  /// Delete an address. Prevents deletion of the last remaining address.
  Future<bool> deleteAddress(String addressId) async {
    if (_userId == null) return false;

    final count = await _addressesRef.count().get();
    if ((count.count ?? 0) <= 1) {
      debugPrint('[AddressService] Cannot delete last address');
      return false;
    }

    final doc = await _addressesRef.doc(addressId).get();
    final wasDefault = doc.data()?['isDefault'] == true;

    await _addressesRef.doc(addressId).delete();
    debugPrint('[AddressService] Deleted address: $addressId');

    // If deleted address was default, assign default to next available
    if (wasDefault) {
      final remaining = await _addressesRef.limit(1).get();
      if (remaining.docs.isNotEmpty) {
        await remaining.docs.first.reference.update({'isDefault': true});
      }
    }

    return true;
  }

  /// Set an address as default (unsets all others).
  Future<void> setDefaultAddress(String addressId) async {
    if (_userId == null) return;
    await _clearDefaultFlag();
    await _addressesRef.doc(addressId).update({'isDefault': true});
    debugPrint('[AddressService] Set default address: $addressId');
  }

  /// Clear the default flag from all addresses.
  Future<void> _clearDefaultFlag() async {
    final defaults = await _addressesRef
        .where('isDefault', isEqualTo: true)
        .get();
    final batch = _firestore.batch();
    for (final doc in defaults.docs) {
      batch.update(doc.reference, {'isDefault': false});
    }
    await batch.commit();
  }
}
