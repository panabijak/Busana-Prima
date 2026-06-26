import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';

/// Quick action chip categories for tailoring-specific conversations.
enum QuickActionTopic {
  fabric,
  design,
  measurement,
  fitting,
  delivery;

  String get label {
    switch (this) {
      case QuickActionTopic.fabric:
        return '🧵 Fabric';
      case QuickActionTopic.design:
        return '✏️ Design';
      case QuickActionTopic.measurement:
        return '📐 Measurement';
      case QuickActionTopic.fitting:
        return '👗 Fitting';
      case QuickActionTopic.delivery:
        return '📦 Delivery';
    }
  }

  /// Suggested message template when chip is tapped.
  String get suggestedMessage {
    switch (this) {
      case QuickActionTopic.fabric:
        return 'Hi, I have a question about the fabric for my order.';
      case QuickActionTopic.design:
        return 'Hi, I would like to discuss a design change for my order.';
      case QuickActionTopic.measurement:
        return 'Hi, I need to update my measurements for this order.';
      case QuickActionTopic.fitting:
        return 'Hi, I would like to schedule a fitting session.';
      case QuickActionTopic.delivery:
        return 'Hi, I have a question about the delivery of my order.';
    }
  }
}

/// A horizontal scrollable row of quick action chips
/// that pre-fill common tailoring discussion topics.
class QuickActionChips extends StatelessWidget {
  final void Function(QuickActionTopic topic) onTap;
  final bool visible;

  const QuickActionChips({super.key, required this.onTap, this.visible = true});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: Text(
              'Quick topics:',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: QuickActionTopic.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final topic = QuickActionTopic.values[index];
                return _buildChip(topic);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(QuickActionTopic topic) {
    return GestureDetector(
      onTap: () => onTap(topic),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          topic.label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
