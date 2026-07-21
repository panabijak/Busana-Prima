import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/router/app_router.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../utils/estimated_completion_utils.dart';
import '../utils/order_display_utils.dart';
import '../widgets/estimated_completion_label.dart';

/// Order page showing all user orders with tab filtering and search.
///
/// Tabs aligned with bespoke tailoring workflow:
/// All | In Tailoring | Ready | Completed | Cancelled
class OrderPageScreen extends ConsumerStatefulWidget {
  final bool showBackButton;

  const OrderPageScreen({super.key, this.showBackButton = true});

  @override
  ConsumerState<OrderPageScreen> createState() => _OrderPageScreenState();
}

class _OrderPageScreenState extends ConsumerState<OrderPageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _tabs = [
    'All',
    'In Tailoring',
    'Ready',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(userOrdersSafeProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          'My Orders',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          isScrollable: true,
          labelStyle: AppTextStyles.labelLarge,
          unselectedLabelStyle: AppTextStyles.labelMedium,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Order list
          Expanded(
            child: ordersAsync.when(
              data: (orders) => _buildTabContent(orders),
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (e, _) => _buildTabContent([]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Search Bar ─────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.sm,
        AppSpacing.screenPaddingH,
        AppSpacing.md,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search Orders...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textHint,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textTertiary,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.inputFill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.round),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.round),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.round),
            borderSide: const BorderSide(color: AppColors.primary, width: 1),
          ),
        ),
      ),
    );
  }

  // ─── Tab Content ────────────────────────────────────────────────────────

  Widget _buildTabContent(List<BusanaOrder> orders) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOrderList(_filterOrders(orders, null)),
        _buildOrderList(_filterOrders(orders, OrderTabFilters.inTailoring)),
        _buildOrderList(_filterOrders(orders, OrderTabFilters.ready)),
        _buildOrderList(_filterOrders(orders, OrderTabFilters.completed)),
        _buildOrderList(_filterOrders(orders, OrderTabFilters.cancelled)),
      ],
    );
  }

  List<BusanaOrder> _filterOrders(
    List<BusanaOrder> orders,
    List<OrderStatus>? statuses,
  ) {
    var filtered = orders;

    // Filter by status tab
    if (statuses != null) {
      filtered = filtered.where((o) => statuses.contains(o.status)).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((order) {
        final matchesOrderNumber = order.orderNumber.toLowerCase().contains(
          query,
        );
        final matchesItemName = order.items.any(
          (item) => item.productName.toLowerCase().contains(query),
        );
        return matchesOrderNumber || matchesItemName;
      }).toList();
    }

    return filtered;
  }

  // ─── Order List ─────────────────────────────────────────────────────────

  Widget _buildOrderList(List<BusanaOrder> orders) {
    if (orders.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.md,
      ),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
    );
  }

  // ─── Order Card ─────────────────────────────────────────────────────────

  Widget _buildOrderCard(BusanaOrder order) {
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final dateFormatted = DateFormat('d MMM yyyy').format(order.orderDate);

    return AppCard(
      onTap: () => context.push('/orders/${order.id}/status'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Order ID + Status Badge ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order ID: #${order.orderNumber}',
                style: AppTextStyles.labelMedium,
              ),
              _buildStatusBadge(order),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Product Info Row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 72,
                  height: 84,
                  child:
                      firstItem != null && firstItem.productImageUrl.isNotEmpty
                      ? AppNetworkImage(
                          imageUrl: firstItem.productImageUrl,
                          width: 72,
                          height: 84,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        )
                      : Container(
                          color: AppColors.surfaceVariant,
                          child: const Icon(
                            Icons.checkroom,
                            color: AppColors.textTertiary,
                            size: 28,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name
                    Text(
                      firstItem?.productName ?? 'Order',
                      style: AppTextStyles.heading4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Multi-item progress (if applicable)
                    if (order.items.length > 1 &&
                        _isActiveStatus(order.status)) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.content_cut,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${order.items.length} outfits in this order',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],

                    // Date / ETA info
                    _buildDateInfo(order, dateFormatted),
                  ],
                ),
              ),
            ],
          ),

          // ── Contextual Actions ──
          const SizedBox(height: AppSpacing.md),
          _buildActionButtons(order),
        ],
      ),
    );
  }

  // ─── Date / ETA info ────────────────────────────────────────────────────

  Widget _buildDateInfo(BusanaOrder order, String dateFormatted) {
    if (_isActiveStatus(order.status)) {
      final eta = resolveOrderEstimatedCompletion(order);
      return EstimatedCompletionLabel(
        estimatedCompletionDate: eta.singleDate,
        formattedRange: eta.hasDate ? eta.format() : null,
      );
    } else if (order.status == OrderStatus.completed) {
      return Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.success),
          const SizedBox(width: 4),
          Text(
            'Delivered on $dateFormatted',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    } else if (order.status == OrderStatus.cancelled) {
      return Text(
        'Refund Processed',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return Text('Ordered on $dateFormatted', style: AppTextStyles.bodySmall);
  }

  // ─── Action Buttons ─────────────────────────────────────────────────────

  Widget _buildActionButtons(BusanaOrder order) {
    switch (order.status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.inProgress:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.push('/orders/${order.id}/status'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: const Text('View Status'),
          ),
        );

      case OrderStatus.ready:
      case OrderStatus.outForDelivery:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.push('/orders/${order.id}/status'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusReady,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: const Text('Ready for Pickup'),
          ),
        );

      case OrderStatus.completed:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: const Text('Reorder'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton(
                onPressed: () => context.push('/orders/${order.id}/details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        );

      case OrderStatus.cancelled:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.push('/orders/${order.id}/details'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: const Text('View Details'),
          ),
        );
    }
  }

  // ─── Status Badge ───────────────────────────────────────────────────────

  Widget _buildStatusBadge(BusanaOrder order) {
    final color = orderStatusColor(order.status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        order.displayStatusLabel,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool _isActiveStatus(OrderStatus status) {
    return OrderTabFilters.inTailoring.contains(status) ||
        status == OrderStatus.ready ||
        status == OrderStatus.outForDelivery;
  }

  // ─── Empty State ────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No orders yet',
              style: AppTextStyles.heading4.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your tailoring orders will appear here',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: const Text('Browse Designs'),
            ),
          ],
        ),
      ),
    );
  }
}
