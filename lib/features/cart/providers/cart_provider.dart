import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_item.dart';
import '../services/cart_service.dart';

/// Singleton CartService provider.
final cartServiceProvider = Provider((ref) => CartService());

/// Stream all cart items for the current user.
final cartItemsStreamProvider = StreamProvider<List<CartItem>>((ref) {
  final service = ref.watch(cartServiceProvider);
  return service.cartItemsStream();
});

/// Cart item count (derived from the stream).
final cartItemCountProvider = Provider<int>((ref) {
  final cartAsync = ref.watch(cartItemsStreamProvider);
  return cartAsync.when(
    data: (items) => items.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Cart total price (sum of all line totals).
final cartTotalProvider = Provider<double>((ref) {
  final cartAsync = ref.watch(cartItemsStreamProvider);
  return cartAsync.when(
    data: (items) => items.fold(0.0, (sum, item) => sum + item.lineTotal),
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Set of selected cart item IDs (for selective checkout).
final selectedCartItemIdsProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

/// Total price of only selected items.
final selectedCartTotalProvider = Provider<double>((ref) {
  final cartAsync = ref.watch(cartItemsStreamProvider);
  final selectedIds = ref.watch(selectedCartItemIdsProvider);
  return cartAsync.when(
    data: (items) => items
        .where((item) => selectedIds.contains(item.id))
        .fold(0.0, (sum, item) => sum + item.lineTotal),
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});
