import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../cart/widgets/cart_icon_button.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../providers/product_provider.dart';
import '../widgets/order_options_sheet.dart';
import '../widgets/favourite_heart_button.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _currentImageIndex = 0;
  bool _isDescriptionExpanded = false;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productByIdProvider(widget.productId));
    final reviewsAsync = ref.watch(reviewsForProductProvider(widget.productId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: productAsync.when(
        data: (product) {
          if (product == null) return _buildNotFound();
          return _buildContent(context, product, reviewsAsync);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('Product not found', style: GoogleFonts.inter(fontSize: 16)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Product product,
    AsyncValue<List<Review>> reviewsAsync,
  ) {
    // Build image list — use product imageUrl, could be single or multiple
    final images = <String>[
      if (product.imageUrl.isNotEmpty) product.imageUrl,
      if (product.thumbnailUrl != null && product.thumbnailUrl!.isNotEmpty)
        product.thumbnailUrl!,
    ];
    // Fallback if no images
    if (images.isEmpty) images.add('');

    final reviews = reviewsAsync.valueOrNull ?? [];
    final avgRating = reviews.isEmpty
        ? 0.0
        : reviews.fold<int>(0, (sum, r) => sum + r.rating) / reviews.length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Image Carousel ─────────────────────────────────
                SizedBox(
                  height: 520,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _currentImageIndex = index);
                        },
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final url = images[index];
                          if (url.isEmpty) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(
                                  Icons.checkroom_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, __) => Container(
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Back button
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 12,
                        left: 16,
                        child: GestureDetector(
                          onTap: () => context.pop(),
                          child: SvgPicture.asset(
                            'assets/icons/arrow_left.svg',
                            width: 33,
                            height: 33,
                          ),
                        ),
                      ),
                      // Cart button
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 12,
                        right: 16,
                        child: const CartIconButton(),
                      ),

                      // Image indicators
                      if (images.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (index) {
                              return Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentImageIndex == index
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ─── Product Info ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge
                      if (product.isTopChoice)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB419B8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Best Seller',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      // Product Name
                      Text(
                        product.name,
                        style: GoogleFonts.sourceSerif4(
                          fontWeight: FontWeight.bold,
                          fontSize: 23,
                          color: Colors.black,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Rating
                      if (reviews.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: GoogleFonts.sourceSerif4(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              ' (${reviews.length} reviews)',
                              style: GoogleFonts.sourceSerif4(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),

                      // Price — "From RMXXX"
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'From ',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: const Color(0xFFFF1E22),
                              ),
                            ),
                            TextSpan(
                              text: 'RM${product.basePrice.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 23,
                                color: const Color(0xFFFF1E22),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Fabric type chip
                      if (product.fabricType != null &&
                          product.fabricType!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.texture,
                                size: 14,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                product.fabricType!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Description section
                      if (product.description != null &&
                          product.description!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFE8C58A),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Description',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedCrossFade(
                          firstChild: Text(
                            _truncateDescription(product.description!),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                              color: Colors.black,
                              height: 1.4,
                            ),
                          ),
                          secondChild: Text(
                            product.description!,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                              color: Colors.black,
                              height: 1.4,
                            ),
                          ),
                          crossFadeState: _isDescriptionExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),
                        if (product.description!.length > 100) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => setState(
                              () => _isDescriptionExpanded =
                                  !_isDescriptionExpanded,
                            ),
                            child: Text(
                              _isDescriptionExpanded
                                  ? '[Read Less]'
                                  : '[Read More]',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: const Color(0xFFFF1E22),
                              ),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 28),

                      // ─── Reviews Section ──────────────────────────
                      _buildReviewsSection(reviews, avgRating),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Bottom Action Bar ──────────────────────────────────
        _buildBottomBar(context, product),
      ],
    );
  }

  Widget _buildReviewsSection(List<Review> reviews, double avgRating) {
    if (reviews.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Reviews',
            style: GoogleFonts.sourceSerif4(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No reviews yet. Be the first to review!',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 16),
            const SizedBox(width: 6),
            Text(
              '${avgRating.toStringAsFixed(1)} Customer Reviews (${reviews.length})',
              style: GoogleFonts.sourceSerif4(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Show max 3 reviews
        ...reviews
            .take(3)
            .map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildReviewItem(review),
              ),
            ),
      ],
    );
  }

  Widget _buildReviewItem(Review review) {
    // Mask customer name for privacy
    final maskedName = _maskName(review.customerId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              maskedName,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: List.generate(
                review.rating,
                (_) => const Icon(Icons.star, color: Colors.amber, size: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          review.comment,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w300,
            fontSize: 11,
            color: Colors.black87,
          ),
        ),
        // Show media thumbnails if available
        if (review.mediaUrls.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: review.mediaUrls.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: review.mediaUrls[index],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 1,
              child: InkWell(
                onTap: () {},
                child: Container(
                  padding: EdgeInsets.only(
                    top: 14,
                    bottom: 14 + MediaQuery.of(context).padding.bottom,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.center_focus_strong_outlined, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        'Try on',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(width: 1, color: Colors.grey.shade300),
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.only(
                  top: 14,
                  bottom: 14 + MediaQuery.of(context).padding.bottom,
                ),
                alignment: Alignment.center,
                child: FavouriteHeartButton(productId: product.id, size: 22),
              ),
            ),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () => OrderOptionsSheet.show(context, product),
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom,
                  ),
                  color: const Color(0xFF702A70),
                  alignment: Alignment.center,
                  child: Text(
                    'Add to cart',
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
    );
  }

  String _truncateDescription(String text) {
    if (text.length <= 100) return text;
    return '${text.substring(0, 100)}...';
  }

  String _maskName(String uid) {
    if (uid.length <= 4) return '***';
    return '${uid.substring(0, 1)}***${uid.substring(uid.length - 1)}';
  }
}
