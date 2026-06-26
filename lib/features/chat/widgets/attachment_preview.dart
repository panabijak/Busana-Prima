import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';

/// Preview dialog shown before sending an attachment.
/// Allows the user to review the file and cancel or confirm.
class AttachmentPreview extends StatelessWidget {
  final File file;
  final AttachmentPreviewType type;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const AttachmentPreview({
    super.key,
    required this.file,
    required this.type,
    required this.onSend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with cancel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: onCancel,
                  ),
                  const Spacer(),
                  Text(
                    _typeLabel,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance
                ],
              ),
            ),

            // Preview content
            Expanded(child: _buildPreview()),

            // File info + Send button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              color: Colors.black.withValues(alpha: 0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // File name
                  Text(
                    file.path.split('/').last,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Send button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onSend,
                      icon: const Icon(Icons.send, size: 18),
                      label: Text(
                        'Send',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    switch (type) {
      case AttachmentPreviewType.image:
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Center(
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.white38,
                size: 64,
              ),
            ),
          ),
        );
      case AttachmentPreviewType.video:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.videocam,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                file.path.split('/').last,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        );
      case AttachmentPreviewType.document:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.insert_drive_file,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  file.path.split('/').last,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: file.length(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return Text(
                    _formatFileSize(snapshot.data!),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  );
                },
              ),
            ],
          ),
        );
    }
  }

  String get _typeLabel {
    switch (type) {
      case AttachmentPreviewType.image:
        return 'Photo';
      case AttachmentPreviewType.video:
        return 'Video';
      case AttachmentPreviewType.document:
        return 'Document';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Show the preview as a full-screen modal route.
  /// Returns true if user confirmed sending.
  static Future<bool> show(
    BuildContext context, {
    required File file,
    required AttachmentPreviewType type,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AttachmentPreview(
          file: file,
          type: type,
          onSend: () => Navigator.of(context).pop(true),
          onCancel: () => Navigator.of(context).pop(false),
        ),
      ),
    );
    return result ?? false;
  }
}

/// Type of file being previewed.
enum AttachmentPreviewType { image, video, document }
