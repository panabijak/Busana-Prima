import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/scan_result.dart';

/// Service for persisting measurement data to Firestore.
class MeasurementFirestoreService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  MeasurementFirestoreService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  /// Save scan results atomically to the user's Firestore document.
  /// Returns true on success, throws on failure.
  Future<bool> saveMeasurements(ScanResult result) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final docRef = _firestore.collection('users').doc(user.uid);

    // Build the measurement_data map
    final measurementData = result.toFirestoreMap();

    // Atomic write - either all measurements save or none
    await docRef
        .update({'measurement_data': measurementData})
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('Save operation timed out. Please try again.');
          },
        );

    return true;
  }

  /// Check if user has existing measurement data
  Future<bool> hasMeasurementData() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;

    final data = doc.data();
    final measurements = data?['measurement_data'] as Map<String, dynamic>?;
    return measurements != null && measurements.isNotEmpty;
  }
}
