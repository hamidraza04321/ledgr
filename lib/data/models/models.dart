import 'dart:convert';

enum TxnType {
  income,
  expense,
  transfer;

  static TxnType parse(Object? s) => TxnType.values.firstWhere(
        (t) => t.name == s,
        orElse: () => TxnType.expense,
      );

  String get label => switch (this) {
        TxnType.income => 'Income',
        TxnType.expense => 'Expense',
        TxnType.transfer => 'Transfer',
      };
}

const kOtherExpenseId = 'exp_other';
const kOtherIncomeId = 'inc_other';
const kCashWalletId = 'wallet_cash';

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
double _double(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;

List<String> splitKeywords(String raw) => raw
    .split(',')
    .map((k) => k.trim().toLowerCase())
    .where((k) => k.isNotEmpty)
    .toList();

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.keywords = const [],
    this.budget,
    this.sortOrder = 0,
    this.updatedAt = 0,
  });

  final String id;
  final String name;
  final TxnType type;
  final String icon;
  final int color;
  final List<String> keywords;

  /// Monthly limit (expense categories only).
  final double? budget;
  final int sortOrder;
  final int updatedAt;

  bool get isFallback => id == kOtherExpenseId || id == kOtherIncomeId;
  bool get hasBudget => budget != null && budget! > 0;

  factory Category.fromRow(Map<String, Object?> r) => Category(
        id: r['id'] as String,
        name: r['name'] as String? ?? '',
        type: TxnType.parse(r['type']),
        icon: r['icon'] as String? ?? 'category',
        color: _int(r['color'], 0xFF64748B),
        keywords: splitKeywords(r['keywords'] as String? ?? ''),
        budget: r['budget'] == null ? null : _double(r['budget']),
        sortOrder: _int(r['sort_order']),
        updatedAt: _int(r['updated_at']),
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'type': type.name,
        'icon': icon,
        'color': color,
        'keywords': keywords.join(','),
        'budget': budget,
        'sort_order': sortOrder,
        'updated_at': updatedAt,
      };

  Category copyWith({
    String? name,
    TxnType? type,
    String? icon,
    int? color,
    List<String>? keywords,
    double? Function()? budget,
    int? sortOrder,
  }) =>
      Category(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        keywords: keywords ?? this.keywords,
        budget: budget != null ? budget() : this.budget,
        sortOrder: sortOrder ?? this.sortOrder,
        updatedAt: updatedAt,
      );
}

class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.openingBalance = 0,
    this.sortOrder = 0,
    this.updatedAt = 0,
  });

  final String id;
  final String name;
  final String icon;
  final int color;
  final double openingBalance;
  final int sortOrder;
  final int updatedAt;

  factory Wallet.fromRow(Map<String, Object?> r) => Wallet(
        id: r['id'] as String,
        name: r['name'] as String? ?? '',
        icon: r['icon'] as String? ?? 'wallet',
        color: _int(r['color'], 0xFF5B4CF0),
        openingBalance: _double(r['opening_balance']),
        sortOrder: _int(r['sort_order']),
        updatedAt: _int(r['updated_at']),
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'opening_balance': openingBalance,
        'sort_order': sortOrder,
        'updated_at': updatedAt,
      };

  Wallet copyWith({
    String? name,
    String? icon,
    int? color,
    double? openingBalance,
    int? sortOrder,
  }) =>
      Wallet(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        openingBalance: openingBalance ?? this.openingBalance,
        sortOrder: sortOrder ?? this.sortOrder,
        updatedAt: updatedAt,
      );
}

/// Where an entry came from.
class TxnSource {
  static const manual = 'manual';
  static const chat = 'chat';
  static const ai = 'ai';
}

class Txn {
  const Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.walletId,
    required this.date,
    this.categoryId,
    this.toWalletId,
    this.note = '',
    this.source = TxnSource.manual,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.deleted = false,
  });

  final String id;
  final TxnType type;
  final double amount;
  final String? categoryId;
  final String walletId;
  final String? toWalletId;
  final String note;
  final DateTime date;
  final String source;
  final int createdAt;
  final int updatedAt;
  final bool deleted;

  /// Signed effect on the overall balance.
  double get signedAmount => switch (type) {
        TxnType.income => amount,
        TxnType.expense => -amount,
        TxnType.transfer => 0,
      };

  factory Txn.fromRow(Map<String, Object?> r) => Txn(
        id: r['id'] as String,
        type: TxnType.parse(r['type']),
        amount: _double(r['amount']),
        categoryId: r['category_id'] as String?,
        walletId: r['wallet_id'] as String? ?? kCashWalletId,
        toWalletId: r['to_wallet_id'] as String?,
        note: r['note'] as String? ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(_int(r['date'])),
        source: r['source'] as String? ?? TxnSource.manual,
        createdAt: _int(r['created_at']),
        updatedAt: _int(r['updated_at']),
        deleted: _int(r['deleted']) == 1,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'category_id': type == TxnType.transfer ? null : categoryId,
        'wallet_id': walletId,
        'to_wallet_id': type == TxnType.transfer ? toWalletId : null,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'source': source,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Txn copyWith({
    TxnType? type,
    double? amount,
    String? Function()? categoryId,
    String? walletId,
    String? Function()? toWalletId,
    String? note,
    DateTime? date,
    String? source,
  }) =>
      Txn(
        id: id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        walletId: walletId ?? this.walletId,
        toWalletId: toWalletId != null ? toWalletId() : this.toWalletId,
        note: note ?? this.note,
        date: date ?? this.date,
        source: source ?? this.source,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deleted: deleted,
      );
}

enum ChatRole { user, bot }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.txnIds = const [],
    this.meta = const {},
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;
  final List<String> txnIds;

  /// Bot extras: `ai` (bool), `undone` (bool), `warnings` (list), `skipped` (list).
  final Map<String, dynamic> meta;

  bool get usedAi => meta['ai'] == true;
  bool get undone => meta['undone'] == true;
  List<String> get warnings =>
      (meta['warnings'] as List?)?.cast<String>() ?? const [];
  List<String> get skipped =>
      (meta['skipped'] as List?)?.cast<String>() ?? const [];

  factory ChatMessage.fromRow(Map<String, Object?> r) {
    final ids = r['txn_ids'] as String? ?? '';
    final meta = r['meta'] as String?;
    return ChatMessage(
      id: r['id'] as String,
      role: r['role'] == 'user' ? ChatRole.user : ChatRole.bot,
      text: r['text'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(_int(r['created_at'])),
      txnIds: ids.isEmpty ? const [] : ids.split(','),
      meta: meta == null || meta.isEmpty
          ? const {}
          : (jsonDecode(meta) as Map).cast<String, dynamic>(),
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'role': role.name,
        'text': text,
        'created_at': createdAt.millisecondsSinceEpoch,
        'txn_ids': txnIds.join(','),
        'meta': meta.isEmpty ? null : jsonEncode(meta),
      };
}

class Totals {
  const Totals({this.income = 0, this.expense = 0});

  final double income;
  final double expense;

  double get net => income - expense;
}

class CategoryTotal {
  const CategoryTotal(this.categoryId, this.total, this.count);

  final String? categoryId;
  final double total;
  final int count;
}

/// Minimal row used for charts.
class AmountPoint {
  const AmountPoint(this.date, this.type, this.amount);

  final DateTime date;
  final TxnType type;
  final double amount;
}
