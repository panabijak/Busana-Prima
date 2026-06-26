import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_image.dart';
import '../../product/models/product.dart';
import '../../product/providers/product_provider.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../services/cart_service.dart';

/// Shopping Cart screen matching the design reference.
///
/// Layout:
/// - AppBar: back arrow, "Shopping Cart (N)" title, "All" toggle
/// - Cart item list with checkbox, image, name, fabric/size, price, quantity pill, delete icon
/// - "~ You might like to fill it with ~" recommendation section
/// - Bottom bar: total price (red) + "Checkout now >>" button (purple)
class ShoppingCartScreen extends ConsumerStatefulWidget {
  const ShoppingCartScreen({super.key});

  @override
  ConsumerState<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends ConsumerState<ShoppingCartScreen> {
  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartItemsStreamProvider);
    final selectedIds = ref.watch(selectedCartItemIdsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: cartAsync.when(
          data: (cartItems) => _buildContent(cartItems, selectedIds),
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Center(child: Text('Error loading cart: $e')),
        ),
      ),
    );
  }

  Widget _buildContent(List<CartItem> cartItems, Set<String> selectedIds) {
    final selectedTotal = cartItems
        .where((item) => selectedIds.contains(item.id))
        .fold(0.0, (sum, item) => sum + item.lineTotal);

    return Column(
      children: [
        // ─── Header ──────────────────────────────────────────────
        _buildHeader(cartItems, selectedIds),

        // ─── Cart Items + Recommendations ────────────────────────
        Expanded(
          child: cartItems.isEmpty
              ? _buildEmptyCart()
              : _buildScrollableContent(cartItems, selectedIds),
        ),

        // ─── Bottom Bar ──────────────────────────────────────────
        if (cartItems.isNotEmpty) _buildBottomBar(selectedTotal),
      ],
    );
  }

  // ─── Header with back, title, "All" toggle ──────────────────────────────

  Widget _buildHeader(List<CartItem> cartItems, Set<String> selectedIds) {
    final allSelected =
        cartItems.isNotEmpty && selectedIds.length == cartItems.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.pop(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SvgPicture.asset(
                'assets/icons/arrow_left.svg',
                width: 33,
                height: 33,
              ),
            ),
          ),
          const Spacer(),
          // Title
          Text(
            'Shopping Cart (${cartItems.length})',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Colors.black,
            ),
          ),
          const Spacer(),
          // "All" toggle
          GestureDetector(
            onTap: () {
              if (allSelected) {
                ref.read(selectedCartItemIdsProvider.notifier).state = {};
              } else {
                ref.read(selectedCartItemIdsProvider.notifier).state = cartItems
                    .map((e) => e.id)
                    .toSet();
              }
            },
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: allSelected ? AppColors.primary : Colors.grey,
                      width: 2,
                    ),
                    color: allSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: allSelected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 4),
                Text(
                  'All',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Scrollable content: cart items + recommendations ────────────────────

  Widget _buildScrollableContent(
    List<CartItem> cartItems,
    Set<String> selectedIds,
  ) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Cart items
        ...cartItems.map((item) => _buildCartItemTile(item, selectedIds)),

        const SizedBox(height: 24),

        // Recommendation section
        _buildRecommendationSection(),

        const SizedBox(height: 16),
      ],
    );
  }

  // ─── Single cart item tile ──────────────────────────────────────────────

  Widget _buildCartItemTile(CartItem item, Set<String> selectedIds) {
    final isSelected = selectedIds.contains(item.id);
    final cartService = ref.read(cartServiceProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Checkbox ──
          GestureDetector(
            onTap: () {
              final current = Set<String>.from(
                ref.read(selectedCartItemIdsProvider),
              );
              if (isSelected) {
                current.remove(item.id);
              } else {
                current.add(item.id);
              }
              ref.read(selectedCartItemIdsProvider.notifier).state = current;
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.black.withValues(alpha: 0.31),
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.white,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),

          // ── Product Image ──
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 62,
              height: 68,
              child: item.productImageUrl.isNotEmpty
                  ? AppNetworkImage(
                      imageUrl: item.productImageUrl,
                      width: 62,
                      height: 68,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(8),
                    )
                  : Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(
                        Icons.image_outlined,
                        color: AppColors.textTertiary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Product Info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row: name + delete icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete icon
                    GestureDetector(
                      onTap: () => _confirmDelete(item, cartService),
                      child: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Subtitle: fabric type / size >
                Text(
                  '${item.fabricLabel} / ${item.sizeLabel ?? "M"} >',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                // Row: price + quantity controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price in red
                    Text(
                      'RM ${item.unitPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: const Color(0xFFFF1E22),
                      ),
                    ),
                    // Quantity pill
                    _buildQuantityPill(item, cartService),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quantity pill: (−) count (+) with blue background ──────────────────

  Widget _buildQuantityPill(CartItem item, CartService cartService) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0C6FFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus
          GestureDetector(
            onTap: () {
              if (item.quantity > 1) {
                cartService.updateQuantity(item.id, item.quantity - 1);
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.remove, size: 14, color: Colors.white),
            ),
          ),
          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${item.quantity}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          // Plus
          GestureDetector(
            onTap: () {
              cartService.updateQuantity(item.id, item.quantity + 1);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Delete confirmation ────────────────────────────────────────────────

  void _confirmDelete(CartItem item, CartService cartService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove item'),
        content: Text('Remove "${item.productName}" from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              cartService.removeFromCart(item.id);
              // Also remove from selected set
              final current = Set<String>.from(
                ref.read(selectedCartItemIdsProvider),
              );
              current.remove(item.id);
              ref.read(selectedCartItemIdsProvider.notifier).state = current;
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─── Recommendations section ────────────────────────────────────────────

  Widget _buildRecommendationSection() {
    final productsAsync = ref.watch(productsStreamProvider);

    return Column(
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '~ You might like to fill it with  ~',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Product grid (vertical, 2 columns like home page)
        productsAsync.when(
          data: (products) {
            if (products.isEmpty) return const SizedBox.shrink();
            // Show up to 6 recommendations
            final recommendations = products.take(6).toList();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                itemCount: recommendations.length,
                itemBuilder: (context, index) =>
                    _buildRecommendationCard(recommendations[index]),
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(Product product) {
    return GestureDetector(
      onTap: () => context.push('/product/${product.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AppNetworkImage(
          imageUrl: product.displayImage,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ─── Bottom bar: price + checkout button ────────────────────────────────

  Widget _buildBottomBar(double totalPrice) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left side: total price
              Expanded(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'RM ${totalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 21,
                      color: const Color(0xFFFF1E22),
                    ),
                  ),
                ),
              ),
              // Right side: checkout button (purple)
              Expanded(
                child: GestureDetector(
                  onTap: totalPrice > 0
                      ? () => context.push(AppRoutes.checkoutDropoff)
                      : null,
                  child: Container(
                    color: const Color(0xFF732871),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Checkout now >>',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty cart state ───────────────────────────────────────────────────

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text('Your cart is empty', style: AppTextStyles.heading4),
          const SizedBox(height: 8),
          Text(
            'Start adding items to your cart',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.go(AppRoutes.home),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Browse Products',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
