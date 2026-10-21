import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../services/parser/offline_parser.dart';
import '../../widgets/common.dart';

Future<void> showTxnForm(
  BuildContext context, {
  Txn? txn,
  TxnType initialType = TxnType.expense,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TxnFormSheet(txn: txn, initialType: initialType),
  );
}

class TxnFormSheet extends ConsumerStatefulWidget {
  const TxnFormSheet({super.key, this.txn, this.initialType = TxnType.expense});

  final Txn? txn;
  final TxnType initialType;

  @override
  ConsumerState<TxnFormSheet> createState() => _TxnFormSheetState();
}

class _TxnFormSheetState extends ConsumerState<TxnFormSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late TxnType _type;
  String? _categoryId;
  String? _walletId;
  String? _toWalletId;
  late DateTime _date;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.txn != null;

  @override
  void initState() {
    super.initState();
    final t = widget.txn;
    if (t != null) {
      _type = t.type;
      _amount.text = _trimAmount(t.amount);
      _note.text = t.note;
      _categoryId = t.categoryId;
      _walletId = t.walletId;
      _toWalletId = t.toWalletId;
      _date = t.date;
    } else {
      _type = widget.initialType;
      _walletId = ref.read(defaultWalletIdProvider);
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  static String _trimAmount(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final categories = (ref.watch(categoriesProvider).value ?? const <Category>[])
        .where((c) => c.type == _type)
        .toList();
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final color = typeColor(context, _type);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        // Bottom sheets don't avoid the system navigation bar on their own.
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? 'Edit entry' : 'New entry',
                    style: context.text.titleLarge,
                  ),
                ),
                if (_editing)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline_rounded,
                        color: context.palette.expense),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<TxnType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: TxnType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward_rounded, size: 18),
                ),
                ButtonSegment(
                  value: TxnType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward_rounded, size: 18),
                ),
                ButtonSegment(
                  value: TxnType.transfer,
                  label: Text('Transfer'),
                  icon: Icon(Icons.swap_horiz_rounded, size: 18),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _error = null;
                final cats = ref.read(categoryMapProvider);
                if (cats[_categoryId]?.type != _type) _categoryId = null;
              }),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Text(
                    currency.symbol,
                    style: context.text.headlineSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      autofocus: !_editing,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: context.text.headlineMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_type != TxnType.transfer) ...[
              _Label('Category'),
              _CategoryGrid(
                categories: categories,
                selected: _categoryId,
                onSelect: (id) => setState(() {
                  _categoryId = id;
                  _error = null;
                }),
              ),
              const SizedBox(height: 18),
              _Label('Wallet'),
              _WalletDropdown(
                wallets: wallets,
                value: _walletId,
                onChanged: (v) => setState(() => _walletId = v),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('From'),
                        _WalletDropdown(
                          wallets: wallets,
                          value: _walletId,
                          onChanged: (v) => setState(() => _walletId = v),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: context.colors.onSurfaceVariant),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('To'),
                        _WalletDropdown(
                          wallets: wallets,
                          value: _toWalletId,
                          onChanged: (v) => setState(() => _toWalletId = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Date'),
                      Material(
                        color: Theme.of(context).inputDecorationTheme.fillColor,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _pickDate,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 15),
                            child: Row(
                              children: [
                                Icon(Icons.event_rounded,
                                    size: 20, color: context.colors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    DateLabels.relativeDay(_date),
                                    style: context.text.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Label('Note'),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Petrol, Biscuit, Bijli bill',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.palette.expense)),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_editing ? 'Save changes' : 'Add entry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day,
          _date.hour, _date.minute, _date.second));
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    String? error;
    if (amount <= 0) {
      error = 'Enter an amount.';
    } else if (_type != TxnType.transfer && _categoryId == null) {
      error = 'Pick a category.';
    } else if (_walletId == null) {
      error = 'Pick a wallet.';
    } else if (_type == TxnType.transfer &&
        (_toWalletId == null || _toWalletId == _walletId)) {
      error = 'Choose two different wallets.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(txnRepoProvider);
    final note = _note.text.trim();
    final original = widget.txn;

    if (original == null) {
      await repo.add(Txn(
        id: const Uuid().v4(),
        type: _type,
        amount: amount,
        categoryId: _type == TxnType.transfer ? null : _categoryId,
        walletId: _walletId!,
        toWalletId: _type == TxnType.transfer ? _toWalletId : null,
        note: note,
        date: _date,
      ));
    } else {
      await repo.update(original.copyWith(
        type: _type,
        amount: amount,
        categoryId: () => _type == TxnType.transfer ? null : _categoryId,
        walletId: _walletId,
        toWalletId: () => _type == TxnType.transfer ? _toWalletId : null,
        note: note,
        date: _date,
      ));
      // Teach the chat parser when a chat entry is re-categorised.
      final recategorised = original.source != TxnSource.manual &&
          _categoryId != null &&
          _categoryId != original.categoryId;
      if (recategorised) {
        final words = OfflineParser.learnableWords(note);
        if (words.isNotEmpty) {
          await ref.read(keywordRepoProvider).learn(words, _categoryId!);
        }
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final txn = widget.txn!;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(txnRepoProvider);
    await repo.softDelete([txn.id]);
    if (!mounted) return;
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.restore([txn.id]),
        ),
      ));
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text,
          style: context.text.labelLarge
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      );
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<Category> categories;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const spacing = 8.0;
      final columns = box.maxWidth > 480 ? 6 : 4;
      final width = (box.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final c in categories)
            SizedBox(
              width: width,
              child: _CategoryChoice(
                category: c,
                selected: c.id == selected,
                onTap: () => onSelect(c.id),
              ),
            ),
        ],
      );
    });
  }
}

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = context.text.labelSmall?.copyWith(
      height: 1.15,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    return Material(
      color: selected
          ? color.withValues(alpha: 0.14)
          : dark
              ? context.colors.surfaceContainerHigh
              : context.colors.surfaceContainer.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? color : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              Icon(categoryIcon(category.icon), color: color, size: 24),
              const SizedBox(height: 6),
              // Fixed two-line slot keeps every tile the same height.
              SizedBox(
                height: 28,
                child: Center(
                  // Single long words shrink instead of breaking mid-word.
                  child: category.name.trim().contains(' ')
                      ? Text(
                          category.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: labelStyle,
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(category.name,
                              maxLines: 1, style: labelStyle),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletDropdown extends StatelessWidget {
  const _WalletDropdown({
    required this.wallets,
    required this.value,
    required this.onChanged,
  });

  final List<Wallet> wallets;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final valid = wallets.any((w) => w.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('wallet_${valid}_${wallets.length}'),
      initialValue: valid,
      isExpanded: true,
      borderRadius: BorderRadius.circular(14),
      hint: const Text('Select'),
      items: [
        for (final w in wallets)
          DropdownMenuItem(
            value: w.id,
            child: Row(
              children: [
                Icon(walletIcon(w.icon), size: 20, color: Color(w.color)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(w.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
