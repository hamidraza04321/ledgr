import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _isCurrent {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final categories = (ref.watch(categoriesProvider).value ?? const <Category>[])
        .where((c) => c.type == TxnType.expense)
        .toList();
    final spent = ref.watch(monthSpendingProvider(_month)).value ?? const {};

    final budgeted = categories.where((c) => c.hasBudget).toList()
      ..sort((a, b) => ((spent[b.id] ?? 0) / b.budget!)
          .compareTo((spent[a.id] ?? 0) / a.budget!));
    final others = categories.where((c) => !c.hasBudget).toList();

    final totalBudget = budgeted.fold<double>(0, (a, c) => a + c.budget!);
    final totalSpent = budgeted.fold<double>(0, (a, c) => a + (spent[c.id] ?? 0));
    final progress = totalBudget == 0 ? 0.0 : totalSpent / totalBudget;
    final now = DateTime.now();
    final daysLeft = _isCurrent
        ? DateTime(now.year, now.month + 1).difference(dateOnly(now)).inDays
        : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  DateLabels.monthYear(_month),
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium,
                ),
              ),
              IconButton(
                onPressed: _isCurrent
                    ? null
                    : () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monthly budget',
                    style: context.text.labelLarge
                        ?.copyWith(color: context.colors.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(currency.format(totalBudget),
                    style: context.text.headlineSmall),
                const SizedBox(height: 14),
                ProgressBar(
                  value: progress,
                  height: 10,
                  color: _barColor(context, progress),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'Spent',
                        value: currency.format(totalSpent),
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: totalSpent > totalBudget ? 'Over by' : 'Left',
                        value: currency.format((totalBudget - totalSpent).abs()),
                        color: totalSpent > totalBudget
                            ? context.palette.expense
                            : context.palette.income,
                      ),
                    ),
                    if (_isCurrent)
                      Expanded(
                        child: _Stat(
                          label: 'Days left',
                          value: '$daysLeft',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (budgeted.isEmpty)
            const AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.savings_rounded,
                title: 'No budgets yet',
                message: 'Set a monthly limit on any category below. '
                    'Ledgr warns you in chat when you get close.',
              ),
            )
          else ...[
            const SectionHeader('Your budgets'),
            for (final c in budgeted)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BudgetCard(
                  category: c,
                  spent: spent[c.id] ?? 0,
                  onTap: () => _editBudget(c),
                ),
              ),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: 10),
            const SectionHeader('Other categories'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final c in others)
                    ListTile(
                      leading: IconBadge(
                          icon: categoryIcon(c.icon),
                          color: Color(c.color),
                          size: 38),
                      title: Text(c.name, style: context.text.titleSmall),
                      subtitle: Text(
                        '${currency.format(spent[c.id] ?? 0)} spent',
                        style: context.text.bodySmall
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                      trailing: TextButton(
                        onPressed: () => _editBudget(c),
                        child: const Text('Set budget'),
                      ),
                      onTap: () => _editBudget(c),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editBudget(Category c) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _BudgetDialog(category: c),
    );
    if (result == null) return;
    await ref
        .read(categoryRepoProvider)
        .setBudget(c.id, result <= 0 ? null : result);
  }
}

/// Pops the new limit, or `<= 0` to remove it. Keep the pops typed `<double>`:
/// an untyped `pop(ctx, -1)` sends an `int`, which throws mid-pop.
class _BudgetDialog extends ConsumerStatefulWidget {
  const _BudgetDialog({required this.category});

  final Category category;

  @override
  ConsumerState<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends ConsumerState<_BudgetDialog> {
  late final _amount = TextEditingController(
    text: widget.category.hasBudget
        ? widget.category.budget!.toStringAsFixed(0)
        : '',
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final currency = ref.watch(currencyProvider);
    return AlertDialog(
      title: Text('${c.name} budget'),
      content: TextField(
        controller: _amount,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          prefixText: '${currency.symbol} ',
          hintText: 'Monthly limit',
        ),
      ),
      actions: [
        if (c.hasBudget)
          TextButton(
            onPressed: () => Navigator.pop<double>(context, -1),
            child: Text('Remove',
                style: TextStyle(color: context.palette.expense)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop<double>(
              context, double.tryParse(_amount.text.trim()) ?? 0),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Color _barColor(BuildContext context, double progress) => progress >= 1
    ? context.palette.expense
    : progress >= 0.8
        ? context.palette.warning
        : context.palette.income;

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: context.text.labelSmall
                ?.copyWith(color: context.colors.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: context.text.titleSmall?.copyWith(color: color)),
      ],
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({
    required this.category,
    required this.spent,
    required this.onTap,
  });

  final Category category;
  final double spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final budget = category.budget!;
    final progress = spent / budget;
    final over = spent > budget;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: categoryIcon(category.icon),
                color: Color(category.color),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name, style: context.text.titleSmall),
                    Text(
                      '${currency.format(spent)} of ${currency.format(budget)}',
                      style: context.text.bodySmall
                          ?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: context.text.titleSmall
                    ?.copyWith(color: _barColor(context, progress)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(value: progress, color: _barColor(context, progress)),
          const SizedBox(height: 8),
          Text(
            over
                ? '${currency.format(spent - budget)} over budget'
                : '${currency.format(budget - spent)} left',
            style: context.text.labelMedium?.copyWith(
              color: over ? context.palette.expense : context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
