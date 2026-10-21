/// Finds one date phrase (Roman Urdu or English) in lowercase text.
class DateHit {
  const DateHit(this.date, this.rest);

  final DateTime? date;

  /// Text with the matched phrase blanked out.
  final String rest;
}

class DateDetector {
  DateDetector._();

  static const _monthPattern =
      r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sept?(?:ember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';

  static final _numeric = RegExp(
      r'(?<![\d.])(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?(?![\d/-])');
  static final _daysAgo = RegExp(
      r'(?<!\d)(\d{1,2})\s*(?:din|dino|dinon|days?)\s*(?:pehle|pehlay|pehley|pahle|pahlay|phle|ago|qabal|before)\b');
  static final _dayBefore = RegExp(
      r'\b(?:day before yesterday|parson|parso|parsun|parsoon)\b');
  static final _yesterday =
      RegExp(r'\b(?:yesterday|guzishta kal|kal|kl|kaal)\b');
  static final _today = RegExp(r'\b(?:today|aaj|aj|ajj|abhi)\b');
  static final _weekday = RegExp(
      r'\b(?:(last|pichl[ae]y?|pichhle|guzishta)\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|somwar|peer|pir|mangal|mangalwar|budh|budhwar|jumeraat|jumerat|jumairat|juma|jumma|jummah|itwar|itwaar|itvar)\b');

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static const _weekdays = {
    'monday': 1, 'somwar': 1, 'peer': 1, 'pir': 1,
    'tuesday': 2, 'mangal': 2, 'mangalwar': 2,
    'wednesday': 3, 'budh': 3, 'budhwar': 3,
    'thursday': 4, 'jumeraat': 4, 'jumerat': 4, 'jumairat': 4,
    'friday': 5, 'juma': 5, 'jumma': 5, 'jummah': 5,
    'saturday': 6,
    'sunday': 7, 'itwar': 7, 'itwaar': 7, 'itvar': 7,
  };

  static DateHit detect(String text, DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    // Only nearby years count, so "25 dec 1000" keeps 1000 as the amount.
    final years = [for (var y = t.year - 5; y <= t.year + 1; y++) y].join('|');
    final dayMonth = RegExp(
        '(?<!\\d)(\\d{1,2})(?:st|nd|rd|th)?\\s*(?:of\\s+)?$_monthPattern\\b'
        '(?:,?\\s*($years)(?!\\d))?');
    final monthDay = RegExp(
        '\\b$_monthPattern\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b'
        '(?:,?\\s*($years)(?!\\d))?');
    final rules = <(RegExp, DateTime? Function(Match))>[
      (_numeric, (m) => _build(m[3], int.parse(m[2]!), int.parse(m[1]!), t)),
      (
        dayMonth,
        (m) => _build(m[3], _months[m[2]!.substring(0, 3)]!, int.parse(m[1]!), t)
      ),
      (
        monthDay,
        (m) => _build(m[3], _months[m[1]!.substring(0, 3)]!, int.parse(m[2]!), t)
      ),
      (_daysAgo, (m) => _minus(t, int.parse(m[1]!))),
      (_dayBefore, (_) => _minus(t, 2)),
      (_yesterday, (_) => _minus(t, 1)),
      (_today, (_) => t),
      (_weekday, (m) {
        final wd = _weekdays[m[2]!]!;
        var diff = (t.weekday - wd) % 7;
        if (diff == 0 && m[1] != null) diff = 7;
        return _minus(t, diff);
      }),
    ];

    for (final (re, build) in rules) {
      for (final m in re.allMatches(text)) {
        final d = build(m);
        if (d == null) continue;
        final rest = text.replaceRange(m.start, m.end, ' ');
        return DateHit(d, rest);
      }
    }
    return DateHit(null, text);
  }

  static DateTime _minus(DateTime t, int days) =>
      DateTime(t.year, t.month, t.day - days);

  static DateTime? _build(String? yearStr, int month, int day, DateTime today) {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      // Maybe written month/day.
      if (day >= 1 && day <= 12 && month >= 1 && month <= 31) {
        final swapped = month;
        month = day;
        day = swapped;
      } else {
        return null;
      }
    }
    var year = today.year;
    if (yearStr != null) {
      year = int.parse(yearStr);
      if (year < 100) year += 2000;
    }
    final d = DateTime(year, month, day);
    if (d.month != month) return null; // e.g. 31 Feb
    if (yearStr == null && d.isAfter(today)) {
      return DateTime(year - 1, month, day);
    }
    return d;
  }
}
