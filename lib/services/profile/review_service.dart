import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Reviews live at BusinessReviews/{businessId}/reviews/{customerId},
/// so each customer has at most one review per business.
class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _col(String businessId) =>
      _firestore
          .collection('BusinessReviews')
          .doc(businessId)
          .collection('reviews');

  /// Latest reviews first.
  Stream<QuerySnapshot<Map<String, dynamic>>> reviewsStream(String businessId) {
    return _col(
      businessId,
    ).orderBy('updatedAt', descending: true).limit(50).snapshots();
  }

  /// Creates or replaces the signed-in customer's review.
  Future<void> saveReview(
    String businessId, {
    required int rating,
    required String comment,
  }) async {
    final me = _auth.currentUser;
    if (me == null) return;

    var name = (me.displayName ?? '').trim();
    if (name.isEmpty) name = 'Customer';
    if (name.length > 30) name = name.substring(0, 30);

    await _col(businessId).doc(me.uid).set({
      'rating': rating,
      'comment': comment.trim(),
      'reviewerID': me.uid,
      'reviewerName': name,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteMyReview(String businessId) async {
    final me = _auth.currentUser;
    if (me == null) return;
    await _col(businessId).doc(me.uid).delete();
  }
}
