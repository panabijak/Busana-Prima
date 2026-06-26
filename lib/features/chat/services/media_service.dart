import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Service for uploading and managing chat media files.
///
/// Storage structure:
///   chat-media/{conversationId}/images/{timestamp}_{uuid}.{ext}
///   chat-media/{conversationId}/videos/{timestamp}_{uuid}.mp4
///   chat-media/{conversationId}/files/{timestamp}_{uuid}_{filename}
class MediaService {
  final FirebaseStorage _storage;

  MediaService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  /// Maximum file sizes (in bytes)
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxVideoSize = 50 * 1024 * 1024; // 50MB
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB

  /// Compression settings
  static const int maxImageWidth = 1080;
  static const int imageQuality = 80;

  // ─── Upload Methods ─────────────────────────────────────────────────────

  /// Upload an image file. Compresses before upload.
  /// Returns the download URL and metadata.
  Future<MediaUploadResult> uploadImage({
    required File file,
    required String conversationId,
    void Function(double progress)? onProgress,
  }) async {
    // Compress the image
    final compressed = await _compressImage(file);
    final fileToUpload = compressed ?? file;

    final fileName = _generateFileName('images', _getExtension(file.path));
    final ref = _storage.ref('chat-media/$conversationId/$fileName');

    final metadata = SettableMetadata(
      contentType: _getMimeType(file.path),
      customMetadata: {'originalName': file.path.split('/').last},
    );

    final uploadTask = ref.putFile(fileToUpload, metadata);

    // Track progress
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();
    final fileSize = await fileToUpload.length();

    debugPrint('[MediaService] Image uploaded: $fileName ($fileSize bytes)');

    return MediaUploadResult(
      downloadUrl: downloadUrl,
      metadata: MessageMetadata(
        fileName: file.path.split('/').last,
        fileSize: fileSize,
        mimeType: _getMimeType(file.path),
      ),
    );
  }

  /// Upload a video file.
  /// Returns the download URL and metadata.
  Future<MediaUploadResult> uploadVideo({
    required File file,
    required String conversationId,
    void Function(double progress)? onProgress,
  }) async {
    final fileSize = await file.length();
    if (fileSize > maxVideoSize) {
      throw Exception('Video file is too large (max 50MB)');
    }

    final fileName = _generateFileName('videos', 'mp4');
    final ref = _storage.ref('chat-media/$conversationId/$fileName');

    final metadata = SettableMetadata(
      contentType: 'video/mp4',
      customMetadata: {'originalName': file.path.split('/').last},
    );

    final uploadTask = ref.putFile(file, metadata);

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    debugPrint('[MediaService] Video uploaded: $fileName ($fileSize bytes)');

    return MediaUploadResult(
      downloadUrl: downloadUrl,
      metadata: MessageMetadata(
        fileName: file.path.split('/').last,
        fileSize: fileSize,
        mimeType: 'video/mp4',
      ),
    );
  }

  /// Upload a document file (PDF, DOC, DOCX).
  /// Returns the download URL and metadata.
  Future<MediaUploadResult> uploadDocument({
    required File file,
    required String conversationId,
    void Function(double progress)? onProgress,
  }) async {
    final fileSize = await file.length();
    if (fileSize > maxFileSize) {
      throw Exception('File is too large (max 10MB)');
    }

    final originalName = file.path.split('/').last;
    final ext = _getExtension(file.path);
    final fileName = _generateFileName('files', ext, suffix: originalName);
    final ref = _storage.ref('chat-media/$conversationId/$fileName');

    final metadata = SettableMetadata(
      contentType: _getMimeType(file.path),
      customMetadata: {'originalName': originalName},
    );

    final uploadTask = ref.putFile(file, metadata);

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    debugPrint('[MediaService] Document uploaded: $fileName ($fileSize bytes)');

    return MediaUploadResult(
      downloadUrl: downloadUrl,
      metadata: MessageMetadata(
        fileName: originalName,
        fileSize: fileSize,
        mimeType: _getMimeType(file.path),
      ),
    );
  }

  // ─── Image Compression ──────────────────────────────────────────────────

  /// Compress an image to max 1080px width, 80% quality.
  /// Returns null if compression fails (original will be used).
  Future<File?> _compressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Only compress if image is larger than target
      if (image.width <= maxImageWidth) return null;

      // Resize proportionally
      final resized = img.copyResize(image, width: maxImageWidth);

      // Encode as JPEG with quality
      final compressed = img.encodeJpg(resized, quality: imageQuality);

      // Write to temp file
      final tempDir = await getTemporaryDirectory();
      final uuid = const Uuid().v4();
      final tempFile = File('${tempDir.path}/compressed_$uuid.jpg');
      await tempFile.writeAsBytes(compressed);

      debugPrint(
        '[MediaService] Image compressed: ${bytes.length} → ${compressed.length} bytes',
      );

      return tempFile;
    } catch (e) {
      debugPrint('[MediaService] Compression failed: $e');
      return null;
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  String _generateFileName(String folder, String ext, {String? suffix}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuid = const Uuid().v4().substring(0, 8);
    if (suffix != null) {
      return '$folder/${timestamp}_${uuid}_$suffix';
    }
    return '$folder/${timestamp}_$uuid.$ext';
  }

  String _getExtension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'bin';
  }

  String _getMimeType(String path) {
    final ext = _getExtension(path);
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  /// Determine MessageType from file MIME type.
  static MessageType messageTypeFromMime(String mimeType) {
    if (mimeType.startsWith('image/')) return MessageType.image;
    if (mimeType.startsWith('video/')) return MessageType.video;
    return MessageType.file;
  }
}

/// Result of a media upload operation.
class MediaUploadResult {
  final String downloadUrl;
  final MessageMetadata metadata;

  const MediaUploadResult({required this.downloadUrl, required this.metadata});
}
