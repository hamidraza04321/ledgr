import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/data/db/seed.dart';
import 'package:ledgr/data/models/models.dart';
import 'package:ledgr/services/parser/offline_parser.dart';
import 'package:ledgr/services/parser/parse_models.dart';

void main() {
  // Sunday, 19 Oct 2026, 3 PM.
  final now = DateTime(2026, 10, 19, 15);
  final today = DateTime(2026, 10, 19);
  final yesterday = DateTime(2026, 10, 18);

  ParseContext ctx({Map<String, String> learned = const {}}) => ParseContext(
        categories: defaultCategories(),
        wallets: [
          ...defaultWallets(),
          const Wallet(id: 'w_jazz', name: 'JazzCash', icon: 'mobile', color: 0),
        ],
        defaultWalletId: kCashWalletId,
        now: now,
        learned: learned,
      );

  const parser = OfflineParser();
  ParseResult parse(String s, {Map<String, String> learned = const {}}) =>
      parser.parse(s, ctx(learned: learned));

  test('the WhatsApp-style example from the brief', () {
    final r = parse('100 ka petrol\n100 ka biscuit\naj ke din ka');
    expect(r.entries, hasLength(2));
    expect(r.skipped, isEmpty);
    expect(r.entries[0].amount, 100);
    expect(r.entries[0].categoryId, 'exp_fuel');
    expect(r.entries[0].note, 'Petrol');
    expect(r.entries[0].type, TxnType.expense);
    expect(r.entries[0].date, today);
    expect(r.entries[1].categoryId, 'exp_food');
    expect(r.entries[1].note, 'Biscuit');
    expect(r.needsAi, isFalse);
  });

  test('income with strong hint', () {
    final r = parse('Salary 85000 mili');
    expect(r.entries.single.type, TxnType.income);
    expect(r.entries.single.categoryId, 'inc_salary');
    expect(r.entries.single.amount, 85000);
    expect(r.needsAi, isFalse);
  });

  test('kal + aur splitting carries the date', () {
    final r = parse('kal 250 ka doodh aur 120 ki bread');
    expect(r.entries, hasLength(2));
    expect(r.entries.every((e) => e.date == yesterday), isTrue);
    expect(r.entries.every((e) => e.categoryId == 'exp_grocery'), isTrue);
    expect(r.entries.map((e) => e.amount), [250, 120]);
  });

  test('k / hazar / lakh multipliers', () {
    expect(parse('2k ka ration').entries.single.amount, 2000);
    expect(parse('1.5k petrol').entries.single.amount, 1500);
    final f = parse('5 hazar freelance se mile').entries.single;
    expect(f.amount, 5000);
    expect(f.categoryId, 'inc_freelance');
    expect(parse('1 lakh profit mila').entries.single.amount, 100000);
  });

  test('currency prefix and thousands separators', () {
    final e = parse('Rs. 1,250 medicine').entries.single;
    expect(e.amount, 1250);
    expect(e.categoryId, 'exp_health');
    expect(parse('₨ 300 chai').entries.single.amount, 300);
    expect(parse('1,00,000 ki gari repair').entries.single.amount, 100000);
  });

  test('comma separated items', () {
    final r = parse('uber 650, careem 400');
    expect(r.entries.map((e) => e.categoryId), ['exp_transport', 'exp_transport']);
    expect(r.entries.map((e) => e.amount), [650, 400]);
  });

  test('several amounts on one line without separators', () {
    final a = parse('100 ka petrol 50 ki chai');
    expect(a.entries.map((e) => e.categoryId), ['exp_fuel', 'exp_food']);
    expect(a.entries.map((e) => e.amount), [100, 50]);

    final b = parse('petrol 500 doodh 200');
    expect(b.entries.map((e) => e.categoryId), ['exp_fuel', 'exp_grocery']);
    expect(b.needsAi, isTrue, reason: 'unmarked numbers are ambiguous');
  });

  test('quantities are not amounts', () {
    final e = parse('2 kg aloo 150 ka').entries.single;
    expect(e.amount, 150);
    expect(e.categoryId, 'exp_grocery');
  });

  test('dates: numeric, month names, days ago, parson', () {
    expect(parse('15/10 500 ka petrol').entries.single.date,
        DateTime(2026, 10, 15));
    expect(parse('3 oct ko 900 ka bill').entries.single.date,
        DateTime(2026, 10, 3));
    expect(parse('3 din pehle 300 ki chai').entries.single.date,
        DateTime(2026, 10, 16));
    expect(parse('parson 200 ka load').entries.single.date,
        DateTime(2026, 10, 17));
    // A future day without a year means last year.
    expect(parse('25 dec 1000 gift').entries.single.date,
        DateTime(2025, 12, 25));
  });

  test('same keyword resolves by income/expense hint', () {
    expect(parse('kiraya diya 25000').entries.single.categoryId, 'exp_rent');
    expect(parse('kiraya mila 25000').entries.single.categoryId, 'inc_rental');
    expect(parse('eidi mili 2000').entries.single.categoryId, 'inc_gift');
    expect(parse('+5000 bonus').entries.single.type, TxnType.income);
  });

  test('wallet mentioned by name', () {
    expect(parse('bank se 1200 ka bill').entries.single.walletId, 'wallet_bank');
    expect(parse('jazzcash se 500 ka load').entries.single.walletId, 'w_jazz');
    expect(parse('500 ka load').entries.single.walletId, kCashWalletId);
  });

  test('typos and spelling variants', () {
    expect(parse('300 ka petrool').entries.single.categoryId, 'exp_fuel');
    expect(parse('700 ki dawaai').entries.single.categoryId, 'exp_health');
  });

  test('unknown words fall back to Other and ask for AI', () {
    final r = parse('450 ka xyzabc');
    expect(r.entries.single.categoryId, kOtherExpenseId);
    expect(r.needsAi, isTrue);
  });

  test('text without an amount is skipped', () {
    final r = parse('petrol dalwaya');
    expect(r.entries, isEmpty);
    expect(r.skipped, ['petrol dalwaya']);
    expect(r.needsAi, isTrue);
  });

  test('learned words override defaults', () {
    final r = parse('100 ka biscuit', learned: {'biscuit': 'exp_grocery'});
    expect(r.entries.single.categoryId, 'exp_grocery');
  });

  test('learnable words drop fillers', () {
    expect(OfflineParser.learnableWords('Bijli ka bill'), ['bijli', 'bill']);
  });
}
