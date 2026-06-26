import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_service.dart';

/// Provides the singleton AuthService instance
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Stream provider for Firebase auth state changes.
/// This powers auto-login: if a user is already signed in, the app
/// skips the login screen and goes directly to home.
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Provider for the current user's role (customer or tailor)
final userRoleProvider = FutureProvider<UserRole?>((ref) async {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) async {
      if (user == null) return null;
      final authService = ref.read(authServiceProvider);
      return authService.getUserRole();
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider to check if email is verified
final emailVerifiedProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user?.emailVerified ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Notifier for auth operations (login, register, etc.)
/// Exposes loading state and error messages to the UI.
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(ref.read(authServiceProvider));
});

/// Auth UI state
class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  AuthState copyWith({bool? isLoading, String? errorMessage, bool? isSuccess}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// State notifier that handles auth actions
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

  /// Clear any error messages
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Reset state
  void reset() {
    state = const AuthState();
  }

  /// Sign in with email/password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authService.signInWithEmail(
      email: email,
      password: password,
    );

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }

  /// Register with email/password
  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authService.registerWithEmail(
      email: email,
      password: password,
      fullName: fullName,
    );

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authService.signInWithGoogle();

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordReset({required String email}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authService.sendPasswordReset(email: email);

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }

  /// Resend email verification
  Future<bool> resendVerification() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authService.sendEmailVerification();

    if (result.success) {
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthState();
  }
}
