import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme.dart';
import '../../order/providers/order_provider.dart';
import '../models/call_log.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../screens/call_screen.dart';
import '../screens/media_preview_screen.dart';
import '../services/chat_service.dart';
import '../widgets/attachment_menu.dart';
import '../widgets/attachment_preview.dart';
import '../widgets/date_separator.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_composer.dart';
import '../widgets/order_context_header.dart';
import '../widgets/quick_action_chips.dart';

/// Order-linked chat screen.
///
/// Every conversation is tied to a specific order.
/// Opens an existing conversation or creates one on first message.
class ChatScreen extends ConsumerStatefulWidget {
  final String orderId;
  final bool showBackButton;

  const ChatScreen({
    super.key,
    required this.orderId,
    this.showBackButton = true,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  String? _conversationId;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Initialize or create the conversation for this order.
  Future<void> _initConversation() async {
    try {
      final chatService = ref.read(chatServiceProvider);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[ChatScreen] ERROR: User not authenticated');
        if (mounted) setState(() => _initializing = false);
        return;
      }

      debugPrint(
        '[ChatScreen] Initializing chat for orderId: ${widget.orderId}',
      );
      debugPrint(
        '[ChatScreen] Current user: ${user.uid} (${user.displayName})',
      );

      final conversation = await chatService.getOrCreateConversation(
        orderId: widget.orderId,
        orderNumber: '', // Will be populated from order data
        customerId: user.uid,
        customerName: user.displayName ?? 'Customer',
      );

      if (mounted) {
        setState(() {
          _conversationId = conversation.id;
          _initializing = false;
        });
        debugPrint('[ChatScreen] Conversation ready: ${conversation.id}');
        // Mark as read when opening
        chatService.markAsRead(conversation.id);
      }
    } catch (e, stack) {
      debugPrint('[ChatScreen] ERROR initializing conversation: $e');
      debugPrint('[ChatScreen] Stack: $stack');
      if (mounted) {
        setState(() => _initializing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar(null),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_conversationId == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar(null),
        body: _buildError(),
      );
    }

    final messagesAsync = ref.watch(messagesProvider(_conversationId!));
    final uploadState = ref.watch(uploadStateProvider);
    final conversationAsync = ref.watch(
      conversationByOrderProvider(widget.orderId),
    );
    final orderAsync = ref.watch(orderStreamProvider(widget.orderId));

    // Get order number from conversation for the header
    final orderNumber = conversationAsync.valueOrNull?.orderNumber ?? '';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: _buildAppBar(orderNumber),
      body: Column(
        children: [
          // Order context banner
          if (orderAsync.valueOrNull != null)
            OrderContextHeader(
              order: orderAsync.valueOrNull!,
              onViewOrder: () =>
                  context.push('/orders/${widget.orderId}/status'),
            ),

          // Messages list
          Expanded(
            child: messagesAsync.when(
              data: (messages) => _buildMessageList(messages),
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => _buildError(),
            ),
          ),

          // Quick action chips (show when chat is empty or has few messages)
          if ((messagesAsync.valueOrNull?.length ?? 0) <= 3)
            QuickActionChips(onTap: (topic) => _handleQuickAction(topic)),

          // Composer
          MessageComposer(
            onSendText: _handleSendText,
            onAttachmentTap: _handleAttachmentTap,
            isUploading: uploadState.isUploading,
            uploadProgress: uploadState.progress,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String? orderNumber) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: widget.showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => context.pop(),
            )
          : null,
      title: Row(
        children: [
          // Tailor avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Text(
              'KD',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kak Dah',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (orderNumber != null && orderNumber.isNotEmpty)
                  Text(
                    orderNumber,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.videocam_outlined,
            size: 22,
            color: AppColors.textSecondary,
          ),
          onPressed: () => _initiateCall(CallType.video),
        ),
        IconButton(
          icon: const Icon(
            Icons.call_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          onPressed: () => _initiateCall(CallType.voice),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.borderLight),
      ),
    );
  }

  Widget _buildMessageList(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return _buildEmptyChat();
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Messages come in newest-first from Firestore, reverse for display
    final displayMessages = messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: displayMessages.length,
      itemBuilder: (context, index) {
        final message = displayMessages[index];
        final previousMessage = index > 0 ? displayMessages[index - 1] : null;

        // Show date separator when day changes
        final showDate =
            previousMessage == null ||
            !_isSameDay(message.createdAt, previousMessage.createdAt);

        return Column(
          children: [
            if (showDate) DateSeparator(date: message.createdAt),
            MessageBubble(
              message: message,
              isSentByMe: message.isSentBy(currentUserId),
              onImageTap: () => _handleImageTap(message),
              onVideoTap: () => _handleVideoTap(message),
              onFileTap: () => _handleFileTap(message),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Start the Conversation',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask about your order, share fabric photos, or discuss design details.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textTertiary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Unable to load chat',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _initConversation,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Actions ────────────────────────────────────────────────────────────

  void _handleQuickAction(QuickActionTopic topic) {
    _handleSendText(topic.suggestedMessage);
  }

  void _initiateCall(CallType callType) {
    if (_conversationId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    CallScreen.startCall(
      context,
      callType: callType,
      conversationId: _conversationId!,
      orderId: widget.orderId,
      localUserId: user.uid,
      localUserName: user.displayName ?? 'Customer',
      remoteUserId: ChatService.tailorUid,
      remoteUserName: ChatService.tailorName,
    );
  }

  Future<void> _handleSendText(String text) async {
    if (_conversationId == null) return;
    final chatService = ref.read(chatServiceProvider);
    await chatService.sendMessage(
      conversationId: _conversationId!,
      content: text,
    );
    _scrollToBottom();
  }

  void _handleAttachmentTap() {
    AttachmentMenu.show(
      context,
      onSelected: (type) => _handleAttachmentSelected(type),
    );
  }

  Future<void> _handleAttachmentSelected(AttachmentType type) async {
    if (_conversationId == null) return;

    final uploadNotifier = ref.read(uploadStateProvider.notifier);

    switch (type) {
      case AttachmentType.camera:
        final photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
        );
        if (photo != null) {
          final file = File(photo.path);
          if (!mounted) return;
          final confirmed = await AttachmentPreview.show(
            context,
            file: file,
            type: AttachmentPreviewType.image,
          );
          if (confirmed) {
            await uploadNotifier.sendImage(
              file: file,
              conversationId: _conversationId!,
            );
            _scrollToBottom();
          }
        }
        break;

      case AttachmentType.gallery:
        final image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1920,
        );
        if (image != null) {
          final file = File(image.path);
          if (!mounted) return;
          final confirmed = await AttachmentPreview.show(
            context,
            file: file,
            type: AttachmentPreviewType.image,
          );
          if (confirmed) {
            await uploadNotifier.sendImage(
              file: file,
              conversationId: _conversationId!,
            );
            _scrollToBottom();
          }
        }
        break;

      case AttachmentType.video:
        final video = await _imagePicker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 5),
        );
        if (video != null) {
          final file = File(video.path);
          if (!mounted) return;
          final confirmed = await AttachmentPreview.show(
            context,
            file: file,
            type: AttachmentPreviewType.video,
          );
          if (confirmed) {
            await uploadNotifier.sendVideo(
              file: file,
              conversationId: _conversationId!,
            );
            _scrollToBottom();
          }
        }
        break;

      case AttachmentType.document:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx'],
          allowMultiple: false,
        );
        if (result != null && result.files.isNotEmpty) {
          final path = result.files.first.path;
          if (path == null) return;
          final file = File(path);
          if (!mounted) return;
          final confirmed = await AttachmentPreview.show(
            context,
            file: file,
            type: AttachmentPreviewType.document,
          );
          if (confirmed) {
            await uploadNotifier.sendDocument(
              file: file,
              conversationId: _conversationId!,
            );
            _scrollToBottom();
          }
        }
        break;
    }
  }

  void _handleImageTap(ChatMessage message) {
    final senderName = message.senderRole == SenderRole.tailor
        ? 'Kak Dah'
        : 'You';
    MediaPreviewScreen.open(
      context,
      imageUrl: message.content,
      senderName: senderName,
      timestamp: message.createdAt,
    );
  }

  void _handleVideoTap(ChatMessage message) {
    // Open video URL externally or with a video player
    // For now, show the URL info
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video playback coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleFileTap(ChatMessage message) {
    // Open document URL externally
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${message.metadata?.fileName ?? "document"}...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
