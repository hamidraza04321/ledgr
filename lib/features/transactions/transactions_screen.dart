import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/period_selector.dart';
import '../../widgets/txn_tile.dart';
import 'txn_form_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.categoryId, this.title});

  /// When set, shows only this category (opened from the dashboard).
  final String? categoryId;
  final String? title;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TxnType? _filter;
  bool _searching = false;
  final _search = TextEditingController();

  /// Swiped-away ids, hidden at once (the DB stream catches up a frame later).
  final _hidden = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(periodTxnsProvider);
    final cats = ref.watch(categoryMapProvider);
    final wallets = ref.watch(walletMapProvider);
    final currency = ref.watch(currencyProvider);
    final period = ref.watch(periodProvider);
    final query = _search.text.trim().toLowerCase();

    final all = txnsAsync.value ?? const <Txn>[];
    final txns = all.where((t) {
      if (_hidden.contains(t.id)) return false;
      if (widget.categoryId != null) {
        final resolved = resolveCategory(cats, t.categoryId, t.type).id;
        if (t.type == TxnType.transfer || resolved != widget.categoryId) {
          return false;
        }
      }
      if (_filter != null && t.type != _filter) return false;
      if (query.isEmpty) return true;
      final cat = resolveCategory(cats, t.categoryId, t.type).name;
      final hay = '${t.note} $cat ${wallets[t.walletId]?.name ?? ''} '
              '${t.amount.toStringAsFixed(0)}'
          .toLowerCase();
      return hay.contains(query);
    }).toList();

    var income = 0.0, expense = 0.0;
    for (final t in txns) {
      if (t.type == TxnType.income) income += t.amount;
      if (t.type == TxnType.expense) expense += t.amount;
    }

    // Group by day, newest first.
    final groups = <DateTime, List<Txn>>{};
    for (final t in txns) {
      groups.putIfAbsent(dateOnly(t.date), () => []).add(t);
    }
    final items = <Object>[];
    for (final e in groups.entries) {
      items.add(e.key);
      items.addAll(e.value);
    }

    final isCategoryView = widget.categoryId != null;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search notes, categories…',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              )
            : Text(widget.title ?? 'Transactions'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
          if (!isCategoryView)
            IconButton(
              tooltip: 'Add entry',
              onPressed: () => showTxnForm(context),
              icon: const Icon(Icons.add_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                const PeriodSelector(),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (income > 0 || !isCategoryView)
                      Text('+${currency.format(income, compact: true)}',
                          style: context.text.labelLarge
                              ?.copyWith(color: context.palette.income)),
                    if (expense > 0 || !isCategoryView)
                      Text('-${currency.format(expense, compact: true)}',
                          style: context.text.labelLarge
                              ?.copyWith(color: context.palette.expense)),
                  ],
                ),
              ],
            ),
          ),
          if (!isCategoryView)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (type, label) in <(TxnType?, String)>[
                    (null, 'All'),
                    (TxnType.expense, 'Expenses'),
                    (TxnType.income, 'Income'),
                    (TxnType.transfer, 'Transfers'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 4),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _filter == type,
                        onSelected: (_) => setState(() => _filter = type),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: txnsAsync.isLoading && all.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : txns.isEmpty
                    ? SingleChildScrollView(
                        child: EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: query.isNotEmpty
                              ? 'No matches'
                              : 'No entries ${period.phrase}',
                          message: query.isNotEmpty
                              ? 'Try a different word.'
                              : 'Tap the chat button and type something like '
                                  '"500 ka petrol".',
                        ),
                      )
                    : ListView.builder(
                        // Zero inside the home tabs; the nav bar inset when
                        // opened on its own from a category.
                        padding: EdgeInsets.fromLTRB(
                            8, 4, 8, 96 + MediaQuery.paddingOf(context).bottom),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          if (item is DateTime) {
                            return _DayHeader(day: item, txns: groups[item]!);
                          }
                          final t = item as Txn;
                          return _SwipeToDelete(
                            txn: t,
                            onDismissed: () => _delete(t),
                            child: TxnTile(t),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _delete(Txn t) {
    setState(() => _hidden.add(t.id));
    final repo = ref.read(txnRepoProvider);
    repo.softDelete([t.id]);
    showSnack(context, 'Entry deleted', actionLabel: 'Undo', onAction: () {
      repo.restore([t.id]);
      if (mounted) setState(() => _hidden.remove(t.id));
    });
  }
}

class _DayHeader extends ConsumerWidget {
  const _DayHeader({required this.day, required this.txns});

  final DateTime day;
  final List<Txn> txns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final net = txns.fold<double>(0, (a, t) => a + t.signedAmount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
      child: Row(
        children: [
          Text(
            DateLabels.relativeDay(day),
            style: context.text.labelLarge
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const Spacer(),
          if (net != 0)
            Text(
              currency.signed(net),
              style: context.text.labelMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _SwipeToDelete extends StatelessWidget {
  const _SwipeToDelete({
    required this.txn,
    required this.onDismissed,
    required this.child,
  });

  final Txn txn;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('txn_${txn.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: context.palette.expense.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline_rounded, color: context.palette.expense),
      ),
      onDismissed: (_) => onDismissed(),
      child: child,
    );
  }
}
