import 'dart:convert';
import 'dart:typed_data';

import 'package:chat_app/services/profile/profile_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Circle avatar: the user's photo if they have one, otherwise colored initials.
class UserAvatar extends StatefulWidget {
  final String uid;
  final String name;
  final double radius;

  const UserAvatar({
    super.key,
    required this.uid,
    required this.name,
    this.radius = 20,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  // Decoded photos, so scrolling the list doesn't re-decode base64.
  static final Map<String, Uint8List> _cache = {};

  late Stream<DocumentSnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = ProfileService().photoStream(widget.uid);
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _stream = ProfileService().photoStream(widget.uid);
    }
  }

  Uint8List? _bytesFrom(Map<String, dynamic>? data) {
    final b64 = data?['data'];
    if (b64 is! String || b64.isEmpty) return null;

    final ts = data?['updatedAt'];
    final version = ts is Timestamp ? ts.millisecondsSinceEpoch : 0;
    final key = '${widget.uid}-$version';

    try {
      final cached = _cache[key];
      if (cached != null) return cached;

      // Drop older versions of this user's photo.
      _cache.removeWhere((k, _) => k.startsWith('${widget.uid}-'));
      return _cache[key] = base64Decode(b64);
    } catch (_) {
      return null; // corrupt data: fall back to initials
    }
  }

  String get _initials {
    final parts =
        widget.name
            .trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color get _color {
    const palette = [
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.purple,
      Colors.blueGrey,
      Colors.brown,
    ];
    return palette[widget.uid.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final bytes = _bytesFrom(snapshot.data?.data());

        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: _color,
          backgroundImage: bytes != null ? MemoryImage(bytes) : null,
          child:
              bytes == null
                  ? Text(
                    _initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.radius * 0.8,
                    ),
                  )
                  : null,
        );
      },
    );
  }
}
