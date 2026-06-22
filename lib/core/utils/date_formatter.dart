import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String tripDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Today, ${DateFormat('h:mm a').format(dt)}';
    if (date == yesterday) return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
    return DateFormat('dd MMM, h:mm a').format(dt);
  }

  static String shortDate(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);

  static String time(DateTime dt) => DateFormat('h:mm a').format(dt);

  static String fullDateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy • h:mm a').format(dt);

  static String relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return shortDate(dt);
  }
}
