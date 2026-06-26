import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/media_service.dart';

// ─── Service Providers ────────────────────────────────────────────────────────

/// Singleton ChatService provider.
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

/// Singleton MediaService provider.
final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService();
});

// ─── Conversation Providers ───────────────────────────────────────────────────

/// Stream of all active conversations for the current user.
/// Used by the ConversationListScreen.
final userConversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.userConversationsStream();
});

/// Stream a single conversation by order ID.
/// Returns null if no conversation exists yet for that order.
final conversationByOrderProvider =
    StreamProvider.family<Conversation?, String>((ref, orderId) {
      final chatService = ref.watch(chatServiceProvider);
      return chatService.conversationByOrderStream(orderId);
    });

/// Total unread message count across all conversations.
/// Used for the badge on the bottom nav "Chat" tab.
final totalUnreadProvider = StreamProvider<int>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.totalUnreadStream();
});

// ─── Message Providers ────────────────────────────────────────────────────────

/// Stream of messages for a specific conversation (real-time, newest first).
final messagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.messagesStream(conversationId);
});

// ─── Upload State Management ──────────────────────────────────────────────────

/// State for tracking media upload progress.
class UploadState {
  final bool isUploading;
  final double progress;
  final String? error;
  final String? fileName;

  const UploadState({
    this.isUploading = false,
    this.progress = 0.0,
    this.error,
    this.fileName,
  });

  UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? error,
    String? fileName,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      error: error,
      fileName: fileName ?? this.fileName,
    );
  }
}

/// Notifier for managing media upload progress and sending media messages.
class UploadNotifier extends StateNotifier<UploadState> {
  final ChatService _chatService;
  final MediaService _mediaService;

  UploadNotifier(this._chatService, this._mediaService)
    : super(const UploadState());

  /// Upload an image and send it as a message.
  Future<void> sendImage({
    required File file,
    required String conversationId,
  }) async {
    try {
      state = state.copyWith(
        isUploading: true,
        progress: 0.0,
        fileName: file.path.split('/').last,
      );

      final result = await _mediaService.uploadImage(
        file: file,
        conversationId: conversationId,
        onProgress: (p) => state = state.copyWith(progress: p),
      );

      await _chatService.sendMessage(
        conversationId: conversationId,
        content: result.downloadUrl,
        type: MessageType.image,
        metadata: result.metadata,
      );

      state = const UploadState(); // Reset
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      debugPrint('[UploadNotifier] Image upload failed: $e');
    }
  }

  /// Upload a video and send it as a message.
  Future<void> sendVideo({
    required File file,
    required String conversationId,
  }) async {
    try {
      state = state.copyWith(
        isUploading: true,
        progress: 0.0,
        fileName: file.path.split('/').last,
      );

      final result = await _mediaService.uploadVideo(
        file: file,
        conversationId: conversationId,
        onProgress: (p) => state = state.copyWith(progress: p),
      );

      await _chatService.sendMessage(
        conversationId: conversationId,
        content: result.downloadUrl,
        type: MessageType.video,
        metadata: result.metadata,
      );

      state = const UploadState();
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      debugPrint('[UploadNotifier] Video upload failed: $e');
    }
  }

  /// Upload a document and send it as a message.
  Future<void> sendDocument({
    required File file,
    required String conversationId,
  }) async {
    try {
      state = state.copyWith(
        isUploading: true,
        progress: 0.0,
        fileName: file.path.split('/').last,
      );

      final result = await _mediaService.uploadDocument(
        file: file,
        conversationId: conversationId,
        onProgress: (p) => state = state.copyWith(progress: p),
      );

      await _chatService.sendMessage(
        conversationId: conversationId,
        content: result.downloadUrl,
        type: MessageType.file,
        metadata: result.metadata,
      );

      state = const UploadState();
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      debugPrint('[UploadNotifier] Document upload failed: $e');
    }
  }

  /// Clear any error state.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for the upload state notifier.
final uploadStateProvider = StateNotifierProvider<UploadNotifier, UploadState>((
  ref,
) {
  final chatService = ref.watch(chatServiceProvider);
  final mediaService = ref.watch(mediaServiceProvider);
  return UploadNotifier(chatService, mediaService);
});
