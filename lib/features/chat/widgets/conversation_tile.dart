import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme.dart';
import '../models/conversation.dart';

/// A list tile for displaying a conversation in the conversation list.
/// Shows: tailor avatar, order number, last message preview, timestamp, unread badge.
class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadFor(currentUserId);
    final hasUnread = unread > 0;
    final lastMsg = conversation.lastMessage;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Tailor avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary,
              child: Text(
                'KD',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order number + time
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order ${conversation.orderNumber}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastMsg != null)
                        Text(
                          _formatTimestamp(lastMsg.timestamp),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: hasUnread
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Last message preview + unread badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _lastMessageText(lastMsg),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: hasUnread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _lastMessageText(LastMessage? msg) {
    if (msg == null) return 'Start a conversation';
    if (msg.type != MessageType.text) return msg.type.displayLabel;
    return msg.text;
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (msgDate == today) return DateFormat('h:mm a').format(dateTime);
    if (today.difference(msgDate).inDays == 1) return 'Yesterday';
    if (today.difference(msgDate).inDays < 7) {
      return DateFormat('EEE').format(dateTime); // Mon, Tue
    }
    return DateFormat('d/M/yy').format(dateTime);
  }
}
