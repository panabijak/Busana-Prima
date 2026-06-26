import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order_model.dart';
import '../services/order_service.dart';

/// Provider for the OrderService singleton.
final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService();
});

/// Stream provider for the current user's orders (real-time from Firestore).
///
/// Uses includeMetadataChanges to receive cache hits even when
/// the server query fails (e.g. missing composite index).
final userOrdersProvider = StreamProvider<List<BusanaOrder>>((ref) {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;

  if (user == null) {
    debugPrint('[OrderProvider] User not authenticated, returning empty');
    return Stream.value(<BusanaOrder>[]);
  }

  debugPrint('[OrderProvider] Fetching orders for uid: ${user.uid}');

  // Use includeMetadataChanges so we get cache data even if server rejects
  return FirebaseFirestore.instance
      .collection('orders')
      .where('customerId', isEqualTo: user.uid)
      .orderBy('orderDate', descending: true)
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) {
        // Accept snapshots that have docs (from cache or server)
        // Skip empty error-recovery snapshots
        if (snapshot.docs.isEmpty && snapshot.metadata.isFromCache) {
          return true; // still emit — user might actually have 0 orders
        }
        return true;
      })
      .map((snapshot) {
        debugPrint(
          '[OrderProvider] Got ${snapshot.docs.length} order(s) '
          '[fromCache: ${snapshot.metadata.isFromCache}]',
        );
        final orders = <BusanaOrder>[];
        for (final doc in snapshot.docs) {
          try {
            orders.add(BusanaOrder.fromFirestore(doc));
          } catch (e) {
            debugPrint('[OrderProvider] Skipping doc ${doc.id}: $e');
          }
        }
        return orders;
      });
});

/// Safe provider that never throws — returns empty list on error.
/// Keeps previous data if available when stream errors.
final userOrdersSafeProvider = Provider<AsyncValue<List<BusanaOrder>>>((ref) {
  final ordersAsync = ref.watch(userOrdersProvider);
  return ordersAsync.when(
    data: (orders) => AsyncValue.data(orders),
    loading: () => const AsyncValue.loading(),
    error: (error, stack) {
      // If we have previous data, keep showing it
      final previousData = ref.read(userOrdersProvider).valueOrNull;
      if (previousData != null && previousData.isNotEmpty) {
        debugPrint(
          '[OrderProvider] Error but keeping ${previousData.length} cached orders',
        );
        return AsyncValue.data(previousData);
      }
      debugPrint('[OrderProvider] Error (no cached data): $error');
      return const AsyncValue.data(<BusanaOrder>[]);
    },
  );
});

/// Provider for fetching a single order by ID.
final orderByIdProvider = FutureProvider.family<BusanaOrder?, String>((
  ref,
  orderId,
) {
  final service = ref.watch(orderServiceProvider);
  return service.getOrder(orderId);
});

/// Real-time stream provider for a single order (live updates from tailor).
/// Use this for Order Status / Outfit Details screens so UI updates
/// instantly when tailor changes item status via Rowy/admin panel.
final orderStreamProvider = StreamProvider.family<BusanaOrder?, String>((
  ref,
  orderId,
) {
  if (orderId.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;
        return BusanaOrder.fromFirestore(doc);
      });
});
