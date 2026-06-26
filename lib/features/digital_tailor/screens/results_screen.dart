import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/router/app_router.dart';
import '../models/measurement.dart';
import '../providers/digital_tailor_provider.dart';
import '../providers/measurement_profile_provider.dart';
import '../widgets/save_profile_sheet.dart';

/// Screen displaying calculated measurement results for review and saving.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  final _scrollController = ScrollController();
  bool _hasViewedAll = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Auto-enable save after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _hasViewedAll = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.atEdge &&
        _scrollController.position.pixels != 0) {
      setState(() => _hasViewedAll = true);
    }
  }

  Future<void> _onSave() async {
    final result = ref.read(digitalTailorProvider).result;
    if (result == null) return;

    // Show save profile bottom sheet
    await showSaveProfileSheet(
      context,
      scanResult: result,
      onSaved: () {
        if (mounted) {
          context.go(AppRoutes.measurements);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil ukuran berjaya disimpan!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(digitalTailorProvider);
    final result = state.result;

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hasil Pengukuran')),
        body: const Center(child: Text('Tidak ada hasil tersedia.')),
      );
    }

    final grouped = result.groupedMeasurements;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => context.go(AppRoutes.profile),
        ),
        title: const Text('Hasil Pengukuran'),
        actions: [
          // Confidence badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _confidenceColor(
                result.confidenceScore,
              ).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified,
                  size: 14,
                  color: _confidenceColor(result.confidenceScore),
                ),
                const SizedBox(width: 4),
                Text(
                  result.confidenceLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _confidenceColor(result.confidenceScore),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Measurement list
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: AppSpacing.screenPadding,
              children: [
                // Auto-detected size badge
                Builder(
                  builder: (context) {
                    final size = ref
                        .read(sizeDetectionServiceProvider)
                        .detectSize(result.measurements);
                    if (size == '-') return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: AppRadius.borderRadiusMd,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.checkroom,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Saiz Dikesan: ',
                            style: AppTextStyles.bodyMedium,
                          ),
                          Text(
                            size,
                            style: AppTextStyles.heading4.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Flagged measurements warning
                if (result.flaggedMeasurements.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: AppRadius.borderRadiusMd,
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${result.flaggedMeasurements.length} pengukuran di luar rentang normal',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Grouped measurements
                for (final region in MeasurementRegion.values)
                  if (grouped.containsKey(region)) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.lg,
                        bottom: AppSpacing.sm,
                      ),
                      child: Text(
                        region.displayName,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    ...grouped[region]!.map((m) => _buildMeasurementTile(m)),
                  ],

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),

          // Bottom action bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error message
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  Row(
                    children: [
                      // Re-scan button
                      Expanded(
                        child: AppButton(
                          label: 'Scan Ulang',
                          variant: AppButtonVariant.outline,
                          onPressed: state.isSaving
                              ? null
                              : () {
                                  ref
                                      .read(digitalTailorProvider.notifier)
                                      .restartScan();
                                  context.pushReplacement(
                                    '/digital-tailor/calibration',
                                  );
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Save button
                      Expanded(
                        child: AppButton(
                          label: state.isSaving ? 'Menyimpan...' : 'Simpan',
                          onPressed: _hasViewedAll && !state.isSaving
                              ? _onSave
                              : null,
                          isLoading: state.isSaving,
                        ),
                      ),
                    ],
                  ),

                  // Back button after 3 failed saves
                  if (state.saveAttempts >= 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: () => context.go(AppRoutes.profile),
                        child: const Text('Kembali ke Profil'),
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

  Widget _buildMeasurementTile(Measurement m) {
    final isOutOfRange = !m.isWithinRange;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderRadiusMd,
        border: isOutOfRange ? Border.all(color: Colors.amber.shade300) : null,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          if (isOutOfRange)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Colors.amber.shade700,
              ),
            ),
          Expanded(child: Text(m.label, style: AppTextStyles.bodyMedium)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${m.valueCm} cm',
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${m.valueInch} in',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _confidenceColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }
}
