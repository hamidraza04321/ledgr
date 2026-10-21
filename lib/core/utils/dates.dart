import 'package:intl/intl.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class DateLabels {
  DateLabels._();

  static final _dayMonth = DateFormat('d MMM');
  static final _dayMonthYear = DateFormat('d MMM yyyy');
  static final _weekdayDay = DateFormat('EEE, d MMM');
  static final _weekdayDayYear = DateFormat('EEE, d MMM yyyy');
  static final _time = DateFormat('h:mm a');
  static final _monthYear = DateFormat('MMMM yyyy');

  /// Today / Yesterday / Mon, 14 Oct
  static String relativeDay(DateTime d, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final day = dateOnly(d);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    return day.year == today.year
        ? _weekdayDay.format(day)
        : _weekdayDayYear.format(day);
  }

  /// Short: Today / Yesterday / 14 Oct
  static String shortDay(DateTime d, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final diff = today.difference(dateOnly(d)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return d.year == today.year ? _dayMonth.format(d) : _dayMonthYear.format(d);
  }

  static String time(DateTime d) => _time.format(d);
  static String dayMonth(DateTime d) => _dayMonth.format(d);
  static String dayMonthYear(DateTime d) => _dayMonthYear.format(d);
  static String monthYear(DateTime d) => _monthYear.format(d);

  static String ago(DateTime d, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(d);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return shortDay(d, now: now);
  }
}
