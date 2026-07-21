import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';

/// Shared ETA label used on My Orders, Order Tracking, and Outfit Details.
///
/// Reads [estimatedCompletionDate] from Firestore only — never hardcoded.
class EstimatedCompletionLabel extends StatelessWidget {
  final DateTime? estimatedCompletionDate;
  final bool isLoading;
  final String? formattedRange;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const EstimatedCompletionLabel({
    super.key,
    required this.estimatedCompletionDate,
    this.isLoading = false,
    this.formattedRange,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final labelTextStyle = labelStyle ??
        GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        );

    final valueTextStyle = valueStyle ??
        GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        );

    final loadingTextStyle = valueTextStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: AppColors.textTertiary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Estimated completion:', style: labelTextStyle),
        const SizedBox(height: 2),
        if (isLoading)
          Text('Calculating completion date...', style: loadingTextStyle)
        else if (formattedRange != null && formattedRange!.isNotEmpty)
          Text(formattedRange!, style: valueTextStyle)
        else if (estimatedCompletionDate != null)
          Text(_formatDate(estimatedCompletionDate!), style: valueTextStyle)
        else
          Text('Calculating completion date...', style: loadingTextStyle),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// Inline variant: "Estimated completion: 20 May 2026"
class EstimatedCompletionInline extends StatelessWidget {
  final DateTime? estimatedCompletionDate;
  final bool isLoading;
  final String? formattedRange;

  const EstimatedCompletionInline({
    super.key,
    required this.estimatedCompletionDate,
    this.isLoading = false,
    this.formattedRange,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Text(
        'Estimated completion: Calculating completion date...',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: AppColors.textTertiary,
        ),
      );
    }

    final value = formattedRange?.isNotEmpty == true
        ? formattedRange!
        : estimatedCompletionDate != null
            ? _formatDate(estimatedCompletionDate!)
            : null;

    if (value == null) {
      return Text(
        'Estimated completion: Calculating completion date...',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: AppColors.textTertiary,
        ),
      );
    }

    return Text(
      'Estimated completion: $value',
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
