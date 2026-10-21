import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../data/models/models.dart';
import 'parse_models.dart';

/// Gemini (Firebase AI Logic) fallback for messages the offline parser
/// could not fully understand.
class AiParser {
  AiParser({this.modelName = AppConfig.aiModel});

  final String modelName;

  Future<ParseResult> parse(String message, ParseContext ctx) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: modelName,
      systemInstruction: Content.system(_instructions(ctx)),
      generationConfig: GenerationConfig(
        temperature: 0,
        responseMimeType: 'application/json',
        responseSchema: _schema(ctx),
      ),
    );
    final response = await model.generateContent([Content.text(message)]);
    final raw = response.text;
    if (raw == null || raw.trim().isEmpty) return const ParseResult();
    return _decode(raw, ctx);
  }

  Schema _schema(ParseContext ctx) => Schema.object(properties: {
        'entries': Schema.array(
          items: Schema.object(
            properties: {
              'amount': Schema.number(
                  description: 'Positive amount of money for this entry.'),
              'type': Schema.enumString(enumValues: ['income', 'expense']),
              'categoryId': Schema.enumString(
                enumValues: [for (final c in ctx.categories) c.id],
              ),
              'walletId': Schema.enumString(
                enumValues: [for (final w in ctx.wallets) w.id],
              ),
              'note': Schema.string(
                description: "1-4 word item description in the user's words, "
                    'e.g. "Petrol", "Biscuit", "Bijli bill".',
              ),
              'date': Schema.string(description: 'YYYY-MM-DD'),
            },
            propertyOrdering: [
              'amount', 'type', 'categoryId', 'walletId', 'note', 'date',
            ],
          ),
        ),
      });

  String _instructions(ParseContext ctx) {
    final today = DateFormat('yyyy-MM-dd (EEEE)').format(ctx.now);
    final categories = ctx.categories.map((c) {
      final kw = c.keywords.take(12).join(', ');
      return '- ${c.id}: ${c.name} [${c.type.name}]${kw.isEmpty ? '' : ' e.g. $kw'}';
    }).join('\n');
    final wallets = ctx.wallets.map((w) => '- ${w.id}: ${w.name}').join('\n');
    return '''
You turn short chat messages into income/expense entries for a personal finance app.
Users write Roman Urdu, Urdu or English, often mixed. Today is $today.

Rules:
- Every item with its own amount is a separate entry. Never invent entries without an amount.
- Amount words: "k" = thousand, "hazar/hazaar" = thousand, "lakh/lac" = 100000, "sau" = hundred, "dhai sau" = 250, "derh" = 1.5x.
- Dates: "aj/aaj" = today, "kal" = yesterday, "parson" = 2 days ago, "N din pehle" = N days ago. A line that only states a date applies to every entry. Default is today.
- Income words: mila/mili/mile, aaye/aayi, received, salary, tankhwah, credited. Expense words: diya/diye, liya, kharcha, paid, bought, or simply naming something bought.
- Pick the closest category of the right type; use $kOtherExpenseId or $kOtherIncomeId only if nothing fits.
- Use the wallet the user names ("cash se", "bank", "jazzcash"); otherwise ${ctx.defaultWalletId}.

Categories:
$categories

Wallets:
$wallets
''';
  }

  ParseResult _decode(String raw, ParseContext ctx) {
    final json = jsonDecode(raw);
    final list = json is Map ? json['entries'] : null;
    if (list is! List) return const ParseResult(usedAi: true);

    final byId = {for (final c in ctx.categories) c.id: c};
    final walletIds = {for (final w in ctx.wallets) w.id};
    final today = DateTime(ctx.now.year, ctx.now.month, ctx.now.day);
    final entries = <ParsedEntry>[];

    for (final item in list.whereType<Map>()) {
      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
      if (amount <= 0) continue;
      final type = item['type'] == 'income' ? TxnType.income : TxnType.expense;
      var category = byId[item['categoryId']];
      if (category == null || category.type != type) {
        category = byId[type == TxnType.income ? kOtherIncomeId : kOtherExpenseId] ??
            ctx.categories.firstWhere((c) => c.type == type);
      }
      final walletId = walletIds.contains(item['walletId'])
          ? item['walletId'] as String
          : ctx.defaultWalletId;
      var date = DateTime.tryParse('${item['date']}') ?? today;
      date = DateTime(date.year, date.month, date.day);
      if (date.isAfter(today) || today.difference(date).inDays > 3650) {
        date = today;
      }
      entries.add(ParsedEntry(
        amount: amount,
        type: category.type,
        categoryId: category.id,
        walletId: walletId,
        note: '${item['note'] ?? ''}'.trim(),
        date: date,
      ));
    }
    return ParseResult(entries: entries, usedAi: true);
  }
}
