import 'package:chat_app/models/message.dart';
import 'package:chat_app/utils/chat_utils.dart';
import 'package:chat_app/utils/slots.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _roomRef(String roomId) =>
      _firestore.collection('chat_rooms').doc(roomId);

  /// The "this time is taken" record for one business and start time.
  DocumentReference<Map<String, dynamic>> _slotRef(
    String businessId,
    DateTime start,
  ) => _firestore
      .collection('BusinessSlots')
      .doc(businessId)
      .collection('booked')
      .doc(slotId(start));

  /// Stream of all users.
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection('Users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        user['uid'] = user['uid'] ?? doc.id;
        return user;
      }).toList();
    });
  }

  /// Sends a text message.
  Future<void> sendMessage(
    String receiverID,
    String text, {
    Map<String, dynamic>? replyTo,
  }) {
    return _send(receiverID, text, replyTo: replyTo);
  }

  /// Sends an appointment request and reserves the slot in the same atomic
  /// write. If someone else already took the slot, the whole write fails.
  Future<void> sendBookingRequest(
    String receiverID, {
    required String service,
    required DateTime dateTime,
    String note = '',
  }) {
    final me = _auth.currentUser!.uid;
    final summary =
        'Appointment request: ${service.trim()} · ${formatDateTimeLong(dateTime)}';

    return _send(
      receiverID,
      summary,
      type: 'booking',
      booking: {
        'service': service.trim(),
        'dateTime': Timestamp.fromDate(dateTime),
        'note': note.trim(),
        'status': 'pending',
      },
      alsoWrite: (batch) {
        batch.set(_slotRef(receiverID, dateTime), {
          'customerID': me,
          'start': Timestamp.fromDate(dateTime),
          'createdAt': Timestamp.now(),
        });
      },
    );
  }

  /// Changes a booking's status: accepted / declined (by the business) or
  /// cancelled (by the customer). Declining or cancelling frees the slot.
  Future<void> updateBookingStatus(
    String otherUserID,
    String messageId,
    String status,
  ) async {
    final me = _auth.currentUser!.uid;
    final messageRef = _roomRef(
      chatRoomId(me, otherUserID),
    ).collection('messages').doc(messageId);

    final batch = _firestore.batch();
    batch.update(messageRef, {'booking.status': status});

    if (status == 'declined' || status == 'cancelled') {
      final snap = await messageRef.get();
      final booking = snap.data()?['booking'];
      final ts = booking is Map ? booking['dateTime'] : null;
      if (ts is Timestamp) {
        // The business is me when declining, the other person when cancelling.
        final businessId = status == 'declined' ? me : otherUserID;
        final slotRef = _slotRef(businessId, ts.toDate());
        // Older bookings may have no slot record, so only delete if it exists.
        if ((await slotRef.get()).exists) batch.delete(slotRef);
      }
    }

    await batch.commit();
  }

  /// Writes the message and updates the chat room summary
  /// (last message + unread counter) in one atomic batch.
  Future<void> _send(
    String receiverID,
    String text, {
    Map<String, dynamic>? replyTo,
    String type = 'text',
    Map<String, dynamic>? booking,
    void Function(WriteBatch batch)? alsoWrite,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final me = _auth.currentUser!;
    final now = DateTime.now();
    final roomId = chatRoomId(me.uid, receiverID);
    final roomRef = _roomRef(roomId);
    final messageRef = roomRef.collection('messages').doc();

    final newMessage = Message(
      senderID: me.uid,
      senderEmail: me.email ?? '',
      receiverID: receiverID,
      message: trimmed,
      timestamp: now,
      replyTo: replyTo,
      type: type,
      booking: booking,
    );

    final batch = _firestore.batch();
    batch.set(messageRef, newMessage.toMap());
    batch.set(roomRef, {
      'participants': [me.uid, receiverID],
      'lastMessage': trimmed,
      'lastSenderID': me.uid,
      'lastTimestamp': Timestamp.fromDate(now),
      'unreadCount': {receiverID: FieldValue.increment(1), me.uid: 0},
    }, SetOptions(merge: true));
    alsoWrite?.call(batch);
    await batch.commit();
  }

  /// Messages between two users, oldest first.
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(
    String userID,
    String otherUserID,
  ) {
    return _roomRef(chatRoomId(userID, otherUserID))
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Deletes one of the current user's own messages.
  Future<void> deleteMessage(String otherUserID, String messageId) {
    final me = _auth.currentUser!.uid;
    return _roomRef(
      chatRoomId(me, otherUserID),
    ).collection('messages').doc(messageId).delete();
  }

  /// Chat room summary (last message, unread counts) for the home list.
  Stream<DocumentSnapshot<Map<String, dynamic>>> getChatRoomStream(
    String otherUserID,
  ) {
    final me = _auth.currentUser!.uid;
    return _roomRef(chatRoomId(me, otherUserID)).snapshots();
  }

  /// Resets the current user's unread counter for this chat.
  Future<void> markAsRead(String otherUserID) {
    final me = _auth.currentUser!.uid;
    return _roomRef(chatRoomId(me, otherUserID)).set({
      'unreadCount': {me: 0},
    }, SetOptions(merge: true));
  }

  /// Live view of one user's profile (name, online status, last seen).
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserStream(String uid) {
    return _firestore.collection('Users').doc(uid).snapshots();
  }

  /// Tells the other user whether the current user is typing in this chat.
  Future<void> setTyping(String otherUserID, bool isTyping) async {
    final me = _auth.currentUser;
    if (me == null) return;
    try {
      await _roomRef(chatRoomId(me.uid, otherUserID)).set({
        'typing': {me.uid: isTyping},
      }, SetOptions(merge: true));
    } catch (_) {
      // Typing status is best-effort; never block the chat on it.
    }
  }
}
