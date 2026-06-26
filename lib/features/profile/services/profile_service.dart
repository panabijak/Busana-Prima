import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/user_profile.dart';

class ProfileService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  ProfileService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<UserProfile?> userProfileStream() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(null);
      }

      return _firestore.collection('users').doc(user.uid).snapshots().map((
        snapshot,
      ) {
        if (!snapshot.exists) return null;
        return UserProfile.fromFirestore(snapshot);
      });
    });
  }

  Future<UserProfile?> getCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    if (!snapshot.exists) return null;
    return UserProfile.fromFirestore(snapshot);
  }

  Future<ProfileResult> updateProfile({
    required String fullName,
    String? phone,
    String? address,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ProfileResult.error('Not signed in');
      }

      final updates = <String, dynamic>{'fullName': fullName.trim()};
      if (phone != null) updates['phone'] = phone.trim();
      if (address != null) updates['address'] = address.trim();

      await _firestore.collection('users').doc(user.uid).update(updates);

      if (user.displayName != fullName.trim()) {
        await user.updateDisplayName(fullName.trim());
      }

      return ProfileResult.ok();
    } on FirebaseException catch (e) {
      return ProfileResult.error('Failed to update profile: ${e.message}');
    } catch (e) {
      return ProfileResult.error('An unexpected error occurred: $e');
    }
  }

  /// Upload profile photo to Firebase Storage and update Firestore.
  /// Path: profile_photos/{uid}.jpg
  Future<ProfileResult> uploadProfilePhoto(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return ProfileResult.error('Not signed in');

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');

      // Upload file
      await storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': downloadUrl,
      });

      // Also update Firebase Auth photoURL
      await user.updatePhotoURL(downloadUrl);

      return ProfileResult.ok();
    } on FirebaseException catch (e) {
      return ProfileResult.error('Failed to upload photo: ${e.message}');
    } catch (e) {
      return ProfileResult.error('An unexpected error occurred: $e');
    }
  }

  /// Remove profile photo.
  Future<ProfileResult> removeProfilePhoto() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return ProfileResult.error('Not signed in');

      // Delete from storage (ignore if not found)
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_photos')
            .child('${user.uid}.jpg');
        await storageRef.delete();
      } catch (_) {}

      // Clear from Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': FieldValue.delete(),
      });

      await user.updatePhotoURL(null);

      return ProfileResult.ok();
    } on FirebaseException catch (e) {
      return ProfileResult.error('Failed to remove photo: ${e.message}');
    } catch (e) {
      return ProfileResult.error('An unexpected error occurred: $e');
    }
  }
}
