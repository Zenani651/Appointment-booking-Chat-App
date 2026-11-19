import 'package:chat_app/components/my_drawer.dart';
import 'package:chat_app/components/user_tile.dart';
import 'package:chat_app/pages/business_directory_page.dart';
import 'package:chat_app/pages/business_profile_page.dart';
import 'package:chat_app/pages/chat_page.dart';
import 'package:chat_app/services/auth/auth.dart';
import 'package:chat_app/services/chat/chat_service.dart';
import 'package:chat_app/services/presence/presence_service.dart';
import 'package:chat_app/utils/chat_utils.dart';
import 'package:chat_app/utils/roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'Browse businesses',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BusinessDirectoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: Column(
        children: [_buildSearchBar(), Expanded(child: _buildUserList())],
      ),
    );
  }

  Widget _buildSearchBar() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 8, 25, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value.trim()),
        decoration: InputDecoration(
          hintText: 'Search users',
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

  Widget _buildUserList() {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Could not load users. Please try again.'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allOthers =
            (snapshot.data ?? [])
                .where((u) => u['uid'] != currentUser.uid)
                .toList();

        if (allOthers.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(25),
              child: Text(
                'No other users yet.\nRegister a second account to start chatting.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Search by display name or email, case-insensitive.
        final q = _query.toLowerCase();
        final users =
            allOthers.where((u) {
                if (q.isEmpty) return true;
                final name = displayNameOf(u).toLowerCase();
                final email = (u['email'] ?? '').toString().toLowerCase();
                return name.contains(q) || email.contains(q);
              }).toList()
              ..sort(
                (a, b) => displayNameOf(
                  a,
                ).toLowerCase().compareTo(displayNameOf(b).toLowerCase()),
              );

        if (users.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Text(
                'No users match "$_query".',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView(
          children:
              users
                  .map<Widget>(
                    (u) => _buildUserListItem(u, currentUser.uid, context),
                  )
                  .toList(),
        );
      },
    );
  }

  /// One tile per user: name, last message, time, unread badge, online dot.
  Widget _buildUserListItem(
    Map<String, dynamic> userData,
    String myUid,
    BuildContext context,
  ) {
    final String name = displayNameOf(userData);
    final String email = (userData['email'] ?? '').toString();
    final String uid = userData['uid'];
    final bool online = isUserOnline(userData);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _chatService.getChatRoomStream(uid),
      builder: (context, snapshot) {
        final room = snapshot.data?.data();

        // Without messages yet, show the email under the name.
        String? subtitle = name != email ? email : null;
        String? time;
        int unread = 0;

        if (room != null) {
          final lastMessage = room['lastMessage'] as String?;
          if (lastMessage != null) {
            final lastSender = room['lastSenderID'];
            subtitle = lastSender == myUid ? 'You: $lastMessage' : lastMessage;
          }
          final ts = room['lastTimestamp'];
          if (ts is Timestamp) time = shortTimestamp(ts.toDate());
          final counts = room['unreadCount'];
          if (counts is Map) unread = (counts[myUid] as num?)?.toInt() ?? 0;
        }

        final bool isBusiness = isBusinessUser(userData);

        return UserTile(
          uid: uid,
          text: name,
          subtitle: subtitle,
          time: time,
          unreadCount: unread,
          isOnline: online,
          isBusiness: isBusiness,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        isBusiness
                            ? BusinessProfilePage(
                              businessID: uid,
                              businessName: name,
                            )
                            : ChatPage(receiverName: name, receiverID: uid),
              ),
            );
          },
        );
      },
    );
  }
}
