import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class ProfileFailure implements Exception {
  final String message;
  ProfileFailure(this.message);

  @override
  String toString() => message;
}

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Largest photo we accept (bytes). A 256px JPEG is normally 15–40 KB.
  static const int maxBytes = 200 * 1024;

  /// Live view of one user's photo document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> photoStream(String uid) {
    return _firestore.collection('ProfilePhotos').doc(uid).snapshots();
  }

  /// Stores the (already resized) picked image as base64.
  Future<void> uploadPhoto(XFile file) async {
    final user = _auth.currentUser;
    if (user == null) throw ProfileFailure('You are not signed in.');

    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw ProfileFailure('That image is too large. Try a smaller one.');
    }

    await _firestore.collection('ProfilePhotos').doc(user.uid).set({
      'data': base64Encode(bytes),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> removePhoto() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('ProfilePhotos').doc(user.uid).delete();
  }
}
