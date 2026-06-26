import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shipping_address.dart';
import '../services/address_service.dart';

/// Singleton AddressService provider.
final addressServiceProvider = Provider((ref) => AddressService());

/// Stream all addresses for the current user.
final addressesStreamProvider = StreamProvider<List<ShippingAddress>>((ref) {
  final service = ref.watch(addressServiceProvider);
  return service.addressesStream();
});

/// Get the default address (derived from stream).
final defaultAddressProvider = Provider<ShippingAddress?>((ref) {
  final addressesAsync = ref.watch(addressesStreamProvider);
  return addressesAsync.when(
    data: (addresses) {
      if (addresses.isEmpty) return null;
      // Find default, or fallback to first
      return addresses.firstWhere(
        (a) => a.isDefault,
        orElse: () => addresses.first,
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Address count provider.
final addressCountProvider = Provider<int>((ref) {
  final addressesAsync = ref.watch(addressesStreamProvider);
  return addressesAsync.when(
    data: (addresses) => addresses.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Selected address for checkout (overrides default when user switches).
final selectedCheckoutAddressProvider = StateProvider<ShippingAddress?>(
  (ref) => null,
);
