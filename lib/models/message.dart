import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderID;
  final String senderEmail;
  final String receiverID;
  final String message;
  final DateTime timestamp;

  /// Snapshot of the message being replied to: {id, message, senderID}.
  final Map<String, dynamic>? replyTo;

  /// 'text' (default) or 'booking'.
  final String type;

  /// For booking messages: {service, dateTime, note, status}.
  final Map<String, dynamic>? booking;

  Message({
    required this.senderID,
    required this.senderEmail,
    required this.receiverID,
    required this.message,
    required this.timestamp,
    this.replyTo,
    this.type = 'text',
    this.booking,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderID': senderID,
      'senderEmail': senderEmail,
      'receiverID': receiverID,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      if (replyTo != null) 'replyTo': replyTo,
      if (booking != null) 'booking': booking,
    };
  }
}
