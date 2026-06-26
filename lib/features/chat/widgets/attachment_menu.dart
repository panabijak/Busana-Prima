import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';

/// Attachment type options for the chat.
enum AttachmentType { camera, gallery, video, document }

/// Bottom sheet menu for selecting attachment type.
/// Shows options: Camera, Gallery, Video, Document.
class AttachmentMenu extends StatelessWidget {
  final void Function(AttachmentType type) onSelected;

  const AttachmentMenu({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Share',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Grid of options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOption(
                  context,
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFFE91E63),
                  type: AttachmentType.camera,
                ),
                _buildOption(
                  context,
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF9C27B0),
                  type: AttachmentType.gallery,
                ),
                _buildOption(
                  context,
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: const Color(0xFF2196F3),
                  type: AttachmentType.video,
                ),
                _buildOption(
                  context,
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Document',
                  color: const Color(0xFF4CAF50),
                  type: AttachmentType.document,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required AttachmentType type,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        onSelected(type);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Show the attachment menu as a bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required void Function(AttachmentType type) onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AttachmentMenu(onSelected: onSelected),
    );
  }
}
