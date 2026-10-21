import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../transactions/txn_form_sheet.dart';
import 'chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty || ref.read(chatBusyProvider)) return;
    _input.clear();
    await ref.read(chatControllerProvider).send(text);
  }

  void _fill(String text) {
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider).value ?? const [];
    final busy = ref.watch(chatBusyProvider);
    final aiOn =
        ref.watch(firebaseReadyProvider) && ref.watch(settingsProvider).aiEnabled;

    // Oldest → newest with day separators, then reversed for the list.
    final items = <Object>[];
    DateTime? lastDay;
    for (final m in messages) {
      final day = dateOnly(m.createdAt);
      if (lastDay == null || day != lastDay) {
        items.add(day);
        lastDay = day;
      }
      items.add(m);
    }
    if (busy) items.add(const _Typing());
    final reversed = items.reversed.toList();

    return Scaffold(
      backgroundColor: context.palette.chatBackground,
      appBar: AppBar(
        backgroundColor: context.palette.card,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: context.palette.heroGradient),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ledgr Assistant', style: context.text.titleMedium),
                  Text(
                    busy
                        ? 'typing…'
                        : aiOn
                            ? 'Smart parser · Gemini assist on'
                            : 'Smart parser · works offline',
                    style: context.text.labelSmall?.copyWith(
                      color: busy
                          ? context.colors.primary
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'help') _showHelp(context);
              if (v == 'clear') {
                final ok = await confirmDialog(
                  context,
                  title: 'Clear chat?',
                  message:
                      'Messages are removed from this screen. Your entries stay saved.',
                  confirm: 'Clear',
                );
                if (ok) await ref.read(chatControllerProvider).clear();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'help', child: Text('How to type entries')),
              PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty && !busy
                ? _EmptyChat(onExample: _fill)
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: reversed.length,
                    itemBuilder: (context, i) {
                      final item = reversed[i];
                      if (item is DateTime) return _DayChip(day: item);
                      if (item is _Typing) return const _TypingBubble();
                      final m = item as ChatMessage;
                      return m.role == ChatRole.user
                          ? _UserBubble(message: m, onLongPress: () => _fill(m.text))
                          : _BotBubble(message: m);
                    },
                  ),
          ),
          _InputBar(
            controller: _input,
            focusNode: _focus,
            canSend: _input.text.trim().isNotEmpty && !busy,
            onSend: _send,
            onAdd: () => showTxnForm(context),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type it like a message', style: ctx.text.titleLarge),
              const SizedBox(height: 12),
              for (final (title, body) in const [
                ('One item per line', '100 ka petrol\n100 ka biscuit\naj ke din ka'),
                ('Income', 'Salary 85000 mili · 5k freelance se aaye'),
                ('Dates', 'kal, parson, 3 din pehle, 15/10, 3 oct'),
                ('Amounts', '2k = 2,000 · 5 hazar · 1.5 lakh · Rs 1,250'),
                ('Wallets', 'bank se 1200 ka bill · jazzcash se 500 ka load'),
                ('Fix a guess', 'Tap any card to change it. Ledgr remembers the word for next time.'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: ctx.text.titleSmall),
                      const SizedBox(height: 4),
                      Text(body,
                          style: ctx.text.bodyMedium?.copyWith(
                              color: ctx.colors.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Typing {
  const _Typing();
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: context.palette.card.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          DateLabels.relativeDay(day),
          style: context.text.labelSmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message, required this.onLongPress});

  final ChatMessage message;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.selectionClick();
          onLongPress();
        },
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          margin: const EdgeInsets.only(top: 4, bottom: 4, left: 48),
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 6),
          decoration: BoxDecoration(
            color: context.palette.bubbleOut,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message.text,
                  style: context.text.bodyLarge?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateLabels.time(message.createdAt),
                    style: context.text.labelSmall
                        ?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.done_all_rounded,
                      size: 14, color: Colors.white.withValues(alpha: 0.8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotBubble extends ConsumerWidget {
  const _BotBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final txnMap = message.txnIds.isEmpty
        ? const <String, Txn>{}
        : ref.watch(chatTxnsProvider(message.txnIds.join(','))).value ??
            const <String, Txn>{};
    final txns = [
      for (final id in message.txnIds)
        if (txnMap[id] != null) txnMap[id]!,
    ];
    final live = txns.where((t) => !t.deleted).toList();
    var spent = 0.0, received = 0.0;
    for (final t in live) {
      if (t.type == TxnType.expense) spent += t.amount;
      if (t.type == TxnType.income) received += t.amount;
    }
    final maxWidth = MediaQuery.sizeOf(context).width * 0.86;
    final muted = context.colors.onSurfaceVariant;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.only(top: 4, bottom: 4, right: 24),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        decoration: BoxDecoration(
          color: context.palette.bubbleIn,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (txns.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      message.undone
                          ? Icons.undo_rounded
                          : Icons.check_circle_rounded,
                      size: 18,
                      color: message.undone ? muted : context.palette.income,
                    ),
                  ),
                Flexible(
                  child: Text(
                    message.undone ? 'Undone' : message.text,
                    style: txns.isNotEmpty
                        ? context.text.titleSmall
                        : context.text.bodyLarge,
                  ),
                ),
              ],
            ),
            if (txns.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final t in txns) _EntryCard(txn: t),
              if (live.length > 1 && (spent > 0 || received > 0))
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 2),
                  child: Text(
                    [
                      if (spent > 0) '${currency.format(spent)} spent',
                      if (received > 0) '${currency.format(received)} received',
                    ].join(' · '),
                    style: context.text.labelMedium?.copyWith(color: muted),
                  ),
                ),
            ],
            for (final w in message.warnings)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: context.palette.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: context.palette.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(w, style: context.text.bodySmall),
                    ),
                  ],
                ),
              ),
            if (message.skipped.isNotEmpty && txns.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Skipped (no amount): ${message.skipped.map((s) => '"$s"').join(', ')}',
                  style: context.text.bodySmall?.copyWith(color: muted),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (message.usedAi)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 12, color: context.colors.primary),
                        const SizedBox(width: 3),
                        Text('Gemini',
                            style: context.text.labelSmall
                                ?.copyWith(color: context.colors.primary)),
                      ],
                    ),
                  ),
                Text(DateLabels.time(message.createdAt),
                    style: context.text.labelSmall?.copyWith(color: muted)),
                const Spacer(),
                if (!message.undone && live.isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        ref.read(chatControllerProvider).undo(message),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: const Text('Undo'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoryMapProvider);
    final wallets = ref.watch(walletMapProvider);
    final currency = ref.watch(currencyProvider);
    final defaultWallet = ref.watch(defaultWalletIdProvider);
    final c = resolveCategory(cats, txn.categoryId, txn.type);
    final color = typeColor(context, txn.type);
    final deleted = txn.deleted;
    final strike = deleted ? TextDecoration.lineThrough : null;
    final details = [
      c.name,
      if (txn.walletId != defaultWallet) wallets[txn.walletId]?.name ?? 'Wallet',
      DateLabels.shortDay(txn.date),
    ].join(' · ');

    return Opacity(
      opacity: deleted ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: Theme.of(context).brightness == Brightness.dark
              ? context.colors.surfaceContainerHighest.withValues(alpha: 0.55)
              : context.colors.surfaceContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: deleted ? null : () => showTxnForm(context, txn: txn),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconBadge(
                      icon: categoryIcon(c.icon), color: Color(c.color), size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          txn.note.isEmpty ? c.name : txn.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall
                              ?.copyWith(decoration: strike),
                        ),
                        Text(
                          deleted ? 'Removed' : details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                              color: context.colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${txn.type == TxnType.income ? '+' : '-'}${currency.format(txn.amount)}',
                    style: context.text.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      decoration: strike,
                    ),
                  ),
                  if (!deleted)
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: context.colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0→1→0 wave, offset per dot.
  double _pulse(int i) {
    final phase = (_c.value - i * 0.18) % 1.0;
    return phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.palette.bubbleIn,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.onSurfaceVariant
                        .withValues(alpha: 0.3 + 0.7 * _pulse(i)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onExample});

  final ValueChanged<String> onExample;

  static const _examples = [
    '100 ka petrol\n100 ka biscuit\naj ke din ka',
    'Salary 85000 mili',
    'kal 250 ka doodh',
    '2k ka ration aur 500 ki dawai',
    'bank se 4500 ka bijli bill',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: context.palette.heroGradient),
            ),
            child: const Icon(Icons.forum_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 18),
          Text('Just type it like a message',
              textAlign: TextAlign.center, style: context.text.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Ledgr turns your messages into entries. Roman Urdu or English, '
            'one item per line.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _examples)
                ActionChip(
                  label: Text(e.replaceAll('\n', ' · ')),
                  onPressed: () => onExample(e),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.onSend,
    required this.onAdd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.palette.card,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Add with form',
                      onPressed: onAdd,
                      icon: Icon(Icons.add_circle_outline_rounded,
                          color: context.colors.onSurfaceVariant),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: context.text.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 100 ka petrol',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.fromLTRB(0, 14, 12, 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: canSend ? 1 : 0.92,
              duration: const Duration(milliseconds: 150),
              child: SizedBox(
                width: 50,
                height: 50,
                child: FloatingActionButton(
                  heroTag: 'chat-send',
                  elevation: canSend ? 2 : 0,
                  shape: const CircleBorder(),
                  backgroundColor: canSend
                      ? context.colors.primary
                      : context.colors.primary.withValues(alpha: 0.45),
                  onPressed: canSend ? onSend : null,
                  child: const Icon(Icons.send_rounded, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
