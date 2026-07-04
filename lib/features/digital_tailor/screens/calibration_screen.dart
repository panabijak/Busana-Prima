import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/digital_tailor_provider.dart';

/// Screen for entering height calibration before scanning.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  final _heightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorText;

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  void _onProceed() {
    final text = _heightController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'Please enter your height');
      return;
    }

    final height = int.tryParse(text);
    if (height == null) {
      setState(() => _errorText = 'Please enter a valid number');
      return;
    }

    if (height < 100 || height > 250) {
      setState(() => _errorText = 'Height must be between 100 cm and 250 cm');
      return;
    }

    setState(() => _errorText = null);
    ref.read(digitalTailorProvider.notifier).setCalibration(height.toDouble());
    context.push('/digital-tailor/scanner');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Digital Tailor'),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // Icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.straighten,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Title
                Center(
                  child: Text(
                    'Height Calibration',
                    style: AppTextStyles.heading3,
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                Center(
                  child: Text(
                    'Enter your height for optimal measurement accuracy.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // Height input
                Text('Height (cm)', style: AppTextStyles.labelMedium),
                const SizedBox(height: AppSpacing.sm),

                AppTextField(
                  controller: _heightController,
                  hint: 'e.g. 165',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  errorText: _errorText,
                ),

                const SizedBox(height: AppSpacing.sm),

                Text(
                  'Accepted range: 100 cm – 250 cm',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),

                const Spacer(),

                // Proceed button
                AppButton(
                  label: 'Continue',
                  onPressed: _onProceed,
                  isFullWidth: true,
                ),

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
