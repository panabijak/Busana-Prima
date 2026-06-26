import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/scan_result.dart';
import '../providers/measurement_profile_provider.dart';

/// Bottom sheet for saving measurement results as a named profile.
/// Minimal UX: only requires a profile name.
class SaveProfileSheet extends ConsumerStatefulWidget {
  final ScanResult scanResult;
  final VoidCallback onSaved;

  const SaveProfileSheet({
    super.key,
    required this.scanResult,
    required this.onSaved,
  });

  @override
  ConsumerState<SaveProfileSheet> createState() => _SaveProfileSheetState();
}

class _SaveProfileSheetState extends ConsumerState<SaveProfileSheet> {
  final _nameController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorText = 'Sila masukkan nama ukuran');
      return;
    }

    if (name.length > 30) {
      setState(() => _errorText = 'Nama terlalu panjang (max 30 aksara)');
      return;
    }

    setState(() => _errorText = null);

    final notifier = ref.read(profileOperationsProvider.notifier);
    final success = await notifier.createProfile(
      profileName: name,
      scanResult: widget.scanResult,
    );

    if (success && mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final opState = ref.watch(profileOperationsProvider);
    final detectedSize = ref
        .read(profileOperationsProvider.notifier)
        .detectSize(widget.scanResult);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPaddingH,
        right: AppSpacing.screenPaddingH,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
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

          const SizedBox(height: AppSpacing.xl),

          // Title
          Text('Simpan Ukuran', style: AppTextStyles.heading3),

          const SizedBox(height: AppSpacing.sm),

          // Detected size badge
          if (detectedSize != '-')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Saiz dikesan: $detectedSize',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),

          const SizedBox(height: AppSpacing.xl),

          // Profile name input
          Text('Nama Ukuran', style: AppTextStyles.labelMedium),
          const SizedBox(height: AppSpacing.sm),

          AppTextField(
            controller: _nameController,
            hint: 'Contoh: Ayah, Anak Lelaki, Baju Nikah',
            errorText: _errorText ?? opState.errorMessage,
            maxLength: 30,
            autofocus: true,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Suggestions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSuggestionChip('Pana'),
              _buildSuggestionChip('Ayah'),
              _buildSuggestionChip('Ibu'),
              _buildSuggestionChip('Anak 1'),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Save button
          AppButton(
            label: opState.isLoading ? 'Menyimpan...' : 'Simpan',
            onPressed: opState.isLoading ? null : _onSave,
            isLoading: opState.isLoading,
            isFullWidth: true,
          ),

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return GestureDetector(
      onTap: () {
        _nameController.text = label;
        setState(() => _errorText = null);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textTertiary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Show the save profile bottom sheet
Future<void> showSaveProfileSheet(
  BuildContext context, {
  required ScanResult scanResult,
  required VoidCallback onSaved,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) =>
        SaveProfileSheet(scanResult: scanResult, onSaved: onSaved),
  );
}
