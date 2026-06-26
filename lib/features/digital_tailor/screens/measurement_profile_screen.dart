import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/measurement.dart';

/// Screen displaying stored measurement data or CTA to start scanning.
class MeasurementProfileScreen extends ConsumerWidget {
  const MeasurementProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Pengukuran Tubuh'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, ref),
        data: (profile) {
          if (profile == null) {
            return _buildErrorState(context, ref);
          }

          final measurementData = profile.measurementData;
          if (measurementData.isEmpty) {
            return _buildEmptyState(context);
          }

          return _buildMeasurementList(context, measurementData);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.straighten,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Belum Ada Data Pengukuran',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Gunakan fitur Digital Scanning untuk mengukur tubuh Anda secara otomatis menggunakan kamera.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            AppButton(
              label: 'Mulai Scanning Digital',
              onPressed: () => context.push('/digital-tailor/calibration'),
              isFullWidth: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementList(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    // Extract metadata
    final scannedAt = data['scanned_at'];
    final confidenceScore = (data['confidence_score'] as num?)?.toDouble();

    // Extract measurements (exclude metadata keys)
    final metadataKeys = {'scanned_at', 'confidence_score', 'scan_version'};
    final measurements = <Measurement>[];

    for (final entry in data.entries) {
      if (metadataKeys.contains(entry.key)) continue;
      if (entry.value is Map<String, dynamic>) {
        measurements.add(
          Measurement.fromMap(entry.key, entry.value as Map<String, dynamic>),
        );
      }
    }

    // Group by region
    final grouped = <MeasurementRegion, List<Measurement>>{};
    for (final m in measurements) {
      grouped.putIfAbsent(m.region, () => []).add(m);
    }

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scan info card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(scannedAt),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (confidenceScore != null)
                      _buildConfidenceBadge(confidenceScore),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Scan Ulang',
                        variant: AppButtonVariant.outline,
                        size: AppButtonSize.small,
                        onPressed: () => _showRescanDialog(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Measurements grouped by region
          for (final region in MeasurementRegion.values)
            if (grouped.containsKey(region)) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  region.displayName,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              ...grouped[region]!.map((m) => _buildMeasurementRow(m)),
              const SizedBox(height: AppSpacing.sm),
            ],

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildMeasurementRow(Measurement m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderRadiusMd,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
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

  Widget _buildConfidenceBadge(double score) {
    final label = score >= 0.8
        ? 'Tinggi'
        : score >= 0.6
        ? 'Sedang'
        : 'Rendah';
    final color = score >= 0.8
        ? Colors.green
        : score >= 0.6
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 56,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Gagal memuat data pengukuran',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Coba Lagi',
              size: AppButtonSize.small,
              isFullWidth: false,
              onPressed: () => ref.invalidate(userProfileStreamProvider),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Tanggal tidak tersedia';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        // Firestore Timestamp
        date = (timestamp).toDate();
      }
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return 'Tanggal tidak tersedia';
    }
  }

  void _showRescanDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan Ulang?'),
        content: const Text(
          'Data pengukuran sebelumnya akan ditimpa dengan hasil scan baru. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/digital-tailor/calibration');
            },
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
  }
}
