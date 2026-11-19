import 'package:chat_app/components/business_status.dart';
import 'package:chat_app/components/star_rating.dart';
import 'package:chat_app/components/user_avatar.dart';
import 'package:chat_app/pages/business_profile_page.dart';
import 'package:chat_app/services/auth/auth.dart';
import 'package:chat_app/services/chat/chat_service.dart';
import 'package:chat_app/services/profile/business_profile_service.dart';
import 'package:chat_app/services/profile/review_service.dart';
import 'package:chat_app/utils/business_hours.dart';
import 'package:chat_app/utils/chat_utils.dart';
import 'package:chat_app/utils/roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Lists every business account so customers can discover them.
class BusinessDirectoryPage extends StatefulWidget {
  const BusinessDirectoryPage({super.key});

  @override
  State<BusinessDirectoryPage> createState() => _BusinessDirectoryPageState();
}

class _BusinessDirectoryPageState extends State<BusinessDirectoryPage> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _usersStream;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _usersStream = ChatService().getUsersStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 8, 25, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value.trim()),
        decoration: InputDecoration(
          hintText: 'Search businesses',
          hintStyle: TextStyle(color: scheme.primary),
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _query.isEmpty
                  ? null
                  : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
          filled: true,
          fillColor: scheme.secondary,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: scheme.tertiary),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: scheme.primary),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().getCurrentUser()?.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Businesses'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _usersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load businesses.'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final q = _query.toLowerCase();
                final businesses =
                    (snapshot.data ?? [])
                        .where((u) => u['uid'] != myUid && isBusinessUser(u))
                        .where(
                          (u) =>
                              q.isEmpty ||
                              displayNameOf(u).toLowerCase().contains(q),
                        )
                        .toList()
                      ..sort(
                        (a, b) => displayNameOf(a).toLowerCase().compareTo(
                          displayNameOf(b).toLowerCase(),
                        ),
                      );

                if (businesses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Text(
                        _query.isEmpty
                            ? 'No businesses have joined yet.'
                            : 'No businesses match "$_query".',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: businesses.length,
                  itemBuilder: (context, index) {
                    final b = businesses[index];
                    return _BusinessCard(
                      key: ValueKey(b['uid']),
                      uid: b['uid'] as String,
                      name: displayNameOf(b),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One business: logo, name, average rating, open/closed status.
class _BusinessCard extends StatefulWidget {
  final String uid;
  final String name;

  const _BusinessCard({super.key, required this.uid, required this.name});

  @override
  State<_BusinessCard> createState() => _BusinessCardState();
}

class _BusinessCardState extends State<_BusinessCard> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _reviewsStream;

  @override
  void initState() {
    super.initState();
    _profileStream = BusinessProfileService().profileStream(widget.uid);
    _reviewsStream = ReviewService().reviewsStream(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => BusinessProfilePage(
                  businessID: widget.uid,
                  businessName: widget.name,
                ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 25),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.secondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(uid: widget.uid, name: widget.name, radius: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ratingRow(),
                  _statusRow(),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _ratingRow() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _reviewsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text(
            'No reviews yet',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          );
        }
        double total = 0;
        for (final doc in docs) {
          total += (doc.data()['rating'] as num?)?.toDouble() ?? 0;
        }
        final average = total / docs.length;
        return Row(
          children: [
            StarRating(value: average, size: 15),
            const SizedBox(width: 6),
            Text(
              '${average.toStringAsFixed(1)} (${docs.length})',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  Widget _statusRow() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final status = openStatus(
          data?['opensAt']?.toString(),
          data?['closesAt']?.toString(),
        );
        final hasAnnouncement =
            (data?['announcement'] ?? '').toString().trim().isNotEmpty;

        if (status == null && !hasAnnouncement) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (status != null) OpenStatusChip(status: status),
              if (hasAnnouncement)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 16,
                      color: Colors.amber,
                    ),
                    SizedBox(width: 4),
                    Text('Announcement', style: TextStyle(fontSize: 12)),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
