import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../models/user_profile.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

/// Service provider for profile Firestore operations.
final profileServiceProvider = Provider((ref) => ProfileService());

/// Stream provider for the current user's profile document.
/// Provides real-time updates whenever the Firestore document changes.
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final service = ref.watch(profileServiceProvider);
  return service.userProfileStream();
});

/// Notifier for profile update operations
final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final service = ref.watch(profileServiceProvider);
  return ProfileNotifier(service);
});

class ProfileState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const ProfileState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  ProfileState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileService _service;

  ProfileNotifier(this._service) : super(const ProfileState());

  /// Update user profile fields in Firestore
  Future<ProfileResult> updateProfile({
    required String fullName,
    String? phone,
    String? address,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );

    final result = await _service.updateProfile(
      fullName: fullName,
      phone: phone,
      address: address,
    );

    state = state.copyWith(
      isLoading: false,
      errorMessage: result.errorMessage,
      isSuccess: result.success,
    );

    return result;
  }

  void reset() {
    state = const ProfileState();
  }
}
