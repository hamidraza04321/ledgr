import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/icons.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../categories/categories_screen.dart' show ColorPickerRow;
import '../transactions/txn_form_sheet.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final balances = ref.watch(walletBalancesProvider).value ?? const {};
    final total = ref.watch(totalBalanceProvider) ?? 0;
    final currency = ref.watch(currencyProvider);
    final defaultId = ref.watch(defaultWalletIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
        actions: [
          if (wallets.length > 1)
            TextButton.icon(
              onPressed: () =>
                  showTxnForm(context, initialType: TxnType.transfer),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Transfer'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-wallet',
        onPressed: () => showWalletForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Wallet'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 4, 16, 96 + MediaQuery.paddingOf(context).bottom),
        children: [
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                IconBadge(
                  icon: Icons.account_balance_wallet_rounded,
                  color: context.colors.primary,
                  size: 48,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total balance',
                        style: context.text.labelLarge
                            ?.copyWith(color: context.colors.onSurfaceVariant)),
                    Text(currency.format(total),
                        style: context.text.headlineSmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final w in wallets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () => showWalletForm(context, wallet: w),
                child: Row(
                  children: [
                    IconBadge(icon: walletIcon(w.icon), color: Color(w.color)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(w.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.titleSmall),
                              ),
                              if (w.id == defaultId) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: context.colors.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Default',
                                      style: context.text.labelSmall?.copyWith(
                                          color: context.colors.primary)),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Opening ${currency.format(w.openingBalance)}',
                            style: context.text.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      currency.format(balances[w.id] ?? 0),
                      style: context.text.titleMedium?.copyWith(
                        color: (balances[w.id] ?? 0) < 0
                            ? context.palette.expense
                            : null,
                      ),
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

Future<void> showWalletForm(BuildContext context, {Wallet? wallet}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WalletForm(wallet: wallet),
  );
}

class _WalletForm extends ConsumerStatefulWidget {
  const _WalletForm({this.wallet});

  final Wallet? wallet;

  @override
  ConsumerState<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends ConsumerState<_WalletForm> {
  late final _name = TextEditingController(text: widget.wallet?.name ?? '');
  late final _opening = TextEditingController(
    text: widget.wallet == null || widget.wallet!.openingBalance == 0
        ? ''
        : widget.wallet!.openingBalance.toStringAsFixed(0),
  );
  late String _icon = widget.wallet?.icon ?? 'wallet';
  late int _color = widget.wallet?.color ?? kColorChoices[9];
  late bool _makeDefault =
      widget.wallet != null && ref.read(defaultWalletIdProvider) == widget.wallet!.id;
  String? _error;

  static const _presets = [
    ('JazzCash', 'mobile', 0xFFE5484D),
    ('Easypaisa', 'mobile', 0xFF22C55E),
    ('Credit card', 'card', 0xFF6366F1),
    ('Savings', 'savings', 0xFFF59E0B),
  ];

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.wallet != null;
    final currency = ref.watch(currencyProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(icon: walletIcon(_icon), color: Color(_color), size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(editing ? 'Edit wallet' : 'New wallet',
                      style: context.text.titleLarge),
                ),
                if (editing)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline_rounded,
                        color: context.palette.expense),
                  ),
              ],
            ),
            if (!editing) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (name, icon, color) in _presets)
                    ActionChip(
                      avatar: Icon(walletIcon(icon), size: 18, color: Color(color)),
                      label: Text(name),
                      onPressed: () => setState(() {
                        _name.text = name;
                        _icon = icon;
                        _color = color;
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _opening,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
              ],
              decoration: InputDecoration(
                labelText: 'Opening balance',
                helperText: 'Money already in this wallet before using Ledgr',
                prefixText: '${currency.symbol} ',
              ),
            ),
            const SizedBox(height: 16),
            Text('Icon', style: context.text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in kWalletIcons.entries)
                  ChoiceChip(
                    selected: e.key == _icon,
                    label: Icon(e.value,
                        size: 22,
                        color: e.key == _icon
                            ? Color(_color)
                            : context.colors.onSurfaceVariant),
                    onSelected: (_) => setState(() => _icon = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Color', style: context.text.labelLarge),
            const SizedBox(height: 8),
            ColorPickerRow(
              selected: _color,
              onSelect: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _makeDefault,
              onChanged: (v) => setState(() => _makeDefault = v),
              title: const Text('Default wallet'),
              subtitle: const Text('Used for chat entries unless you name a wallet'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: context.palette.expense)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(editing ? 'Save changes' : 'Add wallet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    final repo = ref.read(walletRepoProvider);
    final opening = double.tryParse(_opening.text.trim()) ?? 0;
    final existing = widget.wallet;
    final w = existing != null
        ? existing.copyWith(
            name: name, icon: _icon, color: _color, openingBalance: opening)
        : Wallet(
            id: const Uuid().v4(),
            name: name,
            icon: _icon,
            color: _color,
            openingBalance: opening,
            sortOrder: await repo.nextSortOrder(),
          );
    await repo.save(w);
    if (_makeDefault) ref.read(settingsProvider.notifier).setDefaultWallet(w.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final w = widget.wallet!;
    final repo = ref.read(walletRepoProvider);
    final wallets = ref.read(walletsProvider).value ?? const [];
    if (wallets.length <= 1) {
      setState(() => _error = 'You need at least one wallet.');
      return;
    }
    if (await repo.hasTransactions(w.id)) {
      setState(() => _error =
          'This wallet has entries. Move or delete them first.');
      return;
    }
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Delete "${w.name}"?',
      message: 'This wallet will be removed.',
    );
    if (!ok) return;
    await repo.delete(w.id);
    if (mounted) Navigator.pop(context);
  }
}
