import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/measurement_profile.dart';
import '../models/scan_result.dart';
import '../services/measurement_profile_service.dart';
import '../services/size_detection_service.dart';

/// Provider for the measurement profile service
final measurementProfileServiceProvider = Provider((ref) {
  return MeasurementProfileService();
});

/// Provider for size detection service
final sizeDetectionServiceProvider = Provider((ref) {
  return SizeDetectionService();
});

/// Stream provider for all measurement profiles
final measurementProfilesStreamProvider =
    StreamProvider<List<MeasurementProfile>>((ref) {
      final service = ref.watch(measurementProfileServiceProvider);
      return service.profilesStream();
    });

/// Future provider for active profile ID
final activeProfileIdProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(measurementProfileServiceProvider);
  return service.getActiveProfileId();
});

/// Provider for profile count
final profileCountProvider = Provider<int>((ref) {
  final profiles = ref.watch(measurementProfilesStreamProvider);
  return profiles.value?.length ?? 0;
});

/// Notifier for profile operations (create, delete, set active)
final profileOperationsProvider =
    StateNotifierProvider<ProfileOperationsNotifier, ProfileOperationState>((
      ref,
    ) {
      return ProfileOperationsNotifier(
        service: ref.watch(measurementProfileServiceProvider),
        sizeDetection: ref.watch(sizeDetectionServiceProvider),
      );
    });

/// State for profile operations
class ProfileOperationState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final String? lastCreatedProfileId;

  const ProfileOperationState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.lastCreatedProfileId,
  });

  ProfileOperationState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    String? lastCreatedProfileId,
    bool clearError = false,
  }) {
    return ProfileOperationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
      lastCreatedProfileId: lastCreatedProfileId ?? this.lastCreatedProfileId,
    );
  }
}

/// Notifier managing profile CRUD operations
class ProfileOperationsNotifier extends StateNotifier<ProfileOperationState> {
  final MeasurementProfileService service;
  final SizeDetectionService sizeDetection;

  ProfileOperationsNotifier({
    required this.service,
    required this.sizeDetection,
  }) : super(const ProfileOperationState());

  /// Create a new measurement profile from scan results
  Future<bool> createProfile({
    required String profileName,
    required ScanResult scanResult,
  }) async {
    state = state.copyWith(isLoading: true, isSuccess: false, clearError: true);

    try {
      // Check profile limit (soft max 20)
      final count = await service.getProfileCount();
      if (count >= 20) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Maksimum 20 profil ukuran. Sila padam profil lama.',
        );
        return false;
      }

      final profileId = await service.createProfile(
        profileName: profileName,
        scanResult: scanResult,
      );

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        lastCreatedProfileId: profileId,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal menyimpan: ${e.toString()}',
      );
      return false;
    }
  }

  /// Delete a measurement profile
  Future<bool> deleteProfile(String profileId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await service.deleteProfile(profileId);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memadam: ${e.toString()}',
      );
      return false;
    }
  }

  /// Set active profile
  Future<void> setActiveProfile(String profileId) async {
    try {
      await service.setActiveProfile(profileId);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal menetapkan profil aktif.');
    }
  }

  /// Migrate legacy measurement data
  Future<void> migrateLegacyData() async {
    try {
      await service.migrateLegacyData();
    } catch (e) {
      // Silent fail for migration — don't block user
    }
  }

  /// Detect size from scan result
  String detectSize(ScanResult scanResult) {
    return sizeDetection.detectSize(scanResult.measurements);
  }

  /// Reset state
  void reset() {
    state = const ProfileOperationState();
  }
}
