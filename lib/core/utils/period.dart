import 'package:intl/intl.dart';

import 'dates.dart';

enum PeriodKind {
  day('Daily'),
  week('Weekly'),
  month('Monthly'),
  year('Yearly'),
  all('All time'),
  custom('Custom range');

  const PeriodKind(this.label);
  final String label;
}

/// Half-open date range: [start, end).
class DateSpan {
  const DateSpan(this.start, this.end);

  final DateTime start;
  final DateTime end;

  int get startMs => start.millisecondsSinceEpoch;
  int get endMs => end.millisecondsSinceEpoch;
  int get days => end.difference(start).inDays;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  @override
  bool operator ==(Object other) =>
      other is DateSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

class Period {
  const Period._(this.kind, this.anchor, [this.customSpan]);

  factory Period.of(PeriodKind kind, {DateTime? anchor, DateSpan? custom}) {
    final a = dateOnly(anchor ?? DateTime.now());
    return Period._(kind, a, kind == PeriodKind.custom ? custom : null);
  }

  factory Period.thisMonth() => Period.of(PeriodKind.month);

  factory Period.custom(DateTime from, DateTime toInclusive) => Period._(
        PeriodKind.custom,
        dateOnly(from),
        DateSpan(dateOnly(from), dateOnly(toInclusive).add(const Duration(days: 1))),
      );

  final PeriodKind kind;
  final DateTime anchor;
  final DateSpan? customSpan;

  static final _allStart = DateTime(2000);
  static final _allEnd = DateTime(2100);

  DateSpan get span {
    final a = anchor;
    switch (kind) {
      case PeriodKind.day:
        return DateSpan(a, DateTime(a.year, a.month, a.day + 1));
      case PeriodKind.week:
        final start = DateTime(a.year, a.month, a.day - (a.weekday - 1));
        return DateSpan(start, DateTime(start.year, start.month, start.day + 7));
      case PeriodKind.month:
        return DateSpan(DateTime(a.year, a.month), DateTime(a.year, a.month + 1));
      case PeriodKind.year:
        return DateSpan(DateTime(a.year), DateTime(a.year + 1));
      case PeriodKind.all:
        return DateSpan(_allStart, _allEnd);
      case PeriodKind.custom:
        return customSpan ?? DateSpan(a, DateTime(a.year, a.month, a.day + 1));
    }
  }

  bool get canShift => kind != PeriodKind.all && kind != PeriodKind.custom;

  Period shift(int delta) {
    final a = anchor;
    switch (kind) {
      case PeriodKind.day:
        return Period._(kind, DateTime(a.year, a.month, a.day + delta));
      case PeriodKind.week:
        return Period._(kind, DateTime(a.year, a.month, a.day + 7 * delta));
      case PeriodKind.month:
        return Period._(kind, DateTime(a.year, a.month + delta, 1));
      case PeriodKind.year:
        return Period._(kind, DateTime(a.year + delta, 1, 1));
      case PeriodKind.all:
      case PeriodKind.custom:
        return this;
    }
  }

  /// True when the period contains today (used to disable "next").
  bool get isCurrent => span.contains(DateTime.now());

  String get label {
    final now = DateTime.now();
    final s = span;
    switch (kind) {
      case PeriodKind.day:
        return DateLabels.relativeDay(anchor, now: now);
      case PeriodKind.week:
        if (s.contains(now)) return 'This week';
        final last = s.end.subtract(const Duration(days: 1));
        return '${DateLabels.dayMonth(s.start)} – ${DateLabels.dayMonth(last)}';
      case PeriodKind.month:
        return anchor.year == now.year
            ? DateFormat('MMMM').format(anchor)
            : DateFormat('MMM yyyy').format(anchor);
      case PeriodKind.year:
        return '${anchor.year}';
      case PeriodKind.all:
        return 'All time';
      case PeriodKind.custom:
        final last = s.end.subtract(const Duration(days: 1));
        final sameYear = s.start.year == last.year && last.year == now.year;
        return sameYear
            ? '${DateLabels.dayMonth(s.start)} – ${DateLabels.dayMonth(last)}'
            : '${DateLabels.dayMonthYear(s.start)} – ${DateLabels.dayMonthYear(last)}';
    }
  }

  /// "this month" / "this week" etc. for sentences.
  String get phrase {
    if (!isCurrent) return label;
    switch (kind) {
      case PeriodKind.day:
        return 'today';
      case PeriodKind.week:
        return 'this week';
      case PeriodKind.month:
        return 'this month';
      case PeriodKind.year:
        return 'this year';
      case PeriodKind.all:
        return 'all time';
      case PeriodKind.custom:
        return label;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Period && other.kind == kind && other.span == span;

  @override
  int get hashCode => Object.hash(kind, span);
}
