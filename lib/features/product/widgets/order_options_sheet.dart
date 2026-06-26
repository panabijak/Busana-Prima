import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../cart/providers/cart_provider.dart';
import '../../digital_tailor/models/measurement_profile.dart';
import '../../digital_tailor/providers/measurement_profile_provider.dart';
import '../models/product.dart';

/// Bottom sheet for product order options.
class OrderOptionsSheet extends ConsumerStatefulWidget {
  final Product product;

  const OrderOptionsSheet({super.key, required this.product});

  static Future<void> show(BuildContext context, Product product) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: OrderOptionsSheet(product: product),
      ),
    );
  }

  @override
  ConsumerState<OrderOptionsSheet> createState() => _OrderOptionsSheetState();
}

class _OrderOptionsSheetState extends ConsumerState<OrderOptionsSheet> {
  int _orderType = -1;
  int _measurementType = -1;
  int _selectedColor = -1;
  int _selectedProfileIndex = 0; // Which measurement profile is selected

  bool get _isComplete =>
      _orderType >= 0 && _selectedColor >= 0 && _measurementType >= 0;

  @override
  Widget build(BuildContext context) {
    final colors = widget.product.availableColors;
    final basePrice = widget.product.basePrice;
    final fabricCost = _orderType == 1 ? 50.0 : 0.0;
    final total = basePrice + fabricCost;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(21),
          topRight: Radius.circular(21),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header + Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order type',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          color: Colors.black,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close,
                          size: 24,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ─── Order Type ─────────────────────────────────
                  _buildRadioOption(
                    label: 'I have my own fabric',
                    isSelected: _orderType == 0,
                    onTap: () => setState(() => _orderType = 0),
                  ),
                  const SizedBox(height: 8),
                  _buildRadioOption(
                    label: 'I want fabric from tailor',
                    isSelected: _orderType == 1,
                    onTap: () => setState(() => _orderType = 1),
                  ),

                  const SizedBox(height: 24),

                  // ─── Choose Colour ──────────────────────────────
                  Text(
                    'Choose colour',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildColorPicker(colors),

                  const SizedBox(height: 24),

                  // ─── Body Measurements (Real Data) ──────────────
                  Text(
                    'Body Measurements',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMeasurementSection(),

                  const SizedBox(height: 20),

                  // ─── Reminder Banner ────────────────────────────
                  if (_orderType == 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
                                fontSize: 15,
                                color: Colors.black,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'Fabric must be sent after the order is placed',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w400,
                                fontSize: 15,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_orderType == 0) const SizedBox(height: 20),

                  // ─── Price Summary ──────────────────────────────
                  Text(
                    'Price Summary',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPriceRow(
                    'Tailor Fee:',
                    'RM ${basePrice.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 4),
                  _buildPriceRow(
                    'Fabric:',
                    _orderType == 1
                        ? 'RM ${fabricCost.toStringAsFixed(2)}'
                        : 'RM 0',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Total:',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'RM ${total.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 23,
                          color: const Color(0xFFFF1E22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── Bottom Action Bar ────────────────────────────────────
          Container(
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
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 12,
                          bottom: 12 + MediaQuery.of(context).padding.bottom,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.center_focus_strong_outlined,
                              size: 22,
                            ),
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
                    child: InkWell(
                      onTap: () {},
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 12,
                          bottom: 12 + MediaQuery.of(context).padding.bottom,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.favorite_border, size: 22),
                            const SizedBox(height: 4),
                            Text(
                              'Add to Favourite',
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
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _isComplete ? () => _addToCart(context) : null,
                      child: Container(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom,
                        ),
                        color: _isComplete
                            ? const Color(0xFF702A70)
                            : const Color(0xFF702A70).withValues(alpha: 0.4),
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
          ),
        ],
      ),
    );
  }

  // ─── Add to Cart Action ──────────────────────────────────────────────────

  Future<void> _addToCart(BuildContext context) async {
    final cartService = ref.read(cartServiceProvider);
    final product = widget.product;
    final colors = product.availableColors;

    final fabricType = _orderType == 0 ? 'own' : 'tailor';
    final selectedColor = _selectedColor >= 0 && _selectedColor < colors.length
        ? colors[_selectedColor]
        : '';
    final fabricCost = _orderType == 1 ? 50.0 : 0.0;
    final unitPrice = product.basePrice + fabricCost;

    // Get measurement profile info for size label
    String? measurementProfileId;
    String? sizeLabel;
    if (_measurementType == 0) {
      // Using saved measurements — use the selected profile
      final profilesAsync = ref.read(measurementProfilesStreamProvider);
      profilesAsync.whenData((profiles) {
        if (profiles.isNotEmpty && _selectedProfileIndex < profiles.length) {
          measurementProfileId = profiles[_selectedProfileIndex].profileId;
          sizeLabel = profiles[_selectedProfileIndex].sizeCategory;
        }
      });
    } else if (_measurementType == 1) {
      // "Create new measurement" selected — validate scan completed
      final profilesAsync = ref.read(measurementProfilesStreamProvider);
      bool hasCompletedProfile = false;
      profilesAsync.whenData((profiles) {
        if (profiles.isNotEmpty) {
          // User completed a scan — use latest profile
          measurementProfileId = profiles.first.profileId;
          sizeLabel = profiles.first.sizeCategory;
          hasCompletedProfile = true;
        }
      });

      if (!hasCompletedProfile) {
        // Block: measurement not completed
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Complete measurement scan first before adding to cart',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Final validation: measurement must exist
    if (measurementProfileId == null || measurementProfileId!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A measurement profile is required to proceed'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      await cartService.addToCart(
        productId: product.id,
        productName: product.name,
        productImageUrl: product.displayImage,
        fabricType: fabricType,
        selectedColor: selectedColor,
        measurementProfileId: measurementProfileId,
        sizeLabel: sizeLabel ?? 'M',
        unitPrice: unitPrice,
      );

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add to cart: $e')));
      }
    }
  }

  // ─── Body Measurements Section with Real Data ───────────────────────────

  Widget _buildMeasurementSection() {
    final profilesAsync = ref.watch(measurementProfilesStreamProvider);

    return profilesAsync.when(
      data: (profiles) => _buildMeasurementCards(profiles),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => _buildMeasurementCards([]),
    );
  }

  Widget _buildMeasurementCards(List<MeasurementProfile> profiles) {
    final hasProfiles = profiles.isNotEmpty;

    return Column(
      children: [
        // Card 1: Use saved measurements
        _buildMeasurementCard(
          isSelected: _measurementType == 0,
          onTap: hasProfiles
              ? () => setState(() => _measurementType = 0)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.checkroom_outlined,
                    size: 18,
                    color: _measurementType == 0
                        ? const Color(0xFF702A70)
                        : Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use saved measurements',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: hasProfiles ? Colors.black : Colors.black38,
                      ),
                    ),
                  ),
                  if (_measurementType == 0)
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Color(0xFF702A70),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                hasProfiles
                    ? 'Select a measurement profile below'
                    : 'No saved measurements yet',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.black45,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (hasProfiles && _measurementType == 0) ...[
                const SizedBox(height: 10),
                // Selectable list of all profiles
                ...profiles.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final profile = entry.value;
                  final isActive = idx == _selectedProfileIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedProfileIndex = idx),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFF9F5FF)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF702A70).withValues(alpha: 0.4)
                              : Colors.grey.shade200,
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Radio indicator
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFF702A70)
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: isActive
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF702A70),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.profileName,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Size: ${profile.sizeCategory} • Updated: ${DateFormat('d MMM yyyy').format(profile.updatedAt)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isActive)
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Color(0xFF702A70),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Card 2: Create new measurement
        _buildMeasurementCard(
          isSelected: _measurementType == 1,
          onTap: () => setState(() => _measurementType = 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.accessibility_new_outlined,
                    size: 18,
                    color: _measurementType == 1
                        ? const Color(0xFF702A70)
                        : Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Create new measurement',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  if (_measurementType == 1)
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Color(0xFF702A70),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Use 3D body scan for a fresh profile',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.black45,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (_measurementType == 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () async {
                      // Close sheet and navigate to 3D scan
                      Navigator.pop(context);
                      context.push(AppRoutes.digitalTailorCalibration);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF702A70),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.center_focus_strong,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Start 3D Scan',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Helper Widgets ─────────────────────────────────────────────────────

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
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF702A70)
                    : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF702A70),
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                  color: Colors.black,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(List<String> colorNames) {
    final colorMap = <String, Color>{
      'pastel pink': const Color(0xFFFFF7AD),
      'yellow': const Color(0xFFFFF7AD),
      'blue': const Color(0xFFBBD8FF),
      'navy': const Color(0xFFBBD8FF),
      'green': const Color(0xFF0DB91C),
      'purple': const Color(0xFFAF0DAF),
      'white': Colors.white,
      'black': Colors.black,
      'red': Colors.red,
      'pink': const Color(0xFFFFB6C1),
      'cream': const Color(0xFFFFF7AD),
    };
    final displayColors = colorNames.isEmpty
        ? [
            const Color(0xFFFFF7AD),
            const Color(0xFFBBD8FF),
            const Color(0xFF0DB91C),
            const Color(0xFFAF0DAF),
          ]
        : colorNames
              .map(
                (name) => colorMap[name.toLowerCase()] ?? Colors.grey.shade300,
              )
              .toList();

    return Row(
      children: List.generate(displayColors.length, (index) {
        final isSelected = _selectedColor == index;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = index),
          child: Container(
            width: 48,
            height: 24,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: displayColors[index],
              border: isSelected
                  ? Border.all(color: Colors.black, width: 2)
                  : Border.all(color: Colors.grey.shade300, width: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: Colors.black,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementCard({
    required bool isSelected,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFCF9FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF702A70) : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Opacity(opacity: onTap != null ? 1.0 : 0.5, child: child),
      ),
    );
  }
}
