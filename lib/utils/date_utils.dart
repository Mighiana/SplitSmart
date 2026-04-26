import 'package:intl/intl.dart';

// Date formatting centralized
class AppDateUtils {
  /// Always returns ISO format "YYYY-MM-DD" so rawDate can parse it reliably.
  /// This fixes the bug where new transactions were invisible until app restart.
  static String todayStr() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static String monthLabel(DateTime d, String locale) {
    return DateFormat.yMMMM(locale).format(d);
  }
}
