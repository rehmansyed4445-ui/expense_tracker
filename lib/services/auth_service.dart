import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  bool _isGuest = false;
  bool _isInitialized = false;
  bool _signingIn = false;
  bool _justSignedIn = false;
  String? _signInError;
  User? _user;

  final GoogleSignIn _googleSignIn = GoogleSignIn.standard(
    scopes: ['email', 'profile'],
  );

  bool get isInitialized => _isInitialized;
  bool get isGuest => _isGuest;
  bool get isSignedIn => _user != null;
  bool get canAccessApp => _isInitialized && (_user != null || _isGuest);
  bool get signingIn => _signingIn;
  bool get justSignedIn => _justSignedIn;
  String? get signInError => _signInError;

  User? get user => _user;
  String? get uid => _user?.uid;
  String? get displayName => _user?.displayName ?? (isGuest ? 'Guest' : null);
  String? get email => _user?.email;

  void consumeJustSignedIn() => _justSignedIn = false;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isGuest = prefs.getBool('is_guest') ?? false;
    _user = FirebaseAuth.instance.currentUser;
    _isInitialized = true;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });

    notifyListeners();
  }

  Future<void> signInAsGuest() async {
    _isGuest = true;
    _signInError = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', true);
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _signingIn = true;
    _signInError = null;
    notifyListeners();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;

      final tokens = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      _isGuest = false;
      _justSignedIn = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', false);
      return true;
    } catch (e) {
      _signInError = '$e';
      debugPrint('❌ Google sign-in failed: $e');
      return false;
    } finally {
      _signingIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isGuest = false;
    _user = null;
    _justSignedIn = false;
    _signInError = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', false);

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    notifyListeners();
  }
}
