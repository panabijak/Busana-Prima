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

/// Outfit Details screen — shows a single outfit's full details:
/// - Header card: product image, name, ID, status badge, ETA, progress bar
/// - Tailoring Progress timeline
/// - Measurements + Fabric info (two-column)
/// - Customer notes quote
class OutfitDetailsScreen extends ConsumerWidget {
  final String orderId;
  final int itemIndex;

  const OutfitDetailsScreen({
    super.key,
    required this.orderId,
    this.itemIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    // Show the specific outfit item based on itemIndex
    if (itemIndex >= order.items.length) return _buildNotFound(context);
    final item = order.items[itemIndex];

    return Column(
      children: [
        // App bar
        _buildAppBar(context),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOutfitHeader(order, item),
                const SizedBox(height: 8),
                _buildTailoringProgress(order),
                const SizedBox(height: 8),
                _buildMeasurementsAndFabric(order, item),
                const SizedBox(height: 8),
                _buildCustomerNotes(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Contact Tailor button
        _buildContactTailorButton(context, order),
      ],
    );
  }

  // ─── App Bar ────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
      child: Row(
        children: [
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
          Expanded(
            child: Center(
              child: Text(
                'Outfit Details',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48), // balance
        ],
      ),
    );
  }

  // ─── Outfit Header Card ─────────────────────────────────────────────────

  Widget _buildOutfitHeader(BusanaOrder order, OrderItem item) {
    final statusLabel = item.status.label;
    final statusColor = _itemStatusColor(item.status);
    final progress = item.progress;
    final etaDate = order.orderDate.add(const Duration(days: 14));
    final etaFormatted = DateFormat('d MMM yyyy').format(etaDate);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 100,
                  height: 120,
                  child: item.productImageUrl.isNotEmpty
                      ? AppNetworkImage(
                          imageUrl: item.productImageUrl,
                          width: 100,
                          height: 120,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(10),
                        )
                      : Container(
                          color: AppColors.surfaceVariant,
                          child: const Icon(
                            Icons.checkroom,
                            size: 36,
                            color: AppColors.textTertiary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: #${order.orderNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Status badge + ETA
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'ETA: $etaFormatted',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(progress * 100).toInt()}% Complete',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tailoring Progress Timeline ────────────────────────────────────────

  Widget _buildTailoringProgress(BusanaOrder order) {
    // Use the specific item based on itemIndex
    if (itemIndex >= order.items.length) return const SizedBox.shrink();
    final item = order.items[itemIndex];
    final steps = _buildStepsFromItem(item, order.orderDate);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              const Icon(Icons.content_cut, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Tailoring Progress',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Timeline steps
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return _buildTimelineItem(step, isLast: index == steps.length - 1);
          }),
        ],
      ),
    );
  }

  /// Build timeline steps dynamically from item's workflow and current status.
  List<_ProgressStep> _buildStepsFromItem(OrderItem item, DateTime orderDate) {
    final workflow = item.workflowSteps;
    final currentIdx = workflow.indexOf(item.status);
    final dateFormat = DateFormat('d MMM yyyy • hh:mm a');

    return workflow.asMap().entries.map((entry) {
      final idx = entry.key;
      final step = entry.value;
      final isCompleted = idx < currentIdx;
      final isCurrent = idx == currentIdx;

      // Generate subtitle based on completion state
      String subtitle;
      if (isCompleted) {
        // Estimate completed date (spread across days from order date)
        final estimatedDate = orderDate.add(Duration(days: idx * 2));
        subtitle = dateFormat.format(estimatedDate);
      } else if (isCurrent) {
        subtitle = 'In progress';
        if (item.tailorNotes != null && item.tailorNotes!.isNotEmpty) {
          subtitle = item.tailorNotes!;
        }
      } else {
        subtitle = 'Pending';
      }

      // Handle skip reason for fitting
      if (step == ItemStatus.fitting &&
          !item.fittingRequired &&
          item.skipReason != null) {
        subtitle = 'Skipped: ${item.skipReason}';
      }

      return _ProgressStep(
        title: _stepTitle(step),
        subtitle: subtitle,
        isCompleted: isCompleted,
        isCurrent: isCurrent,
      );
    }).toList();
  }

  String _stepTitle(ItemStatus status) {
    switch (status) {
      case ItemStatus.newOrder:
        return 'Order Confirmed';
      case ItemStatus.waitingFabric:
        return 'Fabric Received';
      case ItemStatus.cutting:
        return 'Cutting Fabric';
      case ItemStatus.sewing:
        return 'Sewing Process';
      case ItemStatus.fitting:
        return 'Fitting Session';
      case ItemStatus.adjustment:
        return 'Alteration & Adjustment';
      case ItemStatus.qc:
        return 'Quality Check';
      case ItemStatus.ready:
        return 'Ready for Delivery';
      case ItemStatus.delivered:
        return 'Delivered';
    }
  }

  Widget _buildTimelineItem(_ProgressStep step, {required bool isLast}) {
    Color dotColor;
    Widget dotContent;

    if (step.isCompleted) {
      dotColor = AppColors.statusCompleted;
      dotContent = const Icon(Icons.check, size: 10, color: Colors.white);
    } else if (step.isCurrent) {
      dotColor = AppColors.primary;
      dotContent = Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
    } else {
      dotColor = AppColors.border;
      dotContent = const SizedBox.shrink();
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: step.isCompleted || step.isCurrent
                        ? dotColor
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                  child: Center(child: dotContent),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: step.isCompleted
                          ? AppColors.statusCompleted
                          : AppColors.borderLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Text content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: step.isCompleted || step.isCurrent
                          ? Colors.black
                          : AppColors.textTertiary,
                      fontStyle: step.isCurrent
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Measurements + Fabric ──────────────────────────────────────────────

  Widget _buildMeasurementsAndFabric(BusanaOrder order, OrderItem item) {
    final fabricLabel = item.fabricType == 'tailor'
        ? "Tailor's Fabric"
        : 'Customer-supplied';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Measurements
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEASUREMENTS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                _buildMeasurementRow('Chest', '92 cm'),
                const SizedBox(height: 8),
                _buildMeasurementRow('Waist', '75 cm'),
                const SizedBox(height: 8),
                _buildMeasurementRow('Hip', '100 cm'),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    'VIEW FULL',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(width: 1, height: 120, color: AppColors.borderLight),
          const SizedBox(width: 16),

          // Right: Fabric info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FABRIC',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Type:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  fabricLabel,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Courier:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  order.fabricDeliveryMethod ==
                          FabricDeliveryMethod.selfShipping
                      ? 'Self-shipping'
                      : 'Drop off at boutique',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

  Widget _buildMeasurementRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  // ─── Customer Notes ─────────────────────────────────────────────────────

  Widget _buildCustomerNotes() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u201C\u201C',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.primary.withValues(alpha: 0.4),
              height: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '"Sleeve adjustment requested by customer: ensure 2-inch extra length for comfort."',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

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

  // ─── Contact Tailor Button ───────────────────────────────────────────────

  Widget _buildContactTailorButton(BuildContext context, BusanaOrder order) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/orders/${order.id}/chat'),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: Text(
              'Contact Tailor About This Outfit',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Not Found ──────────────────────────────────────────────────────────

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

/// Internal timeline step model.
class _ProgressStep {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;

  const _ProgressStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isCurrent,
  });
}
