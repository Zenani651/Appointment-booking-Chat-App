import 'package:flutter/material.dart';

Future<void> showMessageDialog(
  BuildContext context,
  String message, {
  String title = 'Oops',
}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
