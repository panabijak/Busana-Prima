import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../services/favourites_service.dart';
import '../services/product_service.dart';

/// Singleton FavouritesService provider.
final favouritesServiceProvider = Provider((ref) => FavouritesService());

/// Stream all favourite product IDs for the current user.
final favouriteIdsProvider = StreamProvider<List<String>>((ref) {
  final service = ref.watch(favouritesServiceProvider);
  return service.favouriteIdsStream();
});

/// Check if a specific product is favourited.
final isFavouritedProvider = StreamProvider.family<bool, String>((
  ref,
  productId,
) {
  final service = ref.watch(favouritesServiceProvider);
  return service.isFavouritedStream(productId);
});

/// Stream full Product objects for all favourited items.
final favouriteProductsProvider = StreamProvider<List<Product>>((ref) {
  final favouriteIdsAsync = ref.watch(favouriteIdsProvider);
  final productService = ref.watch(ProductServiceProvider);

  return favouriteIdsAsync.when(
    data: (ids) {
      if (ids.isEmpty) return Stream.value([]);
      // Fetch all products and filter by favourite IDs
      return productService.activeProductsStream().map(
        (products) => products.where((p) => ids.contains(p.id)).toList(),
      );
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

/// Provider reference for ProductService (reuse from product_provider).
final ProductServiceProvider = Provider((ref) => ProductService());
