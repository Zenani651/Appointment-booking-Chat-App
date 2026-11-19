import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Writes online status + last seen to the current user's doc.
class PresenceService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> setOnline() => _write(true);
  Future<void> setOffline() => _write(false);

  Future<void> _write(bool online) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('Users').doc(user.uid).set({
        'isOnline': online,
        'lastSeen': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Presence is best-effort.
    }
  }
}

/// A user counts as online if flagged online AND seen in the last 2 minutes.
/// The time check covers apps that were killed without going offline.
bool isUserOnline(Map<String, dynamic> user, {DateTime? now}) {
  final ts = user['lastSeen'];
  if (user['isOnline'] != true || ts is! Timestamp) return false;
  final current = now ?? DateTime.now();
  return current.difference(ts.toDate()).inMinutes < 2;
}

DateTime? lastSeenOf(Map<String, dynamic> user) {
  final ts = user['lastSeen'];
  return ts is Timestamp ? ts.toDate() : null;
}

/// Wrap the signed-in UI with this. It marks the user online while the app is
/// open (with a 60 s heartbeat) and offline when it goes to the background.
class PresenceWatcher extends StatefulWidget {
  final Widget child;
  const PresenceWatcher({super.key, required this.child});

  @override
  State<PresenceWatcher> createState() => _PresenceWatcherState();
}

class _PresenceWatcherState extends State<PresenceWatcher>
    with WidgetsBindingObserver {
  final PresenceService _presence = PresenceService();
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _goOnline();
  }

  void _goOnline() {
    _presence.setOnline();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _presence.setOnline(),
    );
  }

  void _goOffline() {
    _heartbeat?.cancel();
    _presence.setOffline();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _goOnline();
    } else {
      _goOffline();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
