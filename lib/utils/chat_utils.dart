/// Builds the deterministic chat room ID for two users (sorted, joined by "_").
String chatRoomId(String userA, String userB) {
  final ids = [userA, userB]..sort();
  return ids.join('_');
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Today", "Yesterday" or e.g. "16 Nov 2026". [now] is injectable for tests.
String dayLabel(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  if (isSameDay(date, today)) return 'Today';
  final yesterday = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(const Duration(days: 1));
  if (isSameDay(date, yesterday)) return 'Yesterday';
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

/// 24-hour clock, e.g. "09:05".
String formatTime(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Short label for the home list: time if today, otherwise the day label.
String shortTimestamp(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return isSameDay(date, today) ? formatTime(date) : dayLabel(date, now: today);
}

/// Shows the display name if set, otherwise falls back to the email.
String displayNameOf(Map<String, dynamic> user) {
  final name = (user['displayName'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;
  return (user['email'] ?? 'Unknown').toString();
}

/// e.g. "last seen today at 09:05", "last seen yesterday at 09:05".
String lastSeenLabel(DateTime lastSeen, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = dayLabel(lastSeen, now: today);
  if (day == 'Today') return 'last seen today at ${formatTime(lastSeen)}';
  if (day == 'Yesterday') {
    return 'last seen yesterday at ${formatTime(lastSeen)}';
  }
  return 'last seen $day';
}

const List<String> _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// e.g. "Fri 21 Nov 2026 at 14:00".
String formatDateTimeLong(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year} '
    'at ${formatTime(d)}';
