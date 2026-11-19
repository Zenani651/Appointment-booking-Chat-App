/// Form validators. Each returns an error message, or null when valid.
class Validators {
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your email';
    if (!_emailRegex.hasMatch(v)) return 'Please enter a valid email address';
    return null;
  }

  /// Used on the login form: only checks that something was entered.
  static String? requiredPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Please enter your password';
    return null;
  }

  /// Used on the register form: enforces a minimum length.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter a password';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter a display name';
    if (v.length < 2) return 'Name must be at least 2 characters';
    if (v.length > 30) return 'Name must be 30 characters or fewer';
    return null;
  }

  /// Optional phone number: digits, spaces, + ( ) - only, 7-15 digits.
  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^[+0-9 ()\-]+$').hasMatch(v)) {
      return 'Use only digits, spaces, + ( ) -';
    }
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }
}
