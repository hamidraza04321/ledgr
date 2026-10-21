import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/period.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../transactions/transactions_screen.dart';
import 'type_toggle.dart';

class _Slice {
  _Slice(this.category, this.total, this.count);

  final Category category;
  double total;
  int count;
}

class CategoryBreakdownCard extends ConsumerStatefulWidget {
  const CategoryBreakdownCard({super.key});

  @override
  ConsumerState<CategoryBreakdownCard> createState() =>
      _CategoryBreakdownCardState();
}

class _CategoryBreakdownCardState extends ConsumerState<CategoryBreakdownCard> {
  TxnType _type = TxnType.expense;
  int? _touched;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final totals = ref.watch(categoryTotalsProvider(_type)).value ?? const [];
    final cats = ref.watch(categoryMapProvider);
    final currency = ref.watch(currencyProvider);
    final period = ref.watch(periodProvider);

    // Merge deleted categories into their fallback.
    final byId = <String, _Slice>{};
    for (final t in totals) {
      final c = resolveCategory(cats, t.categoryId, _type);
      final s = byId.putIfAbsent(c.id, () => _Slice(c, 0, 0));
      s.total += t.total;
      s.count += t.count;
    }
    final slices = byId.values.toList()..sort((a, b) => b.total.compareTo(a.total));
    final sum = slices.fold<double>(0, (a, s) => a + s.total);
    final touched =
        _touched != null && _touched! < slices.length ? slices[_touched!] : null;
    final visible = _expanded ? slices : slices.take(5).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('By category', style: context.text.titleMedium),
              ),
              TypeToggle(
                value: _type,
                onChanged: (t) => setState(() {
                  _type = t;
                  _touched = null;
                  _expanded = false;
                }),
              ),
            ],
          ),
          if (slices.isEmpty)
            EmptyState(
              compact: true,
              icon: Icons.donut_large_rounded,
              title: _type == TxnType.expense
                  ? 'No spending ${period.phrase}'
                  : 'No income ${period.phrase}',
            )
          else ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: 2,
                      centerSpaceRadius: 62,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions) return;
                          final i =
                              response?.touchedSection?.touchedSectionIndex;
                          setState(() => _touched = (i == null || i < 0) ? null : i);
                        },
                      ),
                      sections: [
                        for (var i = 0; i < slices.length; i++)
                          PieChartSectionData(
                            value: slices[i].total,
                            color: Color(slices[i].category.color),
                            radius: _touched == i ? 26 : 20,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        touched?.category.name ?? 'Total',
                        style: context.text.labelMedium
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currency.format(touched?.total ?? sum, compact: true),
                        style: context.text.titleLarge,
                      ),
                      if (touched != null)
                        Text(
                          '${(touched.total / sum * 100).toStringAsFixed(1)}%',
                          style: context.text.labelSmall
                              ?.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final s in visible)
              _CategoryRow(
                slice: s,
                share: sum == 0 ? 0 : s.total / sum,
                showBudget: _type == TxnType.expense &&
                    period.kind == PeriodKind.month,
              ),
            if (slices.length > 5)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded
                    ? 'Show less'
                    : 'Show all ${slices.length} categories'),
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({
    required this.slice,
    required this.share,
    required this.showBudget,
  });

  final _Slice slice;
  final double share;
  final bool showBudget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final c = slice.category;
    final color = Color(c.color);
    final budget = showBudget && c.hasBudget ? c.budget! : null;
    final progress = budget != null ? slice.total / budget : share;
    final barColor = budget == null
        ? color
        : progress >= 1
            ? context.palette.expense
            : progress >= 0.8
                ? context.palette.warning
                : context.palette.income;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TransactionsScreen(categoryId: c.id, title: c.name),
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            IconBadge(icon: categoryIcon(c.icon), color: color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall),
                      ),
                      Text(currency.format(slice.total),
                          style: context.text.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ProgressBar(value: progress, color: barColor, height: 5),
                  const SizedBox(height: 4),
                  Text(
                    budget != null
                        ? '${(progress * 100).round()}% of ${currency.format(budget)} budget'
                        : '${(share * 100).toStringAsFixed(share < 0.1 ? 1 : 0)}%'
                            ' · ${slice.count} ${slice.count == 1 ? 'entry' : 'entries'}',
                    style: context.text.labelSmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
