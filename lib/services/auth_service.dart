import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  bool _isGuest = false;
  User? _user;
  bool _signingIn = false;
  bool _isInitialized = false; // Prevents UI flash on startup

  final GoogleSignIn _googleSignIn = GoogleSignIn.standard(
    scopes: ['email', 'profile'],
  );

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isGuest => _isGuest;
  bool get isSignedIn => _user != null;
  bool get canAccessApp => _isInitialized && (_user != null || _isGuest);
  bool get signingIn => _signingIn;

  User? get user => _user;
  String? get uid => _user?.uid;
  String? get displayName => _user?.displayName ?? (isGuest ? 'Guest' : null);
  String? get email => _user?.email;

  // 1. Initialize (Call this from main.dart)
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isGuest = prefs.getBool('is_guest') ?? false;
    _isInitialized = true;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });

    notifyListeners();
  }

  // 2. Sign in as Guest
  Future<void> signInAsGuest() async {
    _isGuest = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', true);
    notifyListeners();
  }

  // 3. Sign in with Google
  Future<bool> signInWithGoogle() async {
    _signingIn = true;
    notifyListeners();
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      return true;
    } catch (e) {
      debugPrint('❌ Google sign-in failed: $e');
      return false;
    } finally {
      _signingIn = false;
      notifyListeners();
    }
  }

  // 4. Sign Out (Bulletproof - updates UI instantly)
  Future<void> signOut() async {
    debugPrint('👋 Signing out...');
    _isGuest = false;
    _user = null; // Force UI to update immediately

    // Update storage in background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('is_guest', false);
    });

    // Try firebase/google signout, but don't let errors block the UI
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    notifyListeners();
  }
}
