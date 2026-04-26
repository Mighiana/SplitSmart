import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton authentication service — wraps Firebase Auth.
///
/// Supports:
///  • Google Sign-In (primary, one-tap)
///  • Email + Password (secondary)
///  • Sign out
///
/// Auth state is exposed as a [Stream] so UI can react instantly.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── Auth state ─────────────────────────────────────────────────────────

  /// Current signed-in user, or null.
  User? get currentUser => _auth.currentUser;

  /// Unique ID of the current user, or null.
  String? get uid => _auth.currentUser?.uid;

  /// True when a user is signed in.
  bool get isSignedIn => _auth.currentUser != null;

  /// Stream of auth state changes — fires on sign-in / sign-out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Display name — Firebase profile or locally stored name.
  Future<String> get displayName async {
    final fbName = _auth.currentUser?.displayName;
    if (fbName != null && fbName.isNotEmpty) return fbName;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_first_name') ?? 'User';
  }

  /// User email, or null.
  String? get email => _auth.currentUser?.email;

  /// User photo URL from Google, or null.
  String? get photoUrl => _auth.currentUser?.photoURL;

  // ─── Google Sign-In ─────────────────────────────────────────────────────

  /// Sign in with Google. Returns the [UserCredential] on success.
  /// Throws [FirebaseAuthException] or [Exception] on failure.
  Future<UserCredential> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Store the display name locally as backup
      final name = userCredential.user?.displayName;
      if (name != null && name.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_first_name', name);
      }

      debugPrint('[Auth] Google sign-in success: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      debugPrint('[Auth] Google sign-in error: $e');
      rethrow;
    }
  }

  // ─── Email + Password ───────────────────────────────────────────────────

  /// Create a new account with email and password.
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Set display name on the Firebase user profile
      await userCredential.user?.updateDisplayName(displayName);
      await userCredential.user?.reload();

      // Store locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_first_name', displayName);

      debugPrint('[Auth] Email sign-up success: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      debugPrint('[Auth] Email sign-up error: $e');
      rethrow;
    }
  }

  /// Sign in with existing email and password.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store display name locally
      final name = userCredential.user?.displayName;
      if (name != null && name.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_first_name', name);
      }

      debugPrint('[Auth] Email sign-in success: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      debugPrint('[Auth] Email sign-in error: $e');
      rethrow;
    }
  }

  /// Send password reset email.
  ///
  /// NOTE: Firebase Auth does NOT throw for non-existent emails (by design,
  /// to prevent email enumeration). The email may also land in spam/junk.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('[Auth] Password reset sent to: $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] Password reset Firebase error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[Auth] Password reset error: $e');
      rethrow;
    }
  }

  // ─── Sign out ───────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      debugPrint('[Auth] Signed out');
    } catch (e) {
      debugPrint('[Auth] Sign out error: $e');
      rethrow;
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  /// Friendly error message from FirebaseAuthException codes.
  static String friendlyError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'This email is already registered. Try signing in instead.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'network-request-failed':
          return 'No internet connection. Please check your network.';
        default:
          return error.message ?? 'An unexpected error occurred.';
      }
    }
    if (error is Exception) {
      final msg = error.toString();
      if (msg.contains('cancelled')) return 'Sign-in was cancelled.';
      return msg.replaceFirst('Exception: ', '');
    }
    return 'An unexpected error occurred.';
  }
}
