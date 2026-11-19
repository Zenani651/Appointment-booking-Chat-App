import 'package:chat_app/utils/roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// An error with a message that is safe to show to the user.
class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);

  @override
  String toString() => message;
}

String friendlyAuthError(String code) {
  switch (code) {
    case 'invalid-email':
      return 'That email address is not valid.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'email-already-in-use':
      return 'An account already exists for that email.';
    case 'weak-password':
      return 'That password is too weak. Use at least 8 characters.';
    case 'network-request-failed':
      return 'No internet connection. Please try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    default:
      return 'Something went wrong ($code). Please try again.';
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? getCurrentUser() => _auth.currentUser;

  /// Saves the public user info. `merge` keeps fields like lastSeen.
  Future<void> _saveUserInfo(
    User user, {
    String? displayName,
    String? role,
  }) {
    final data = <String, dynamic>{'uid': user.uid, 'email': user.email};
    if (displayName != null && displayName.trim().isNotEmpty) {
      data['displayName'] = displayName.trim();
    }
    if (role != null) data['role'] = role;
    return _firestore
        .collection('Users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      // The user document is created at sign-up, and the role must never be
      // rewritten, so signing in only authenticates.
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(friendlyAuthError(e.code));
    }
  }

  Future<UserCredential> signUpWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
    String role = UserRole.customer,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final name = displayName?.trim();
      if (name != null && name.isNotEmpty) {
        await credential.user!.updateDisplayName(name);
      }
      await _saveUserInfo(credential.user!, displayName: name, role: role);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(friendlyAuthError(e.code));
    }
  }

  /// Changes the display name everyone sees.
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser!;
    final trimmed = name.trim();
    await user.updateDisplayName(trimmed);
    await _firestore.collection('Users').doc(user.uid).set({
      'displayName': trimmed,
    }, SetOptions(merge: true));
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(friendlyAuthError(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();
}