import 'package:cloud_firestore/cloud_firestore.dart';

/// User profile data model for the Customer app.
/// The app is locked to customer accounts, but the role field is preserved
/// so a separate Tailor app can still connect to the same Firebase project.
class UserProfile {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String? photoUrl;
  final String role;
  final Map<String, dynamic> measurementData;
  final DateTime? createdAt;

  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.address = '',
    this.photoUrl,
    this.role = 'customer',
    this.measurementData = const {},
    this.createdAt,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  bool get isCustomer => role == 'customer';

  /// This getter remains for compatibility with shared project data.
  bool get isTailor => role == 'tailor';

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile(
      uid: doc.id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      role: data['role'] as String? ?? 'customer',
      measurementData: data['measurement_data'] as Map<String, dynamic>? ?? {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toUpdateMap({
    String? fullName,
    String? phone,
    String? address,
  }) {
    final map = <String, dynamic>{};
    if (fullName != null) map['fullName'] = fullName.trim();
    if (phone != null) map['phone'] = phone.trim();
    if (address != null) map['address'] = address.trim();
    return map;
  }
}

class ProfileResult {
  final bool success;
  final String? errorMessage;

  const ProfileResult({required this.success, this.errorMessage});

  factory ProfileResult.ok() => const ProfileResult(success: true);
  factory ProfileResult.error(String msg) =>
      ProfileResult(success: false, errorMessage: msg);
}
