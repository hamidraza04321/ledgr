import '../../data/models/models.dart';

class ParsedEntry {
  const ParsedEntry({
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.walletId,
    required this.note,
    required this.date,
    this.confident = true,
  });

  final double amount;
  final TxnType type;
  final String categoryId;
  final String walletId;
  final String note;

  /// Day of the entry (time is filled in when saving).
  final DateTime date;

  /// False when the offline parser had to guess.
  final bool confident;

  @override
  String toString() =>
      'ParsedEntry($amount, ${type.name}, $categoryId, $walletId, "$note", '
      '${date.toIso8601String().substring(0, 10)}, confident: $confident)';
}

class ParseResult {
  const ParseResult({
    this.entries = const [],
    this.skipped = const [],
    this.usedAi = false,
  });

  final List<ParsedEntry> entries;

  /// Message parts that had words but no amount.
  final List<String> skipped;
  final bool usedAi;

  bool get needsAi =>
      entries.isEmpty || skipped.isNotEmpty || entries.any((e) => !e.confident);
}

class ParseContext {
  const ParseContext({
    required this.categories,
    required this.wallets,
    required this.defaultWalletId,
    required this.now,
    this.learned = const {},
  });

  final List<Category> categories;
  final List<Wallet> wallets;
  final String defaultWalletId;
  final DateTime now;

  /// word → category id, taught by the user's corrections.
  final Map<String, String> learned;
}
