import 'package:cloud_firestore/cloud_firestore.dart';

/// Taken slots live at BusinessSlots/{businessId}/booked/{slotId}.
class SlotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// IDs of the slots already booked on [day].
  Stream<Set<String>> bookedSlotIds(String businessId, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    return _firestore
        .collection('BusinessSlots')
        .doc(businessId)
        .collection('booked')
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('start', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.id).toSet());
  }
}
