import 'dart:async';

import 'package:chat_app/components/booking_card.dart';
import 'package:chat_app/components/booking_sheet.dart';
import 'package:chat_app/components/chat_bubble.dart';
import 'package:chat_app/components/day_separator.dart';
import 'package:chat_app/components/my_textfields.dart';
import 'package:chat_app/components/user_avatar.dart';
import 'package:chat_app/services/auth/auth.dart';
import 'package:chat_app/services/chat/chat_service.dart';
import 'package:chat_app/services/presence/presence_service.dart';
import 'package:chat_app/utils/chat_utils.dart';
import 'package:chat_app/utils/roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// The message currently being replied to.
class _ReplyDraft {
  final String id;
  final String text;
  final String senderID;
  const _ReplyDraft({
    required this.id,
    required this.text,
    required this.senderID,
  });
}

class ChatPage extends StatefulWidget {
  final String receiverName;
  final String receiverID;

  const ChatPage({
    super.key,
    required this.receiverName,
    required this.receiverID,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  int _lastMessageCount = 0;
  bool _isSending = false;

  Timer? _typingTimer;
  bool _isTyping = false;

  _ReplyDraft? _replyingTo;

  @override
  void initState() {
    super.initState();
    _chatService.markAsRead(widget.receiverID);
  }

  @override
  void dispose() {
    _stopTyping();
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- typing indicator -------------------------------------------------

  void _onTextChanged(String text) {
    if (text.trim().isEmpty) {
      _stopTyping();
      return;
    }
    if (!_isTyping) {
      _isTyping = true;
      _chatService.setTyping(widget.receiverID, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    if (_isTyping) {
      _isTyping = false;
      _chatService.setTyping(widget.receiverID, false);
    }
  }

  // ---- sending / replying / deleting -----------------------------------

  /// The list is reversed, so offset 0 is the newest message.
  void _scrollToLatest() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final reply = _replyingTo;
    Map<String, dynamic>? replyTo;
    if (reply != null) {
      replyTo = {
        'id': reply.id,
        'senderID': reply.senderID,
        'message':
            reply.text.length > 100
                ? '${reply.text.substring(0, 100)}…'
                : reply.text,
      };
    }

    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(widget.receiverID, text, replyTo: replyTo);
      _messageController.clear();
      _stopTyping();
      if (mounted) setState(() => _replyingTo = null);
      _scrollToLatest();
    } catch (_) {
      _toast('Message failed to send. Try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Long-press a message: Reply (anyone's) or Delete (your own).
  void _showMessageOptions({
    required String id,
    required Map<String, dynamic> data,
    required bool isCurrentUser,
  }) {
    showModalBottomSheet(
      context: context,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() {
                      _replyingTo = _ReplyDraft(
                        id: id,
                        text: (data['message'] ?? '').toString(),
                        senderID: (data['senderID'] ?? '').toString(),
                      );
                    });
                    _inputFocus.requestFocus();
                  },
                ),
                if (isCurrentUser)
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Delete'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _confirmDelete(id);
                    },
                  ),
              ],
            ),
          ),
    );
  }

  Future<void> _confirmDelete(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete message?'),
            content: const Text('This removes the message for both of you.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      try {
        await _chatService.deleteMessage(widget.receiverID, messageId);
      } catch (_) {
        _toast('Could not delete the message.');
      }
    }
  }

  // ---- appointments -----------------------------------------------------

  Future<void> _openBookingSheet() async {
    final draft = await showBookingSheet(
      context,
      businessID: widget.receiverID,
    );
    if (draft == null) return;

    try {
      await _chatService.sendBookingRequest(
        widget.receiverID,
        service: draft.service,
        dateTime: draft.dateTime,
        note: draft.note,
      );
      _scrollToLatest();
    } catch (_) {
      _toast('Could not book that slot. It may have just been taken.');
    }
  }

  /// Accept / decline (business) or cancel (customer), then tell the other
  /// side with a normal chat message so they get a notification badge.
  Future<void> _respondToBooking(
    String messageId,
    Map<String, dynamic> booking,
    String status,
  ) async {
    try {
      await _chatService.updateBookingStatus(
        widget.receiverID,
        messageId,
        status,
      );

      final ts = booking['dateTime'];
      final when = ts is Timestamp ? formatDateTimeLong(ts.toDate()) : '';
      final label =
          status == 'accepted'
              ? 'Appointment accepted ✅'
              : status == 'declined'
              ? 'Appointment declined ❌'
              : 'Appointment cancelled';
      await _chatService.sendMessage(
        widget.receiverID,
        '$label: ${booking['service']} · $when',
      );
    } catch (_) {
      _toast('Could not update the appointment.');
    }
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
        actions: [
          // Only shown when chatting with a business.
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _chatService.getUserStream(widget.receiverID),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              if (data == null || !isBusinessUser(data)) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.event_available),
                tooltip: 'Request appointment',
                onPressed: _openBookingSheet,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [Expanded(child: _buildMessagesList()), _buildUserInput()],
      ),
    );
  }

  /// Avatar + name + "typing…" / "Online" / "last seen …".
  Widget _buildTitle() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _chatService.getUserStream(widget.receiverID),
      builder: (context, userSnap) {
        final user = userSnap.data?.data();
        final name = user != null ? displayNameOf(user) : widget.receiverName;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _chatService.getChatRoomStream(widget.receiverID),
          builder: (context, roomSnap) {
            final typingMap = roomSnap.data?.data()?['typing'];
            final isTyping =
                typingMap is Map && typingMap[widget.receiverID] == true;

            String status = '';
            if (isTyping) {
              status = 'typing…';
            } else if (user != null) {
              if (isUserOnline(user)) {
                status = 'Online';
              } else {
                final seen = lastSeenOf(user);
                if (seen != null) status = lastSeenLabel(seen);
              }
            }

            return Row(
              children: [
                UserAvatar(uid: widget.receiverID, name: name, radius: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, overflow: TextOverflow.ellipsis),
                      if (status.isNotEmpty)
                        Text(
                          status,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMessagesList() {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) return const SizedBox.shrink();
    final myId = currentUser.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _chatService.getMessages(myId, widget.receiverID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load messages.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(child: Text('Say hi to ${widget.receiverName} 👋'));
        }

        // New incoming message while the chat is open: mark it as read.
        if (docs.length > _lastMessageCount) {
          final lastSender = docs.last.data()['senderID'];
          if (lastSender != myId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _chatService.markAsRead(widget.receiverID);
            });
          }
        }
        _lastMessageCount = docs.length;

        // Oldest -> newest with a separator when the day changes, then
        // reversed so the list is anchored to the bottom.
        final items = <Widget>[];
        DateTime? previousDay;
        for (final doc in docs) {
          final data = doc.data();
          final ts = data['timestamp'];
          final date = ts is Timestamp ? ts.toDate() : DateTime.now();

          if (previousDay == null || !isSameDay(previousDay, date)) {
            items.add(DaySeparator(date: date));
            previousDay = date;
          }
          items.add(_buildMessageItem(doc.id, data, date, myId));
        }

        return ListView(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: items.reversed.toList(),
        );
      },
    );
  }

  Widget _buildMessageItem(
    String id,
    Map<String, dynamic> data,
    DateTime date,
    String myId,
  ) {
    final isCurrentUser = data['senderID'] == myId;

    // Appointment requests are shown as a card with Accept/Decline/Cancel.
    if (data['type'] == 'booking' && data['booking'] is Map) {
      final booking = Map<String, dynamic>.from(data['booking'] as Map);
      return BookingCard(
        booking: booking,
        isCurrentUser: isCurrentUser,
        timestamp: date,
        onAccept: () => _respondToBooking(id, booking, 'accepted'),
        onDecline: () => _respondToBooking(id, booking, 'declined'),
        onCancel: () => _respondToBooking(id, booking, 'cancelled'),
      );
    }

    String? replyText;
    String? replyAuthor;
    final reply = data['replyTo'];
    if (reply is Map) {
      replyText = reply['message']?.toString();
      replyAuthor = reply['senderID'] == myId ? 'You' : widget.receiverName;
    }

    return ChatBubble(
      message: data['message'] ?? '',
      isCurrentUser: isCurrentUser,
      timestamp: date,
      replyText: replyText,
      replyAuthor: replyAuthor,
      onLongPress:
          () => _showMessageOptions(
            id: id,
            data: data,
            isCurrentUser: isCurrentUser,
          ),
    );
  }

  /// The "Replying to …" banner above the input box.
  Widget _buildReplyBanner() {
    final reply = _replyingTo!;
    final scheme = Theme.of(context).colorScheme;
    final myId = _authService.getCurrentUser()?.uid;
    final author = reply.senderID == myId ? 'You' : widget.receiverName;

    return Container(
      margin: const EdgeInsets.fromLTRB(25, 0, 25, 6),
      decoration: BoxDecoration(
        color: scheme.secondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: Colors.green),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Replying to $author',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        reply.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _replyingTo = null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null) _buildReplyBanner(),
            Row(
              children: [
                Expanded(
                  child: MyTextfields(
                    controller: _messageController,
                    focusNode: _inputFocus,
                    hintText: 'Type your message',
                    obscureText: false,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    onChanged: _onTextChanged,
                    maxLength: 2000,
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  margin: const EdgeInsets.only(right: 25),
                  child: IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: const Icon(Icons.arrow_upward, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
