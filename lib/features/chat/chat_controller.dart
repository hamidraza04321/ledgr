import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/period.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../services/parser/parse_models.dart';

final chatControllerProvider = Provider((ref) => ChatController(ref));

class ChatController {
  ChatController(this.ref);

  final Ref ref;
  static const _uuid = Uuid();

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty) return;
    final chat = ref.read(chatRepoProvider);
    final busy = ref.read(chatBusyProvider.notifier);

    await chat.add(ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      text: message,
      createdAt: DateTime.now(),
    ));

    busy.set(true);
    try {
      final ctx = await _context();
      final settings = ref.read(settingsProvider);
      final firebaseReady = ref.read(firebaseReadyProvider);
      final connectivity = ref.read(connectivityProvider);

      final result = await ref.read(entryParserProvider).parse(
            message,
            ctx,
            aiAllowed: () async =>
                firebaseReady &&
                settings.aiEnabled &&
                await connectivity.isOnline(),
          );

      final now = DateTime.now();
      final txns = [
        for (final e in result.entries)
          Txn(
            id: _uuid.v4(),
            type: e.type,
            amount: e.amount,
            categoryId: e.categoryId,
            walletId: e.walletId,
            note: e.note,
            date: DateTime(e.date.year, e.date.month, e.date.day, now.hour,
                now.minute, now.second),
            source: result.usedAi ? TxnSource.ai : TxnSource.chat,
          ),
      ];
      await ref.read(txnRepoProvider).addAll(txns);
      final warnings = await _budgetWarnings(txns, ctx);

      await chat.add(ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.bot,
        text: _reply(result, txns.length),
        createdAt: DateTime.now(),
        txnIds: [for (final t in txns) t.id],
        meta: {
          if (result.usedAi) 'ai': true,
          if (warnings.isNotEmpty) 'warnings': warnings,
          if (result.skipped.isNotEmpty) 'skipped': result.skipped,
        },
      ));
    } catch (e, st) {
      debugPrint('Chat send failed: $e\n$st');
      await chat.add(ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.bot,
        text: 'Something went wrong while saving that. Please try again.',
        createdAt: DateTime.now(),
      ));
    } finally {
      busy.set(false);
    }
  }

  Future<void> undo(ChatMessage message) async {
    await ref.read(txnRepoProvider).softDelete(message.txnIds);
    await ref
        .read(chatRepoProvider)
        .updateMeta(message.id, {...message.meta, 'undone': true});
  }

  Future<void> clear() => ref.read(chatRepoProvider).clear();

  Future<ParseContext> _context() async {
    final categories = await ref.read(categoryRepoProvider).getAll();
    final wallets = await ref.read(walletRepoProvider).getAll();
    final learned = await ref.read(keywordRepoProvider).getAll();
    final preferred = ref.read(settingsProvider).defaultWalletId;
    final defaultWallet = wallets.any((w) => w.id == preferred)
        ? preferred
        : (wallets.isEmpty ? kCashWalletId : wallets.first.id);
    return ParseContext(
      categories: categories,
      wallets: wallets,
      defaultWalletId: defaultWallet,
      now: DateTime.now(),
      learned: learned,
    );
  }

  String _reply(ParseResult result, int count) {
    if (count == 0) {
      return result.skipped.isEmpty
          ? "I couldn't find an amount in that. Try something like "
              '"500 ka petrol" or "Salary 80000 mili".'
          : "I couldn't find an amount in that. Add a number, "
              'e.g. "${result.skipped.first} 500".';
    }
    return count == 1 ? 'Added 1 entry' : 'Added $count entries';
  }

  Future<List<String>> _budgetWarnings(
      List<Txn> txns, ParseContext ctx) async {
    final currency = ref.read(currencyProvider);
    final byId = {for (final c in ctx.categories) c.id: c};
    final checked = <String>{};
    final warnings = <String>[];

    for (final t in txns) {
      final c = byId[t.categoryId];
      if (t.type != TxnType.expense || c == null || !c.hasBudget) continue;
      final key = '${c.id}_${t.date.year}_${t.date.month}';
      if (!checked.add(key)) continue;

      final span = Period.of(PeriodKind.month, anchor: t.date).span;
      final spent =
          (await ref.read(txnRepoProvider).spentByCategory(span))[c.id] ?? 0;
      final pct = spent / c.budget!;
      if (pct >= 1) {
        warnings.add('Over budget on ${c.name}: '
            '${currency.format(spent)} of ${currency.format(c.budget!)}');
      } else if (pct >= 0.8) {
        warnings.add('${c.name}: ${(pct * 100).round()}% of monthly budget used');
      }
    }
    return warnings;
  }
}
