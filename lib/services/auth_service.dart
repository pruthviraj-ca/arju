/// auth_service.dart
///
/// Centralized Firebase Authentication service for the TruAssets CRM.
/// Provides a singleton interface for sign-in, sign-out, and auth state
/// observation. Includes an allow-list check for authorized email addresses.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service that wraps [FirebaseAuth] with a clean API
/// for authentication operations throughout the app.
class AuthService {
  AuthService._() {
    _auth.authStateChanges().listen((User? user) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (user != null) {
          await prefs.setString('auth_login_type', 'firebase');
        } else {
          if (!isDemoMode.value) {
            await prefs.setString('auth_login_type', '');
          }
        }
      } catch (e) {
        debugPrint('Error in authStateChanges listener: $e');
      }
    });
  }

  /// Global singleton instance.
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ValueNotifier to enable offline Demo Mode without network requests.
  static final ValueNotifier<bool> isDemoMode = ValueNotifier(false);

  // ─── Allow-listed Emails ──────────────────────────────────────────────────

  /// Emails authorized to sign in to this application.
  static const List<String> _allowedEmails = [
    'pruthviraj.in.in@gmail.com',
    'arjunckbng@aol.com',
    'pruthvi.in.in@gmail.com',
  ];

  // ─── Auth State Accessors ─────────────────────────────────────────────────

  /// The currently signed-in user, or `null` if unauthenticated.
  User? get currentUser {
    if (isDemoMode.value) {
      return _mockUser;
    }
    return _auth.currentUser;
  }

  /// Reactive stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Whether a user is currently signed in.
  bool get isSignedIn => isDemoMode.value || _auth.currentUser != null;

  static final MockUser _mockUser = MockUser();


  // ─── Authentication Actions ───────────────────────────────────────────────

  /// Signs in a user with [email] and [password].
  ///
  /// Validates the email against the allow-list before attempting Firebase
  /// authentication. Returns the signed-in [User] on success.
  ///
  /// Throws [FirebaseAuthException] if the email is not authorized or
  /// if Firebase authentication fails.
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (!_allowedEmails.contains(trimmedEmail)) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Invalid email: This email address is not registered or authorized.',
      );
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  /// Loads the persisted login state from SharedPreferences on app startup.
  Future<void> initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final type = prefs.getString('auth_login_type') ?? '';
      if (type == 'demo') {
        isDemoMode.value = true;
      } else {
        isDemoMode.value = false;
      }
    } catch (e) {
      debugPrint('Error initializing auth state: $e');
    }
  }

  /// Sets whether the app is in offline Demo Mode, persisting the preference.
  Future<void> setDemoMode(bool enabled) async {
    isDemoMode.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (enabled) {
        await prefs.setString('auth_login_type', 'demo');
      } else {
        await prefs.setString('auth_login_type', '');
      }
    } catch (e) {
      debugPrint('Error setting demo mode: $e');
    }
  }

  /// Signs out the currently authenticated user.
  Future<void> signOut() async {
    await setDemoMode(false);
    await _auth.signOut();
  }

  // ─── Error Handling ───────────────────────────────────────────────────────

  /// Converts a [FirebaseAuthException] into a user-friendly error message.
  ///
  /// [e] - The Firebase authentication exception to translate.
  /// Returns a localized, human-readable error string.
  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address';
      case 'wrong-password':
        return 'Incorrect password. Please try again';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'user-disabled':
        return 'This account has been disabled. Contact support';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again';
      case 'invalid-credential':
        return 'Invalid email or password. Please check and try again';
      case 'network-request-failed':
        return 'Network error. Check your internet connection';
      default:
        return 'Sign in failed. Please try again';
    }
  }
}

class MockUser implements User {
  @override
  String get uid => 'demo_uid';

  @override
  String? get email => 'demo@truassets.in';

  String _displayName = 'Rahul Sharma';

  @override
  String? get displayName => _displayName;

  @override
  Future<void> updateDisplayName(String? name) async {
    _displayName = name ?? 'Rahul Sharma';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

