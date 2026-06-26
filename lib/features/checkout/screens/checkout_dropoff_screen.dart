import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_image.dart';
import '../../cart/models/cart_item.dart';
import '../../cart/providers/cart_provider.dart';
import '../../order/models/order_model.dart';
import '../../profile/models/shipping_address.dart';
import '../../profile/providers/address_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../profile/widgets/address_picker_sheet.dart';
import '../providers/checkout_provider.dart';

/// Unified checkout screen matching the design reference.
///
/// Sections (scrollable):
/// 1. Shipping Address (from user profile)
/// 2. Receiving Method (ship to address / self-collection)
/// 3. Fabric Delivery (drop off at boutique / self-shipping) + calendar
/// 4. Payment Terms (Deposit 50% / Full Payment)
/// 5. Payment Method (Visa / Mastercard / DuitNow QR)
/// 6. Order Summary (cart items with thumbnails)
/// 7. Totals (tailor fee + fabric)
/// 8. Place Order button
class CheckoutDropoffScreen extends ConsumerStatefulWidget {
  const CheckoutDropoffScreen({super.key});

  @override
  ConsumerState<CheckoutDropoffScreen> createState() =>
      _CheckoutDropoffScreenState();
}

class _CheckoutDropoffScreenState extends ConsumerState<CheckoutDropoffScreen> {
  @override
  void initState() {
    super.initState();
    // Reset checkout state when entering screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkoutNotifierProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(checkoutNotifierProvider);
    final cartAsync = ref.watch(cartItemsStreamProvider);
    final profileAsync = ref.watch(userProfileStreamProvider);

    // Listen for completed order → navigate to confirmation
    ref.listen<CheckoutState>(checkoutNotifierProvider, (prev, next) {
      if (next.completedOrder != null && prev?.completedOrder == null) {
        context.go(AppRoutes.orderConfirmation);
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: cartAsync.when(
                    data: (cartItems) {
                      final selectedIds = ref.watch(
                        selectedCartItemIdsProvider,
                      );
                      // Use selected items if any, otherwise all items
                      final checkoutItems = selectedIds.isEmpty
                          ? cartItems
                          : cartItems
                                .where((i) => selectedIds.contains(i.id))
                                .toList();

                      return _buildBody(
                        checkoutItems,
                        checkoutState,
                        profileAsync,
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),

            // Payment processing overlay
            if (checkoutState.isProcessing)
              _buildProcessingOverlay(checkoutState),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
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
          const Spacer(),
          Text(
            'Checkout',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Colors.black,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40), // balance
        ],
      ),
    );
  }

  // ─── Body ───────────────────────────────────────────────────────────────

  Widget _buildBody(
    List<CartItem> cartItems,
    CheckoutState checkoutState,
    AsyncValue profileAsync,
  ) {
    // Get address from address provider system
    final selectedAddress = ref.watch(selectedCheckoutAddressProvider);
    final defaultAddress = ref.watch(defaultAddressProvider);
    final activeAddress = selectedAddress ?? defaultAddress;

    // Fallback to profile data if no address saved
    final profile = profileAsync.valueOrNull;
    final customerName =
        activeAddress?.recipientName ?? profile?.fullName ?? '';
    final customerPhone = activeAddress?.phone ?? profile?.phone ?? '';
    final shippingAddress =
        activeAddress?.fullAddress ?? profile?.address ?? '';

    // Calculate totals
    double tailorFeeTotal = 0;
    double fabricTotal = 0;
    for (final item in cartItems) {
      if (item.fabricType == 'tailor') {
        tailorFeeTotal += (item.unitPrice - 50.0) * item.quantity;
        fabricTotal += 50.0 * item.quantity;
      } else {
        tailorFeeTotal += item.unitPrice * item.quantity;
      }
    }
    final totalAmount = tailorFeeTotal + fabricTotal;

    // Fabric delivery section only needed if customer provides own fabric
    final hasOwnFabric = cartItems.any((item) => item.fabricType == 'own');

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Shipping Address
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader(
                      Icons.location_on_outlined,
                      'Shipping Address',
                    ),
                    GestureDetector(
                      onTap: () async {
                        final picked = await AddressPickerSheet.show(context);
                        if (picked != null) {
                          ref
                                  .read(
                                    selectedCheckoutAddressProvider.notifier,
                                  )
                                  .state =
                              picked;
                        }
                      },
                      child: Text(
                        'Change',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (activeAddress != null)
                  _buildAddressCard(activeAddress)
                else
                  Text(
                    shippingAddress.isNotEmpty
                        ? '$customerName\n$shippingAddress\n$customerPhone'
                        : 'No address saved. Tap "Change" to add one.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),

                const SizedBox(height: 24),

                // 2. Receiving Method
                _buildSectionHeader(null, 'Receiving Method'),
                const SizedBox(height: 10),
                _buildRadioOption(
                  label: 'Ship orders to address',
                  isSelected:
                      checkoutState.deliveryMethod ==
                      DeliveryMethod.shipToAddress,
                  onTap: () => ref
                      .read(checkoutNotifierProvider.notifier)
                      .setDeliveryMethod(DeliveryMethod.shipToAddress),
                ),
                const SizedBox(height: 8),
                _buildRadioOption(
                  label: 'Self-collection / Pickup',
                  isSelected:
                      checkoutState.deliveryMethod ==
                      DeliveryMethod.selfCollection,
                  onTap: () => ref
                      .read(checkoutNotifierProvider.notifier)
                      .setDeliveryMethod(DeliveryMethod.selfCollection),
                ),

                const SizedBox(height: 24),

                // 3. Fabric Delivery — only for own fabric orders
                if (hasOwnFabric) ...[
                  _buildSectionHeader(null, 'Fabric Delivery'),
                  const SizedBox(height: 10),
                  // Boutique address info (static, not a radio button)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/glyphs-poly_map-marker-line.svg',
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Boutique Address',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Busana Prima Tailoring & Fashion,\nMayor Street Garden, Maxim City,\n58100, Kuala Lumpur',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Radio: Drop off at boutique
                  _buildRadioOption(
                    label: 'Drop off at boutique',
                    isSelected:
                        checkoutState.fabricDeliveryMethod ==
                        FabricDeliveryMethod.dropOffAtBoutique,
                    onTap: () => ref
                        .read(checkoutNotifierProvider.notifier)
                        .setFabricDeliveryMethod(
                          FabricDeliveryMethod.dropOffAtBoutique,
                        ),
                  ),

                  const SizedBox(height: 12),

                  // Calendar date picker — only when drop off at boutique is selected
                  if (checkoutState.fabricDeliveryMethod ==
                      FabricDeliveryMethod.dropOffAtBoutique)
                    _buildDatePicker(checkoutState),

                  if (checkoutState.fabricDeliveryMethod ==
                      FabricDeliveryMethod.dropOffAtBoutique)
                    const SizedBox(height: 12),

                  // Radio: Self-shipping
                  _buildRadioOption(
                    label: 'Self-shipping (You drop off to courier)',
                    isSelected:
                        checkoutState.fabricDeliveryMethod ==
                        FabricDeliveryMethod.selfShipping,
                    onTap: () => ref
                        .read(checkoutNotifierProvider.notifier)
                        .setFabricDeliveryMethod(
                          FabricDeliveryMethod.selfShipping,
                        ),
                  ),

                  const SizedBox(height: 12),

                  // Reminder banner — only shows when self-shipping is selected
                  if (checkoutState.fabricDeliveryMethod ==
                      FabricDeliveryMethod.selfShipping)
                    _buildReminderBanner(),
                ],

                const SizedBox(height: 24),

                // 4. Payment Terms
                _buildSectionHeader(Icons.payments_outlined, 'Payment Terms'),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildPaymentTermCard(
                          label: 'Deposit (50%)',
                          subtitle:
                              'Pay RM ${(totalAmount * 0.5).toStringAsFixed(2)}\nfor now',
                          isSelected:
                              checkoutState.paymentTerms ==
                              PaymentTerms.deposit50,
                          onTap: () => ref
                              .read(checkoutNotifierProvider.notifier)
                              .setPaymentTerms(PaymentTerms.deposit50),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPaymentTermCard(
                          label: 'Full Payment',
                          subtitle: '',
                          isSelected:
                              checkoutState.paymentTerms ==
                              PaymentTerms.fullPayment,
                          onTap: () => ref
                              .read(checkoutNotifierProvider.notifier)
                              .setPaymentTerms(PaymentTerms.fullPayment),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 5. Payment Method
                _buildSectionHeader(
                  Icons.credit_card_outlined,
                  'Payment Method',
                ),
                const SizedBox(height: 10),
                _buildPaymentMethodOption(
                  label: 'Visa',
                  icon: Icons.credit_card,
                  isSelected: checkoutState.paymentMethod == PaymentMethod.visa,
                  onTap: () => ref
                      .read(checkoutNotifierProvider.notifier)
                      .setPaymentMethod(PaymentMethod.visa),
                ),
                const SizedBox(height: 8),
                _buildPaymentMethodOption(
                  label: 'Mastercard',
                  icon: Icons.credit_card,
                  isSelected:
                      checkoutState.paymentMethod == PaymentMethod.mastercard,
                  onTap: () => ref
                      .read(checkoutNotifierProvider.notifier)
                      .setPaymentMethod(PaymentMethod.mastercard),
                ),
                const SizedBox(height: 8),
                _buildPaymentMethodOption(
                  label: 'DuitNow QR',
                  icon: Icons.qr_code,
                  isSelected:
                      checkoutState.paymentMethod == PaymentMethod.duitNowQR,
                  onTap: () => ref
                      .read(checkoutNotifierProvider.notifier)
                      .setPaymentMethod(PaymentMethod.duitNowQR),
                ),

                const SizedBox(height: 24),

                // 6. Order Summary
                _buildSectionHeader(null, 'Order Summary'),
                const SizedBox(height: 10),
                ...cartItems.map((item) => _buildOrderSummaryItem(item)),

                const SizedBox(height: 16),

                // 7. Totals + Payment Breakdown
                _buildTotalRow(
                  'Tailor Fee:',
                  'RM ${tailorFeeTotal.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 4),
                _buildTotalRow(
                  'Fabric:',
                  'RM ${fabricTotal.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 12),
                _buildTotalRow(
                  'Order Total (${cartItems.length} item${cartItems.length > 1 ? 's' : ''}):',
                  'RM ${totalAmount.toStringAsFixed(2)}',
                  isBold: true,
                ),

                // Payment breakdown based on payment terms
                if (checkoutState.paymentTerms == PaymentTerms.deposit50) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFB74D).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pay Now (50% Deposit):',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'RM ${(totalAmount * 0.5).toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE65100),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Balance (due on collection):',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              'RM ${(totalAmount * 0.5).toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pay Now (Full Payment):',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          'RM ${totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Error message
                if (checkoutState.errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      checkoutState.errorMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 8. Place Order button
        _buildPlaceOrderButton(
          cartItems: cartItems,
          customerName: customerName,
          customerPhone: customerPhone,
          shippingAddress: shippingAddress,
          activeAddress: activeAddress,
          isProcessing: checkoutState.isProcessing,
        ),
      ],
    );
  }

  // ─── Section Header ─────────────────────────────────────────────────────

  Widget _buildSectionHeader(IconData? icon, String title) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  // ─── Address Card ───────────────────────────────────────────────────────

  Widget _buildAddressCard(ShippingAddress address) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                address.recipientName,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  address.label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            address.fullAddress,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            address.phone,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ─── Radio Option ───────────────────────────────────────────────────────

  Widget _buildRadioOption({
    required String label,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Date & Time Picker (Calendar + Operating Hours) ─────────────────────

  Widget _buildDatePicker(CheckoutState checkoutState) {
    final selectedDate = checkoutState.fabricDropoffDate;

    return GestureDetector(
      onTap: () async {
        // Step 1: Pick date
        final date = await showDatePicker(
          context: context,
          initialDate:
              selectedDate ?? DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(primary: AppColors.primary),
              ),
              child: child!,
            );
          },
        );
        if (date == null || !mounted) return;

        // Step 2: Pick time (restricted to operating hours 10AM–4PM)
        final time = await showTimePicker(
          context: context,
          initialTime: const TimeOfDay(hour: 10, minute: 0),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(primary: AppColors.primary),
              ),
              child: child!,
            );
          },
        );
        if (time == null || !mounted) return;

        // Validate: operating hours 10AM–4PM only
        if (time.hour < 10 || time.hour >= 16) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Drop-off time must be within operating hours (10:00 AM – 4:00 PM)',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Combine date + time → store as UTC
        final combined = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        ref
            .read(checkoutNotifierProvider.notifier)
            .setFabricDropoffDate(combined.toUtc());
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selectedDate != null
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(10),
          color: selectedDate != null
              ? AppColors.primary.withValues(alpha: 0.03)
              : null,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedDate != null
                    ? DateFormat('d MMMM yyyy').format(selectedDate.toLocal())
                    : 'Select fabric drop-off date',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: selectedDate != null ? Colors.black : Colors.grey,
                ),
              ),
            ),
            Text(
              selectedDate != null
                  ? DateFormat('h:mm a').format(selectedDate.toLocal())
                  : '10AM – 4PM',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: selectedDate != null
                    ? FontWeight.w500
                    : FontWeight.w400,
                color: selectedDate != null
                    ? AppColors.primary
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Reminder Banner ────────────────────────────────────────────────────

  Widget _buildReminderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFADEDE),
        borderRadius: BorderRadius.circular(11),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Reminder: ',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            TextSpan(
              text: 'Please send fabric within 3 days after ordering',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Payment Term Card ──────────────────────────────────────────────────

  Widget _buildPaymentTermCard({
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.black,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: isSelected ? AppColors.primary : Colors.black54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Payment Method Option ──────────────────────────────────────────────

  Widget _buildPaymentMethodOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.black,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black54),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Order Summary Item ─────────────────────────────────────────────────

  Widget _buildOrderSummaryItem(CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 50,
              height: 56,
              child: item.productImageUrl.isNotEmpty
                  ? AppNetworkImage(
                      imageUrl: item.productImageUrl,
                      width: 50,
                      height: 56,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(8),
                    )
                  : Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.image_outlined, size: 20),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.fabricLabel} / ${item.sizeLabel ?? "M"} >',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  'RM ${item.unitPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFFFF1E22),
                  ),
                ),
              ],
            ),
          ),
          // Quantity
          Text(
            'x${item.quantity}',
            style: GoogleFonts.roboto(fontSize: 14, color: Colors.black),
          ),
        ],
      ),
    );
  }

  // ─── Total Row ──────────────────────────────────────────────────────────

  Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  // ─── Place Order Button ─────────────────────────────────────────────────

  Widget _buildPlaceOrderButton({
    required List<CartItem> cartItems,
    required String customerName,
    required String customerPhone,
    required String shippingAddress,
    ShippingAddress? activeAddress,
    required bool isProcessing,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isProcessing
                ? null
                : () {
                    ref
                        .read(checkoutNotifierProvider.notifier)
                        .placeOrder(
                          cartItems: cartItems,
                          customerName: customerName,
                          customerPhone: customerPhone,
                          shippingAddress: shippingAddress,
                          addressSnapshot: activeAddress?.toOrderSnapshot(),
                        );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF732871),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Place Order',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Processing Overlay ─────────────────────────────────────────────────

  Widget _buildProcessingOverlay(CheckoutState state) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF732871)),
              ),
              const SizedBox(height: 24),
              Text(
                state.processingMessage ?? 'Processing...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please do not close this screen',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
