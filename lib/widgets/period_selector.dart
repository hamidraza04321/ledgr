import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/period.dart';
import '../providers/providers.dart';

/// "‹  October ▾  ›" pill bound to [periodProvider].
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodProvider);
    final notifier = ref.read(periodProvider.notifier);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (period.canShift)
            _ArrowButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous',
              onTap: () => notifier.shift(-1),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showPeriodPicker(context, ref),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: period.canShift ? 6 : 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 18, color: context.colors.primary),
                  const SizedBox(width: 8),
                  Text(period.label, style: context.text.titleSmall),
                  const SizedBox(width: 2),
                  Icon(Icons.expand_more_rounded,
                      size: 20, color: context.colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
          if (period.canShift)
            _ArrowButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next',
              onTap: period.isCurrent ? null : () => notifier.shift(1),
            ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon),
    );
  }
}

Future<void> showPeriodPicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(periodProvider);
  final options = <(PeriodKind, String, IconData)>[
    (PeriodKind.day, 'Today', Icons.today_rounded),
    (PeriodKind.week, 'This week', Icons.view_week_rounded),
    (PeriodKind.month, 'This month', Icons.calendar_view_month_rounded),
    (PeriodKind.year, 'This year', Icons.calendar_today_rounded),
    (PeriodKind.all, 'All time', Icons.all_inclusive_rounded),
    (PeriodKind.custom, 'Custom range…', Icons.date_range_rounded),
  ];

  final picked = await showModalBottomSheet<PeriodKind>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text('Show period', style: ctx.text.titleLarge),
            ),
            for (final (kind, label, icon) in options)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                trailing: current.kind == kind
                    ? Icon(Icons.check_circle_rounded,
                        color: ctx.colors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, kind),
              ),
          ],
        ),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;

  final notifier = ref.read(periodProvider.notifier);
  if (picked == PeriodKind.custom) {
    final now = DateTime.now();
    final span = current.span;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: current.kind == PeriodKind.all
          ? null
          : DateTimeRange(
              start: span.start,
              end: span.end.subtract(const Duration(days: 1)),
            ),
    );
    if (range != null) notifier.set(Period.custom(range.start, range.end));
  } else {
    notifier.set(Period.of(picked));
  }
}
