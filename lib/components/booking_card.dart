import 'package:chat_app/utils/chat_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// An appointment request shown in the chat.
/// The sender (customer) can cancel while pending; the receiver (business)
/// can accept or decline.
class BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isCurrentUser; // true when I sent the request
  final DateTime? timestamp;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;

  const BookingCard({
    super.key,
    required this.booking,
    required this.isCurrentUser,
    this.timestamp,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final status = (booking['status'] ?? 'pending').toString();
    final service = (booking['service'] ?? '').toString();
    final note = (booking['note'] ?? '').toString();
    final ts = booking['dateTime'];
    final when = ts is Timestamp ? formatDateTimeLong(ts.toDate()) : '';

    Color statusColor;
    String statusLabel;
    if (status == 'accepted') {
      statusColor = Colors.green;
      statusLabel = 'Accepted';
    } else if (status == 'declined') {
      statusColor = Colors.red;
      statusLabel = 'Declined';
    } else if (status == 'cancelled') {
      statusColor = Colors.grey;
      statusLabel = 'Cancelled';
    } else {
      statusColor = Colors.orange;
      statusLabel = 'Pending';
    }

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 25),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.secondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_available, size: 18),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Appointment request',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                service,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(when, style: const TextStyle(fontSize: 13)),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (status == 'pending') ...[
                const SizedBox(height: 10),
                if (!isCurrentUser)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDecline,
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel request'),
                    ),
                  ),
              ],
              if (timestamp != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatTime(timestamp!),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
