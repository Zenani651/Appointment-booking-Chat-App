/// The two account types.
class UserRole {
  static const String customer = 'customer';
  static const String business = 'business';
  static const List<String> all = [customer, business];
}

/// Accounts created before roles existed have no role: treat them as customers.
String roleOf(Map<String, dynamic> user) {
  final role = user['role'];
  return role is String && UserRole.all.contains(role)
      ? role
      : UserRole.customer;
}

bool isBusinessUser(Map<String, dynamic> user) =>
    roleOf(user) == UserRole.business;
