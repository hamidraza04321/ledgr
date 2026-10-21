import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/icons.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/dates.dart';
import '../data/models/models.dart';
import '../features/transactions/txn_form_sheet.dart';
import '../providers/providers.dart';
import 'common.dart';

class TxnTile extends ConsumerWidget {
  const TxnTile(
    this.txn, {
    super.key,
    this.showDate = false,
    this.dense = false,
  });

  final Txn txn;
  final bool showDate;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoryMapProvider);
    final wallets = ref.watch(walletMapProvider);
    final currency = ref.watch(currencyProvider);

    final isTransfer = txn.type == TxnType.transfer;
    final category =
        isTransfer ? null : resolveCategory(cats, txn.categoryId, txn.type);
    final wallet = wallets[txn.walletId]?.name ?? 'Wallet';

    final title = txn.note.isNotEmpty
        ? txn.note
        : isTransfer
            ? 'Transfer'
            : category!.name;
    final subtitleParts = <String>[
      if (isTransfer)
        '$wallet → ${wallets[txn.toWalletId]?.name ?? 'Wallet'}'
      else ...[
        if (txn.note.isNotEmpty) category!.name,
        wallet,
      ],
      if (showDate) DateLabels.shortDay(txn.date),
    ];

    final color = typeColor(context, txn.type);
    final amount = switch (txn.type) {
      TxnType.income => '+${currency.format(txn.amount)}',
      TxnType.expense => '-${currency.format(txn.amount)}',
      TxnType.transfer => currency.format(txn.amount),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showTxnForm(context, txn: txn),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 8 : 10),
        child: Row(
          children: [
            IconBadge(
              icon: isTransfer
                  ? Icons.swap_horiz_rounded
                  : categoryIcon(category!.icon),
              color: isTransfer ? context.palette.transfer : Color(category!.color),
              size: dense ? 40 : 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              style: context.text.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
