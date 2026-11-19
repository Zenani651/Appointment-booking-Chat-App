import 'package:flutter/material.dart';

/// Read-only stars, e.g. for an average of 4.5.
class StarRating extends StatelessWidget {
  final double value;
  final double size;

  const StarRating({super.key, required this.value, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final star = index + 1;
        IconData icon;
        if (value >= star) {
          icon = Icons.star;
        } else if (value >= star - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, size: size, color: Colors.amber);
      }),
    );
  }
}

/// Tappable stars for choosing a rating.
class StarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const StarPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final star = index + 1;
        return IconButton(
          iconSize: 38,
          onPressed: () => onChanged(star),
          icon: Icon(
            star <= value ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
        );
      }),
    );
  }
}
