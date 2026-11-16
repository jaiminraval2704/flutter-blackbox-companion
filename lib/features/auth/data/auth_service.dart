import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Manages user authentication and tier state for the Web Companion.
///
/// Supports Google Sign-in (web popup) and anonymous guest mode.
/// Tier data is read from Firebase RTDB at `users/{uid}/tier`.
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._();
  static AuthService get instance => _instance;

  AuthService._() {
    try {
      _auth.authStateChanges().listen(
        _onAuthStateChanged,
        onError: (e) {
          debugPrint('Auth state error: $e');
          _isLoading = false;
          _isGuest = true;
          notifyListeners();
        },
      );
      // Failsafe timeout: ensure isLoading is never stuck on web
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_isLoading) {
          _isLoading = false;
          _isGuest = _user == null;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Auth init error: $e');
      _isLoading = false;
      _isGuest = true;
      notifyListeners();
    }
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  String _tier = 'free';
  bool _isGuest = true;
  bool _isLoading = false;

  /// Currently signed-in Firebase user (null if guest or signed out).
  User? get user => _user;

  /// Display name for the UI.
  String get displayName =>
      _user?.displayName ?? _user?.email?.split('@').first ?? 'Guest';

  /// User's avatar URL (Google profile photo).
  String? get photoUrl => _user?.photoURL;

  /// User's email address.
  String? get email => _user?.email;

  /// Whether the user is signed in (includes anonymous/guest).
  bool get isSignedIn => _user != null || _isGuest;

  /// Whether the user is browsing as a guest (no account).
  bool get isGuest => _isGuest;

  /// Whether auth state is still being resolved.
  bool get isLoading => _isLoading;

  /// Current subscription tier: 'free', 'pro', 'team', 'enterprise'.
  String get tier => _tier;

  bool get isPro => _tier == 'pro' || _tier == 'team' || _tier == 'enterprise';
  bool get isTeam => _tier == 'team' || _tier == 'enterprise';
  bool get isEnterprise => _tier == 'enterprise';

  // ── Auth state listener ─────────────────────────────────────────────

  void _onAuthStateChanged(User? user) {
    _user = user;
    _isLoading = false;
    if (user != null) {
      _isGuest = false;
      _loadUserTier(user.uid);
    } else {
      _tier = 'free';
    }
    notifyListeners();
  }

  // ── Tier loading ────────────────────────────────────────────────────

  Future<void> _loadUserTier(String uid) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/$uid/tier')
          .get();
      if (snapshot.exists && snapshot.value is String) {
        _tier = snapshot.value as String;
      } else {
        _tier = 'free';
        // Create user record with free tier if it doesn't exist
        await FirebaseDatabase.instance.ref('users/$uid').update({
          'tier': 'free',
          'email': _user?.email,
          'displayName': _user?.displayName,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Failed to load user tier: $e');
      _tier = 'free';
    }
    notifyListeners();
  }

  // ── Sign-in methods ─────────────────────────────────────────────────

  /// Sign in with Google (web popup).
  Future<void> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');
      await _auth.signInWithPopup(provider);
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      rethrow;
    }
  }

  /// Sign in with email and password.
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // Auto-create account if user doesn't exist
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        rethrow;
      }
    }
  }

  /// Continue as guest — no Firebase account, free tier only.
  void continueAsGuest() {
    _isGuest = true;
    _user = null;
    _tier = 'free';
    _isLoading = false;
    notifyListeners();
  }

  /// Sign out and reset state.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    _user = null;
    _isGuest = false;
    _tier = 'free';
    notifyListeners();
  }
}
