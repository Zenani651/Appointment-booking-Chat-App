import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BusinessProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('BusinessProfiles').doc(uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> profileStream(String uid) {
    return _doc(uid).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getProfile(String uid) {
    return _doc(uid).get();
  }

  /// Saves the signed-in business's own details.
  /// [opensAt] / [closesAt] are "HH:mm" strings, or '' when not set.
  /// [slotMinutes] is the length of one appointment slot.
  Future<void> saveMyProfile({
    required String description,
    required String hours,
    required String phone,
    required String address,
    String announcement = '',
    String opensAt = '',
    String closesAt = '',
    int slotMinutes = 60,
  }) async {
    final me = _auth.currentUser;
    if (me == null) return;

    await _doc(me.uid).set({
      'description': description.trim(),
      'hours': hours.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'announcement': announcement.trim(),
      'opensAt': opensAt,
      'closesAt': closesAt,
      'slotMinutes': slotMinutes,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }
}
