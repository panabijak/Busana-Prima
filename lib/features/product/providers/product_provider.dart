import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../services/product_service.dart';

/// Singleton ProductService provider.
final productServiceProvider = Provider((ref) => ProductService());

/// Stream all active products (respects isActive flag).
final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final service = ref.watch(productServiceProvider);
  return service.activeProductsStream();
});

/// Stream "Top Choice" products for the Home Screen hero section.
final topChoicesStreamProvider = StreamProvider<List<Product>>((ref) {
  final service = ref.watch(productServiceProvider);
  return service.topChoicesStream();
});

/// Stream products filtered by category name.
final productsByCategoryProvider = StreamProvider.family<List<Product>, String>(
  (ref, category) {
    final service = ref.watch(productServiceProvider);
    return service.productsByCategoryStream(category);
  },
);

/// Stream active categories for the filter tabs.
final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final service = ref.watch(productServiceProvider);
  return service.categoriesStream();
});

/// Search query state provider.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered products based on search query.
/// Searches across name, category, fabricType, and description.
final searchResultsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final productsAsync = ref.watch(productsStreamProvider);

  if (query.isEmpty) return const AsyncValue.data([]);

  return productsAsync.when(
    data: (products) {
      final results = products.where((p) {
        final name = p.name.toLowerCase();
        final category = p.category.toLowerCase();
        final fabric = (p.fabricType ?? '').toLowerCase();
        final description = (p.description ?? '').toLowerCase();
        final colors = p.availableColors.join(' ').toLowerCase();

        return name.contains(query) ||
            category.contains(query) ||
            fabric.contains(query) ||
            description.contains(query) ||
            colors.contains(query);
      }).toList();
      return AsyncValue.data(results);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Stream reviews for a specific product.
final reviewsForProductProvider = StreamProvider.family<List<Review>, String>((
  ref,
  productId,
) {
  final service = ref.watch(productServiceProvider);
  return service.reviewsForProductStream(productId);
});

/// Fetch a single product by ID.
final productByIdProvider = FutureProvider.family<Product?, String>((
  ref,
  productId,
) {
  final service = ref.watch(productServiceProvider);
  return service.getProduct(productId);
});
