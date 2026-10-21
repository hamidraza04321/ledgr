import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/period.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import 'type_toggle.dart';

class TrendBucket {
  const TrendBucket(this.label, this.income, this.expense);

  final String label;
  final double income;
  final double expense;
}

/// Buckets points by day (≤ 31 days), month (≤ 2 years) or year.
List<TrendBucket> buildTrend(Period period, List<AmountPoint> points) {
  if (period.kind == PeriodKind.day) return const [];
  var span = period.span;
  if (period.kind == PeriodKind.all) {
    if (points.isEmpty) return const [];
    span = DateSpan(
      dateOnly(points.first.date),
      dateOnly(points.last.date).add(const Duration(days: 1)),
    );
  }

  final days = math.max(1, span.days);
  final start = span.start;
  final keys = <DateTime>[];
  final String Function(DateTime) label;
  final DateTime Function(DateTime) keyOf;

  if (days <= 31) {
    for (var i = 0; i < days; i++) {
      keys.add(DateTime(start.year, start.month, start.day + i));
    }
    keyOf = dateOnly;
    label = period.kind == PeriodKind.week
        ? (d) => DateFormat('EEE').format(d)
        : (d) => '${d.day}';
  } else if (days <= 731) {
    var m = DateTime(start.year, start.month);
    while (m.isBefore(span.end)) {
      keys.add(m);
      m = DateTime(m.year, m.month + 1);
    }
    keyOf = (d) => DateTime(d.year, d.month);
    label = keys.length <= 12
        ? (d) => DateFormat('MMMMM').format(d)
        : (d) => DateFormat('MMM yy').format(d);
  } else {
    for (var y = start.year; y < span.end.year || y == start.year; y++) {
      keys.add(DateTime(y));
    }
    keyOf = (d) => DateTime(d.year);
    label = (d) => '${d.year}';
  }

  final income = {for (final k in keys) k: 0.0};
  final expense = {for (final k in keys) k: 0.0};
  for (final p in points) {
    final k = keyOf(p.date);
    if (p.type == TxnType.income && income.containsKey(k)) {
      income[k] = income[k]! + p.amount;
    } else if (p.type == TxnType.expense && expense.containsKey(k)) {
      expense[k] = expense[k]! + p.amount;
    }
  }
  return [for (final k in keys) TrendBucket(label(k), income[k]!, expense[k]!)];
}

class TrendCard extends ConsumerStatefulWidget {
  const TrendCard({super.key});

  @override
  ConsumerState<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends ConsumerState<TrendCard> {
  TxnType _type = TxnType.expense;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(periodProvider);
    final points = ref.watch(periodPointsProvider).value ?? const [];
    final currency = ref.watch(currencyProvider);
    final buckets = buildTrend(period, points);
    if (buckets.isEmpty) return const SizedBox.shrink();

    final values = [
      for (final b in buckets) _type == TxnType.expense ? b.expense : b.income,
    ];
    final total = values.fold<double>(0, (a, b) => a + b);
    final maxV = values.fold<double>(0, math.max);
    final color = typeColor(context, _type);
    final daily = buckets.length > 1 && period.span.days <= 31;
    // Average over buckets that have started (not future days/months).
    final now = DateTime.now();
    final span = period.span;
    var elapsed = values.length;
    if (span.contains(now)) {
      elapsed = daily
          ? dateOnly(now).difference(span.start).inDays + 1
          : (now.year - span.start.year) * 12 + now.month - span.start.month + 1;
    }
    elapsed = elapsed.clamp(1, values.length);
    final avg = values.isEmpty ? 0.0 : (total / elapsed).roundToDouble();
    final showBackRods = values.length <= 12;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _type == TxnType.expense ? 'Spending trend' : 'Income trend',
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      total == 0
                          ? 'Nothing ${period.phrase}'
                          : 'Avg ${currency.format(avg, compact: true)}'
                              ' per ${daily ? 'day' : 'month'}',
                      style: context.text.bodySmall
                          ?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TypeToggle(
                value: _type,
                onChanged: (t) => setState(() => _type = t),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                maxY: maxV <= 0 ? 1 : maxV * 1.15,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxV <= 0 ? 1 : maxV * 1.15 / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.colors.outlineVariant,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxV <= 0 ? 1 : maxV * 1.15 / 4,
                      getTitlesWidget: (v, meta) {
                        if (v == meta.max || maxV <= 0) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            NumberFormat.compact().format(v),
                            style: context.text.labelSmall?.copyWith(
                                color: context.colors.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        final n = buckets.length;
                        final show = n <= 12 || i == 0 || (i + 1) % 5 == 0;
                        if (!show || i < 0 || i >= n) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            buckets[i].label,
                            style: context.text.labelSmall?.copyWith(
                                color: context.colors.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.colors.inverseSurface,
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${buckets[group.x].label}\n',
                      TextStyle(
                        color: context.colors.onInverseSurface
                            .withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                      children: [
                        TextSpan(
                          text: currency.format(rod.toY),
                          style: TextStyle(
                            color: context.colors.onInverseSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i],
                          color: color,
                          width: values.length <= 7
                              ? 18
                              : values.length <= 12
                                  ? 12
                                  : 6,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: showBackRods,
                            toY: maxV <= 0 ? 1 : maxV * 1.15,
                            color: color.withValues(alpha: 0.05),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
