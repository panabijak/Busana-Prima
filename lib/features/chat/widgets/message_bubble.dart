import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

/// A single message bubble.
/// Supports text, image, video, file, and system message types.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isSentByMe;
  final VoidCallback? onImageTap;
  final VoidCallback? onVideoTap;
  final VoidCallback? onFileTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSentByMe,
    this.onImageTap,
    this.onVideoTap,
    this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    // System messages are centered
    if (message.type == MessageType.system) {
      return _buildSystemMessage();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isSentByMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSentByMe) ...[_buildAvatar(), const SizedBox(width: 6)],
          Flexible(child: _buildBubble(context)),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 12,
      backgroundColor: AppColors.primary,
      child: Text(
        'KD',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final bubbleColor = isSentByMe
        ? AppColors.chatBubbleSent
        : AppColors.chatBubbleReceived;
    final textColor = isSentByMe ? Colors.white : AppColors.textPrimary;
    final timeColor = isSentByMe
        ? Colors.white.withValues(alpha: 0.6)
        : AppColors.textTertiary;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(isSentByMe ? 14 : 4),
          bottomRight: Radius.circular(isSentByMe ? 4 : 14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Content based on type
          _buildContent(context, textColor),

          // Timestamp + status
          Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              message.type == MessageType.text ? 0 : 6,
              14,
              8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: GoogleFonts.inter(fontSize: 9, color: timeColor),
                ),
                if (isSentByMe) ...[
                  const SizedBox(width: 3),
                  _buildStatusIcon(timeColor),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    switch (message.type) {
      case MessageType.text:
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 3),
          child: Text(
            message.content,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: textColor,
              height: 1.4,
            ),
          ),
        );
      case MessageType.image:
        return _buildImageContent(context);
      case MessageType.video:
        return _buildVideoContent(context);
      case MessageType.file:
        return _buildFileContent(textColor);
      case MessageType.system:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImageContent(BuildContext context) {
    return GestureDetector(
      onTap: onImageTap,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 220,
            minHeight: 100,
            minWidth: 160,
          ),
          child: CachedNetworkImage(
            imageUrl: message.content,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 150,
              width: 200,
              color: AppColors.surfaceVariant,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              height: 100,
              width: 160,
              color: AppColors.surfaceVariant,
              child: const Icon(
                Icons.broken_image,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    final thumbnail = message.metadata?.thumbnailUrl;
    final duration = message.metadata?.durationLabel ?? '';

    return GestureDetector(
      onTap: onVideoTap,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 180,
              width: 240,
              color: AppColors.surfaceVariant,
              child: thumbnail != null && thumbnail.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumbnail,
                      fit: BoxFit.cover,
                      width: 240,
                      height: 180,
                    )
                  : const Icon(
                      Icons.videocam,
                      color: AppColors.textTertiary,
                      size: 40,
                    ),
            ),
            // Play button overlay
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
            ),
            // Duration badge
            if (duration.isNotEmpty)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    duration,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileContent(Color textColor) {
    final fileName = message.metadata?.fileName ?? 'Document';
    final fileSize = message.metadata?.fileSizeLabel ?? '';

    return GestureDetector(
      onTap: onFileTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSentByMe
                    ? Colors.white.withValues(alpha: 0.15)
                    : AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.insert_drive_file_outlined,
                size: 18,
                color: isSentByMe ? Colors.white : AppColors.info,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fileSize.isNotEmpty)
                    Text(
                      fileSize,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: textColor.withValues(alpha: 0.6),
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

  Widget _buildSystemMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(Color color) {
    switch (message.status) {
      case MessageStatus.sent:
        return Icon(Icons.check, size: 11, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 11, color: color);
      case MessageStatus.seen:
        return Icon(Icons.done_all, size: 11, color: AppColors.info);
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }
}
