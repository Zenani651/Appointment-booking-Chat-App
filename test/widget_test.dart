import 'package:chat_app/components/chat_bubble.dart';
import 'package:chat_app/components/my_textfields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChatBubble shows message text and time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: 'Hello there',
            isCurrentUser: true,
            timestamp: DateTime(2026, 11, 16, 9, 5),
          ),
        ),
      ),
    );

    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('09:05'), findsOneWidget);
  });

  testWidgets('MyTextfields hides text when obscureText is true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            secondary: Colors.grey,
            tertiary: Colors.white,
          ),
        ),
        home: Scaffold(
          body: MyTextfields(
            hintText: 'Password',
            obscureText: true,
            controller: TextEditingController(),
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
  });
}
