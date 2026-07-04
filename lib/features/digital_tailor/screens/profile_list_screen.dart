import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/measurement_profile.dart';
import '../providers/measurement_profile_provider.dart';

/// Screen displaying list of saved measurement profiles.
/// Replaces the old single measurement view.
class ProfileListScreen extends ConsumerStatefulWidget {
  const ProfileListScreen({super.key});

  @override
  ConsumerState<ProfileListScreen> createState() => _ProfileListScreenState();
}

class _ProfileListScreenState extends ConsumerState<ProfileListScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger legacy data migration on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileOperationsProvider.notifier).migrateLegacyData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(measurementProfilesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Measurement Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Scan',
            onPressed: () => context.push('/digital-tailor/calibration'),
          ),
        ],
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, ref),
        data: (profiles) {
          if (profiles.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildProfileList(context, profiles);
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
              'No Measurement Profiles',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Scan your body to save a measurement profile.\nYou can save profiles for yourself, family members, or customers.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            AppButton(
              label: 'Start Digital Scan',
              onPressed: () => context.push('/digital-tailor/calibration'),
              isFullWidth: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileList(
    BuildContext context,
    List<MeasurementProfile> profiles,
  ) {
    return ListView.builder(
      padding: AppSpacing.screenPadding,
      itemCount: profiles.length + 1, // +1 for the "Add New" button at bottom
      itemBuilder: (context, index) {
        if (index == profiles.length) {
          // Add new profile button
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: AppButton(
              label: 'New Scan',
              variant: AppButtonVariant.outline,
              prefixIcon: Icons.add,
              onPressed: () => context.push('/digital-tailor/calibration'),
            ),
          );
        }

        final profile = profiles[index];
        return _buildProfileCard(context, profile, index == 0);
      },
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    MeasurementProfile profile,
    bool isFirst,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderRadiusMd,
        boxShadow: AppShadows.sm,
        border: isFirst
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: InkWell(
        borderRadius: AppRadius.borderRadiusMd,
        onTap: () => _showProfileDetail(context, profile),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Profile name
                  Expanded(
                    child: Text(
                      profile.profileName,
                      style: AppTextStyles.heading4,
                    ),
                  ),
                  // Size badge
                  if (profile.sizeCategory != '-')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Size: ${profile.sizeCategory}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Measurement summary
              Text(
                profile.summaryText.isNotEmpty
                    ? profile.summaryText
                    : 'No summary data',
                style: AppTextStyles.bodySmall,
              ),

              const SizedBox(height: 8),

              // Footer row
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(profile.updatedAt),
                    style: AppTextStyles.caption,
                  ),
                  const Spacer(),
                  // Delete button
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () => _confirmDelete(context, profile),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),

              // Active indicator
              if (isFirst)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Active Profile',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileDetail(BuildContext context, MeasurementProfile profile) {
    // Navigate to detail view (reuse existing measurement display)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) =>
            _buildDetailSheet(ctx, profile, scrollController),
      ),
    );
  }

  Widget _buildDetailSheet(
    BuildContext context,
    MeasurementProfile profile,
    ScrollController scrollController,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Expanded(
                child: Text(profile.profileName, style: AppTextStyles.heading3),
              ),
              if (profile.sizeCategory != '-')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    profile.sizeCategory,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Measurements list
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: profile.measurements.length,
              itemBuilder: (ctx, index) {
                final m = profile.measurements[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: AppRadius.borderRadiusSm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(m.label, style: AppTextStyles.bodyMedium),
                      ),
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
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, MeasurementProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: Text(
          'Profile "${profile.profileName}" will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(profileOperationsProvider.notifier)
                  .deleteProfile(profile.profileId);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
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
              'Failed to load measurement profiles',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Try Again',
              size: AppButtonSize.small,
              isFullWidth: false,
              onPressed: () =>
                  ref.invalidate(measurementProfilesStreamProvider),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }
}
