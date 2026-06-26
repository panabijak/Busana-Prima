import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/measurement.dart';
import '../models/measurement_profile.dart';
import '../models/scan_result.dart';
import 'size_detection_service.dart';

/// Service for managing multiple measurement profiles in Firestore.
/// Uses subcollection: users/{uid}/measurement_profiles/{profileId}
class MeasurementProfileService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final SizeDetectionService _sizeDetection;

  MeasurementProfileService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    SizeDetectionService? sizeDetection,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _sizeDetection = sizeDetection ?? SizeDetectionService();

  /// Get the profiles subcollection reference for current user
  CollectionReference<Map<String, dynamic>> _profilesRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('measurement_profiles');
  }

  /// Stream all measurement profiles for current user (ordered by updated_at)
  Stream<List<MeasurementProfile>> profilesStream() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(<MeasurementProfile>[]);

      return _profilesRef(
        user.uid,
      ).orderBy('updated_at', descending: true).snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => MeasurementProfile.fromFirestore(doc))
            .toList();
      });
    });
  }

  /// Create a new measurement profile from scan results
  Future<String> createProfile({
    required String profileName,
    required ScanResult scanResult,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final trimmedName = profileName.trim();
    if (trimmedName.isEmpty) throw Exception('Profile name is required');

    // Detect size category
    final sizeCategory = _sizeDetection.detectSize(scanResult.measurements);

    // Build measurements map
    final measurementsMap = <String, dynamic>{};
    for (final m in scanResult.measurements) {
      measurementsMap[m.key] = m.toMap();
    }

    final profileData = {
      'profile_name': trimmedName,
      'size_category': sizeCategory,
      'measurements': measurementsMap,
      'scan_metadata': {
        'confidence_score': scanResult.confidenceScore,
        'scan_version': '2.0.0',
        'scanned_at': scanResult.scannedAt,
      },
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Save to subcollection
    final docRef = await _profilesRef(user.uid)
        .add(profileData)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Save timed out. Please try again.'),
        );

    // If this is the first profile, set it as active
    final profileCount = await getProfileCount();
    if (profileCount == 1) {
      await setActiveProfile(docRef.id);
    }

    return docRef.id;
  }

  /// Delete a measurement profile
  Future<void> deleteProfile(String profileId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _profilesRef(user.uid).doc(profileId).delete();

    // If deleted profile was active, switch to most recent
    final activeId = await getActiveProfileId();
    if (activeId == profileId) {
      final profiles = await _profilesRef(
        user.uid,
      ).orderBy('updated_at', descending: true).limit(1).get();

      if (profiles.docs.isNotEmpty) {
        await setActiveProfile(profiles.docs.first.id);
      } else {
        // No profiles left, clear active
        await _firestore.collection('users').doc(user.uid).update({
          'active_measurement_profile_id': FieldValue.delete(),
        });
      }
    }
  }

  /// Set the active measurement profile
  Future<void> setActiveProfile(String profileId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore.collection('users').doc(user.uid).update({
      'active_measurement_profile_id': profileId,
    });
  }

  /// Get the active profile ID
  Future<String?> getActiveProfileId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['active_measurement_profile_id'] as String?;
  }

  /// Get a single profile by ID
  Future<MeasurementProfile?> getProfile(String profileId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _profilesRef(user.uid).doc(profileId).get();
    if (!doc.exists) return null;
    return MeasurementProfile.fromFirestore(doc);
  }

  /// Get profile count
  Future<int> getProfileCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final snapshot = await _profilesRef(user.uid).get();
    return snapshot.size;
  }

  /// Check if profile name already exists
  Future<bool> profileNameExists(String name) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final snapshot = await _profilesRef(
      user.uid,
    ).where('profile_name', isEqualTo: name.trim()).limit(1).get();

    return snapshot.docs.isNotEmpty;
  }

  /// Migrate legacy measurement_data to a profile (one-time)
  Future<void> migrateLegacyData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return;

    final data = userDoc.data()!;
    final legacyData = data['measurement_data'] as Map<String, dynamic>?;

    // Skip if no legacy data or already migrated
    if (legacyData == null || legacyData.isEmpty) return;

    // Check if migration already happened (has profiles)
    final existingProfiles = await _profilesRef(user.uid).limit(1).get();
    if (existingProfiles.docs.isNotEmpty) return;

    // Extract metadata from legacy format
    final scannedAt = legacyData['scanned_at'];
    final confidenceScore =
        (legacyData['confidence_score'] as num?)?.toDouble() ?? 0.0;
    final scanVersion = legacyData['scan_version'] as String? ?? '1.0.0';

    // Extract measurements (exclude metadata keys)
    final metadataKeys = {'scanned_at', 'confidence_score', 'scan_version'};
    final measurementsMap = <String, dynamic>{};

    for (final entry in legacyData.entries) {
      if (metadataKeys.contains(entry.key)) continue;
      if (entry.value is Map<String, dynamic>) {
        measurementsMap[entry.key] = entry.value;
      }
    }

    if (measurementsMap.isEmpty) return;

    // Parse measurements for size detection
    final measurements = measurementsMap.entries
        .map((e) => Measurement.fromMap(e.key, e.value as Map<String, dynamic>))
        .toList();

    final sizeCategory = _sizeDetection.detectSize(measurements);

    // Create migrated profile
    final profileData = {
      'profile_name': 'Ukuran Utama',
      'size_category': sizeCategory,
      'measurements': measurementsMap,
      'scan_metadata': {
        'confidence_score': confidenceScore,
        'scan_version': scanVersion,
        'scanned_at': scannedAt ?? DateTime.now(),
      },
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    final docRef = await _profilesRef(user.uid).add(profileData);

    // Set as active profile
    await setActiveProfile(docRef.id);

    // Clear legacy data (optional — keep for safety)
    // await _firestore.collection('users').doc(user.uid).update({
    //   'measurement_data': FieldValue.delete(),
    // });
  }
}
