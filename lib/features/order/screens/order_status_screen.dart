import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_image.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../services/order_service.dart';

/// Order Status screen — fetches real order data and displays:
/// - Per-outfit progress cards with status + progress bar
/// - Payment status (adapts for full payment vs deposit 50%)
/// - Chat CTA at bottom
class OrderStatusScreen extends ConsumerWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Real-time stream — updates instantly when tailor changes status
    final orderAsync = ref.watch(orderStreamProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: orderAsync.when(
          data: (order) {
            if (order == null) return _buildNotFound(context);
            return _buildContent(context, order);
          },
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => _buildNotFound(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BusanaOrder order) {
    return Column(
      children: [
        // ─── Header ──────────────────────────────────────────
        _buildAppBar(context, order),

        // ─── Scrollable Content ──────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSummary(context, order),
                const SizedBox(height: 8),
                _buildOutfitCards(context, order),
                const SizedBox(height: 8),
                _buildPaymentSection(context, order),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // ─── Bottom CTA ──────────────────────────────────────
        _buildBottomActions(context, order),
      ],
    );
  }

  // ─── App Bar ────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, BusanaOrder order) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
      child: Row(
        children: [
          // Back arrow — same as cart (arrow_left.svg, 33x33)
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
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Order Status',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${order.orderNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Spacer to balance the back button
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ─── Order Summary ──────────────────────────────────────────────────────

  Widget _buildOrderSummary(BuildContext context, BusanaOrder order) {
    final itemCount = order.items.length;
    final etaDate = order.orderDate.add(const Duration(days: 14));
    final etaFormatted = DateFormat('d MMM yyyy').format(etaDate);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row: outfit count + tailor icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$itemCount Outfit${itemCount > 1 ? 's' : ''} in This Order',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const Text('🧵', style: TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated completion: $etaFormatted',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 14),

          // Avatar stack + "Reviewing Details"
          Row(
            children: [
              // Stacked product thumbnails (show up to 2 + count)
              SizedBox(
                width: itemCount > 1 ? 52 : 32,
                height: 28,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      child: _buildMiniAvatar(
                        order.items.first.productImageUrl,
                      ),
                    ),
                    if (itemCount > 1)
                      Positioned(
                        left: 18,
                        child: _buildMiniAvatarCount('+${itemCount - 1}'),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'Reviewing Details',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar(String imageUrl) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        color: AppColors.surfaceVariant,
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? AppNetworkImage(
                imageUrl: imageUrl,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              )
            : const Icon(Icons.checkroom, size: 12, color: AppColors.primary),
      ),
    );
  }

  Widget _buildMiniAvatarCount(String count) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          count,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─── Outfit Progress Cards ──────────────────────────────────────────────

  Widget _buildOutfitCards(BuildContext context, BusanaOrder order) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: order.items.asMap().entries.map((entry) {
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: entry.key < order.items.length - 1 ? 14 : 0,
            ),
            child: _buildOutfitCard(
              context: context,
              item: item,
              itemIndex: entry.key,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOutfitCard({
    required BuildContext context,
    required OrderItem item,
    required int itemIndex,
  }) {
    final statusColor = _itemStatusColor(item.status);
    final statusLabel = item.status.label.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 64,
              child: item.productImageUrl.isNotEmpty
                  ? AppNetworkImage(
                      imageUrl: item.productImageUrl,
                      width: 56,
                      height: 64,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(8),
                    )
                  : Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(
                        Icons.checkroom,
                        color: AppColors.textTertiary,
                        size: 24,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + View link
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final uri = Uri(
                          path: '/orders/$orderId/details',
                          queryParameters: {'item': '$itemIndex'},
                        );
                        context.push(uri.toString());
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          'View',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Status badge + skip reason
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.skipReason != null && item.skipReason!.isNotEmpty)
                      Expanded(
                        child: Text(
                          item.skipReason!,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          'ETA: ${_estimateEtaFromStatus(item.status)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textTertiary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Progress bar (uses model's dynamic workflow calculation)
                Row(
                  children: [
                    Text(
                      'Progress',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${item.progressPercent}%',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 6,
                    backgroundColor: AppColors.borderLight,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),

                // Tailor notes (if any)
                if (item.tailorNotes != null &&
                    item.tailorNotes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '📝 ${item.tailorNotes}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _itemStatusColor(ItemStatus status) {
    switch (status) {
      case ItemStatus.newOrder:
        return AppColors.statusPending;
      case ItemStatus.waitingFabric:
        return AppColors.info;
      case ItemStatus.cutting:
      case ItemStatus.sewing:
        return AppColors.statusInProgress;
      case ItemStatus.fitting:
      case ItemStatus.adjustment:
        return const Color(0xFFFF9800);
      case ItemStatus.qc:
        return const Color(0xFF00BCD4);
      case ItemStatus.ready:
        return AppColors.statusReady;
      case ItemStatus.delivered:
        return AppColors.statusCompleted;
    }
  }

  String _estimateEtaFromStatus(ItemStatus status) {
    final daysLeft = switch (status) {
      ItemStatus.newOrder => 14,
      ItemStatus.waitingFabric => 12,
      ItemStatus.cutting => 10,
      ItemStatus.sewing => 7,
      ItemStatus.fitting => 5,
      ItemStatus.adjustment => 4,
      ItemStatus.qc => 2,
      ItemStatus.ready => 0,
      ItemStatus.delivered => 0,
    };
    if (daysLeft == 0) return 'Completed';
    final eta = DateTime.now().add(Duration(days: daysLeft));
    return DateFormat('d MMM yyyy').format(eta);
  }

  // ─── Payment Section ────────────────────────────────────────────────────

  Widget _buildPaymentSection(BuildContext context, BusanaOrder order) {
    final payment = order.payment;
    if (payment == null) return const SizedBox.shrink();

    final isFullPayment = payment.paymentTerms == PaymentTerms.fullPayment;
    final totalAmount = order.totalAmount;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Status',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          if (isFullPayment) ...[
            // ── Full Payment UI ──
            // Show a clean "Paid in Full" confirmation with checkmark
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paid in Full',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.statusCompleted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'RM${totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Payment method icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        payment.paymentMethod.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('d MMM yyyy').format(payment.paidAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.statusCompleted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No outstanding balance. Your order is fully paid.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── Deposit 50% UI ──
            // Deposit paid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Deposit Paid',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'RM${payment.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.statusReady,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Remaining balance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Remaining Balance',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'RM${(totalAmount - payment.amount).toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE53935),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Info note — balance due upon collection
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Balance due upon collection or delivery of final items.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Chat Button ────────────────────────────────────────────────────────

  // ─── Bottom Actions (Chat + Cancel) ──────────────────────────────────────

  Widget _buildBottomActions(BuildContext context, BusanaOrder order) {
    final canCancel = order.status.isCancellable;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chat button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/orders/$orderId/chat'),
                icon: const Icon(Icons.chat_bubble, size: 18),
                label: Text(
                  'Chat Us',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Cancel button OR production started indicator
            if (canCancel)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _showCancelDialog(context, order),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: Text(
                    'Cancel Order',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              )
            else if (order.status != OrderStatus.cancelled &&
                order.status != OrderStatus.completed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.precision_manufacturing,
                      size: 16,
                      color: AppColors.statusInProgress,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Production Started — Cannot Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show cancellation confirmation dialog with backend validation.
  void _showCancelDialog(BuildContext context, BusanaOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Cancel Order?',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Keep Order',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeCancellation(context, order.id);
            },
            child: Text(
              'Confirm Cancellation',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Execute cancellation with backend validation.
  Future<void> _executeCancellation(
    BuildContext context,
    String orderId,
  ) async {
    try {
      final orderService = OrderService();
      await orderService.cancelOrder(orderId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order has been cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Pop back to orders list
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── Not Found State ────────────────────────────────────────────────────

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Order not found',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
