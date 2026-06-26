import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/banner_item.dart';

/// Stream provider for active promotional banners.
/// Uses client-side filtering to avoid requiring composite indexes.
final bannersStreamProvider = StreamProvider<List<BannerItem>>((ref) {
  final firestore = FirebaseFirestore.instance;
  return firestore
      .collection('banners')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => BannerItem.fromFirestore(doc))
                .where((b) => b.isActive)
                .toList()
              ..sort((a, b) => a.order.compareTo(b.order)),
      );
});
