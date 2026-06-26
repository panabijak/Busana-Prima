import 'package:cloud_firestore/cloud_firestore.dart';

/// Promotional banner model for the home screen carousel.
/// Maps to Firestore `banners` collection.
class BannerItem {
  final String id;
  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? actionUrl;
  final int order;
  final bool isActive;

  const BannerItem({
    required this.id,
    required this.imageUrl,
    this.title = '',
    this.subtitle,
    this.actionUrl,
    this.order = 0,
    this.isActive = true,
  });

  factory BannerItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BannerItem(
      id: doc.id,
      imageUrl: _parseImageUrl(
        data['imageUrl'] ?? data['image_url'] ?? data['image'],
      ),
      title: _parseString(data['title'] ?? data['name']),
      subtitle: data['subtitle'] as String?,
      actionUrl: data['actionUrl'] as String? ?? data['action_url'] as String?,
      order: (data['order'] as num?)?.toInt() ?? 0,
      isActive: _parseBool(
        data['isActive'] ?? data['is_active'],
        defaultValue: true,
      ),
    );
  }

  /// Parse Rowy Image/File field: [{downloadURL: "...", name: "..."}]
  static String _parseImageUrl(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) {
      if (value.isEmpty) return '';
      final first = value.first;
      if (first is Map) {
        return (first['downloadURL'] ?? first['url'] ?? first['src'] ?? '')
            .toString();
      }
      return first.toString();
    }
    if (value is Map) {
      return (value['downloadURL'] ?? value['url'] ?? value['src'] ?? '')
          .toString();
    }
    return value.toString();
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return defaultValue;
  }
}
