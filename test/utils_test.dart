import 'package:chat_app/utils/chat_utils.dart';
import 'package:chat_app/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chatRoomId', () {
    test('is the same regardless of argument order', () {
      expect(chatRoomId('b', 'a'), 'a_b');
      expect(chatRoomId('a', 'b'), 'a_b');
    });
  });

  group('dayLabel', () {
    final now = DateTime(2026, 11, 16, 12);

    test('today and yesterday', () {
      expect(dayLabel(DateTime(2026, 11, 16, 1), now: now), 'Today');
      expect(dayLabel(DateTime(2026, 11, 15, 23), now: now), 'Yesterday');
    });

    test('older dates are formatted', () {
      expect(dayLabel(DateTime(2026, 11, 3), now: now), '3 Nov 2026');
    });
  });

  test('formatTime pads with zeros', () {
    expect(formatTime(DateTime(2026, 1, 1, 7, 3)), '07:03');
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email(' me@example.com '), isNull);
    });

    test('new password needs 8+ characters', () {
      expect(Validators.newPassword('short'), isNotNull);
      expect(Validators.newPassword('longenough'), isNull);
    });

    test('confirm password must match', () {
      expect(Validators.confirmPassword('abc', 'abd'), isNotNull);
      expect(Validators.confirmPassword('abc', 'abc'), isNull);
    });
  });
}
