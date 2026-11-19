import 'package:chat_app/components/my_button.dart';
import 'package:chat_app/components/my_textfields.dart';
import 'package:chat_app/components/star_rating.dart';
import 'package:flutter/material.dart';

class ReviewResult {
  final int rating;
  final String comment;
  final bool delete;

  const ReviewResult({
    required this.rating,
    required this.comment,
    this.delete = false,
  });
}

/// Shows the "Rate this business" form. Returns null if dismissed.
Future<ReviewResult?> showReviewSheet(
  BuildContext context, {
  int initialRating = 0,
  String initialComment = '',
  bool canDelete = false,
}) {
  return showModalBottomSheet<ReviewResult>(
    context: context,
    isScrollControlled: true,
    builder:
        (context) => _ReviewSheet(
          initialRating: initialRating,
          initialComment: initialComment,
          canDelete: canDelete,
        ),
  );
}

class _ReviewSheet extends StatefulWidget {
  final int initialRating;
  final String initialComment;
  final bool canDelete;

  const _ReviewSheet({
    required this.initialRating,
    required this.initialComment,
    required this.canDelete,
  });

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _rating = widget.initialRating;
  late final TextEditingController _commentController = TextEditingController(
    text: widget.initialComment,
  );
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_rating == 0) {
      setState(() => _error = 'Choose a star rating');
      return;
    }
    Navigator.pop(
      context,
      ReviewResult(rating: _rating, comment: _commentController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(25, 20, 25, 8),
                child: Text(
                  'Rate this business',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              StarPicker(
                value: _rating,
                onChanged:
                    (value) => setState(() {
                      _rating = value;
                      _error = null;
                    }),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              const SizedBox(height: 8),
              MyTextfields(
                hintText: 'Add a comment (optional)',
                obscureText: false,
                controller: _commentController,
                maxLines: 3,
                maxLength: 300,
              ),
              const SizedBox(height: 16),
              MyButton(text: 'Submit review', onTap: _submit),
              if (widget.canDelete)
                TextButton(
                  onPressed:
                      () => Navigator.pop(
                        context,
                        const ReviewResult(
                          rating: 0,
                          comment: '',
                          delete: true,
                        ),
                      ),
                  child: const Text('Delete my review'),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
