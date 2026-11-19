import 'package:chat_app/components/business_status.dart';
import 'package:chat_app/components/my_button.dart';
import 'package:chat_app/components/review_sheet.dart';
import 'package:chat_app/components/star_rating.dart';
import 'package:chat_app/components/user_avatar.dart';
import 'package:chat_app/pages/chat_page.dart';
import 'package:chat_app/services/auth/auth.dart';
import 'package:chat_app/services/chat/chat_service.dart';
import 'package:chat_app/services/profile/business_profile_service.dart';
import 'package:chat_app/services/profile/review_service.dart';
import 'package:chat_app/utils/business_hours.dart';
import 'package:chat_app/utils/chat_utils.dart';
import 'package:chat_app/utils/roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BusinessProfilePage extends StatelessWidget {
  final String businessID;
  final String businessName;

  const BusinessProfilePage({
    super.key,
    required this.businessID,
    required this.businessName,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(businessName),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: BusinessProfileService().profileStream(businessID),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data();
          String field(String key) => (data?[key] ?? '').toString().trim();

          final description = field('description');
          final hours = field('hours');
          final phone = field('phone');
          final address = field('address');
          final announcement = field('announcement');
          final status = openStatus(field('opensAt'), field('closesAt'));
          final hasDetails = [
            description,
            hours,
            phone,
            address,
            announcement,
          ].any((value) => value.isNotEmpty);

          return ListView(
            padding: const EdgeInsets.all(25),
            children: [
              Center(
                child: UserAvatar(
                  uid: businessID,
                  name: businessName,
                  radius: 52,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  businessName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Business',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (status != null) ...[
                const SizedBox(height: 12),
                Center(child: OpenStatusChip(status: status)),
              ],
              const SizedBox(height: 24),
              if (announcement.isNotEmpty)
                AnnouncementBanner(text: announcement),
              if (!hasDetails)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    "This business hasn't added details yet.",
                    textAlign: TextAlign.center,
                  ),
                ),
              if (description.isNotEmpty)
                _InfoCard(
                  icon: Icons.info_outline,
                  label: 'About',
                  text: description,
                ),
              if (hours.isNotEmpty)
                _InfoCard(
                  icon: Icons.schedule,
                  label: 'Opening hours',
                  text: hours,
                ),
              if (phone.isNotEmpty)
                _InfoCard(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  text: phone,
                  onCopy: () async {
                    await Clipboard.setData(ClipboardData(text: phone));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Phone number copied')),
                      );
                    }
                  },
                ),
              if (address.isNotEmpty)
                _InfoCard(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  text: address,
                ),
              const SizedBox(height: 8),
              _ReviewsSection(businessID: businessID),
              const SizedBox(height: 16),
              MyButton(
                text: 'Message',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ChatPage(
                            receiverName: businessName,
                            receiverID: businessID,
                          ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Average rating, the latest reviews, and the "Rate this business" button.
class _ReviewsSection extends StatefulWidget {
  final String businessID;
  const _ReviewsSection({required this.businessID});

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  final ReviewService _reviews = ReviewService();
  late final String _myUid;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _reviewsStream;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _meStream;

  @override
  void initState() {
    super.initState();
    _myUid = AuthService().getCurrentUser()?.uid ?? '';
    _reviewsStream = _reviews.reviewsStream(widget.businessID);
    _meStream = ChatService().getUserStream(_myUid);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _rate(Map<String, dynamic>? mine) async {
    final result = await showReviewSheet(
      context,
      initialRating: (mine?['rating'] as num?)?.toInt() ?? 0,
      initialComment: (mine?['comment'] ?? '').toString(),
      canDelete: mine != null,
    );
    if (result == null) return;

    try {
      if (result.delete) {
        await _reviews.deleteMyReview(widget.businessID);
        _toast('Review deleted');
      } else {
        await _reviews.saveReview(
          widget.businessID,
          rating: result.rating,
          comment: result.comment,
        );
        _toast('Thanks for your review!');
      }
    } on FirebaseException catch (e) {
      _toast(
        e.code == 'permission-denied'
            ? 'You can review a business after you have chatted with it.'
            : 'Could not save your review.',
      );
    } catch (_) {
      _toast('Could not save your review.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _reviewsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        double total = 0;
        for (final doc in docs) {
          total += (doc.data()['rating'] as num?)?.toDouble() ?? 0;
        }
        final average = docs.isEmpty ? 0.0 : total / docs.length;

        Map<String, dynamic>? mine;
        for (final doc in docs) {
          if (doc.id == _myUid) mine = doc.data();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Ratings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (docs.isNotEmpty) ...[
                  StarRating(value: average),
                  const SizedBox(width: 6),
                  Text(
                    '${average.toStringAsFixed(1)} (${docs.length})',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (docs.isEmpty)
              const Text('No reviews yet.')
            else
              ...docs.take(10).map((doc) {
                final review = doc.data();
                final rating = (review['rating'] as num?)?.toDouble() ?? 0;
                final comment = (review['comment'] ?? '').toString();
                final name = (review['reviewerName'] ?? 'Customer').toString();
                final ts = review['updatedAt'];

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (ts is Timestamp)
                            Text(
                              dayLabel(ts.toDate()),
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      StarRating(value: rating, size: 16),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(comment),
                      ],
                    ],
                  ),
                );
              }),

            // Only customers can rate (never the business itself).
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _meStream,
              builder: (context, meSnap) {
                final me = meSnap.data?.data();
                if (me == null ||
                    isBusinessUser(me) ||
                    _myUid == widget.businessID) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _rate(mine),
                        icon: const Icon(Icons.star_outline),
                        label: Text(
                          mine == null
                              ? 'Rate this business'
                              : 'Edit your review',
                        ),
                      ),
                    ),
                    if (mine == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'You can rate a business once you have chatted with it.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final VoidCallback? onCopy;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.text,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: scheme.primary),
                ),
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Copy',
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}
