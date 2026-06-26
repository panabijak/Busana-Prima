import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// User roles in the Busana Prima app
enum UserRole { customer, tailor }

/// Result wrapper for auth operations
class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;

  const AuthResult({required this.success, this.errorMessage, this.user});

  factory AuthResult.ok(User user) => AuthResult(success: true, user: user);

  factory AuthResult.error(String message) =>
      AuthResult(success: false, errorMessage: message);
}

/// Firebase Authentication Service
///
/// Handles all auth operations including:
/// - Email/Password sign-in & registration
/// - Google Sign-In
/// - Email verification
/// - Password reset
/// - Auto-login (persistent session)
/// - Firestore user document creation on first sign-in
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Current authenticated user (null if not logged in)
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes (for auto-login / persistent session)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if current user's email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // ─── Email/Password Registration ───────────────────────────────────────

  /// Register a new user with email and password.
  /// Creates a Firestore document under `users/{uid}` with a locked-in customer role.
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) return AuthResult.error('Registration failed');

      // Update display name
      await user.updateDisplayName(fullName);

      // Send email verification
      await user.sendEmailVerification();

      // Create Firestore user document with customer-only role
      await _createUserDocument(
        uid: user.uid,
        email: email,
        fullName: fullName,
      );

      return AuthResult.ok(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_mapAuthError(e.code));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  // ─── Email/Password Sign-In ────────────────────────────────────────────

  /// Sign in with email and password.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) return AuthResult.error('Sign-in failed');

      return AuthResult.ok(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_mapAuthError(e.code));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  // ─── Google Sign-In ────────────────────────────────────────────────────

  /// Sign in with Google. Creates Firestore document on first sign-in.
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.error('Google sign-in was cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return AuthResult.error('Google sign-in failed');

      // Create Firestore document only on first sign-in, always as customer
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      if (isNewUser) {
        await _createUserDocument(
          uid: user.uid,
          email: user.email ?? '',
          fullName: user.displayName ?? '',
        );
      }

      return AuthResult.ok(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_mapAuthError(e.code));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  // ─── Email Verification ────────────────────────────────────────────────

  /// Resend email verification link
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return AuthResult.error('No user signed in');

      await user.sendEmailVerification();
      return AuthResult.ok(user);
    } catch (e) {
      return AuthResult.error('Failed to send verification email: $e');
    }
  }

  /// Reload user to check if email is now verified
  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // ─── Password Reset ────────────────────────────────────────────────────

  /// Send password reset email
  Future<AuthResult> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_mapAuthError(e.code));
    } catch (e) {
      return AuthResult.error('Failed to send reset email: $e');
    }
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────

  /// Sign out from Firebase and Google
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  // ─── User Role ─────────────────────────────────────────────────────────

  /// Get the current user's role from Firestore
  Future<UserRole?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    final roleStr = doc.data()?['role'] as String?;
    return roleStr == 'tailor' ? UserRole.tailor : UserRole.customer;
  }

  // ─── Private Helpers ───────────────────────────────────────────────────

  /// Create user document in Firestore on first registration/sign-in
  Future<void> _createUserDocument({
    required String uid,
    required String email,
    required String fullName,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'fullName': fullName,
      'phone': '',
      'address': '',
      'role': 'customer',
      'createdAt': FieldValue.serverTimestamp(),
      'measurement_data': {},
    });
  }

  /// Map Firebase Auth error codes to user-friendly messages
  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Authentication error: $code';
    }
  }
}
