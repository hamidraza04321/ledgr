import 'package:intl/intl.dart';

class Currency {
  const Currency(this.code, this.symbol, this.name);

  final String code;
  final String symbol;
  final String name;

  static const all = [
    Currency('PKR', 'Rs', 'Pakistani Rupee'),
    Currency('INR', '₹', 'Indian Rupee'),
    Currency('USD', '\$', 'US Dollar'),
    Currency('EUR', '€', 'Euro'),
    Currency('GBP', '£', 'British Pound'),
    Currency('AED', 'AED', 'UAE Dirham'),
    Currency('SAR', 'SAR', 'Saudi Riyal'),
    Currency('BDT', '৳', 'Bangladeshi Taka'),
    Currency('CAD', 'C\$', 'Canadian Dollar'),
    Currency('AUD', 'A\$', 'Australian Dollar'),
  ];

  static Currency byCode(String? code) =>
      all.firstWhere((c) => c.code == code, orElse: () => all.first);

  static final _full = NumberFormat('#,##0.##', 'en_US');
  static final _compact = NumberFormat.compact(locale: 'en_US');

  String _join(String number) =>
      symbol.length > 1 ? '$symbol $number' : '$symbol$number';

  /// `Rs 1,250` / `$1,250.5`
  String format(double amount, {bool compact = false}) {
    final n = compact && amount.abs() >= 10000
        ? _compact.format(amount.abs())
        : _full.format(amount.abs());
    final s = _join(n);
    return amount < 0 ? '-$s' : s;
  }

  /// `+Rs 1,250` / `-Rs 1,250`
  String signed(double amount, {bool compact = false}) {
    final s = format(amount.abs(), compact: compact);
    return amount < 0 ? '-$s' : '+$s';
  }

  /// Plain number with the currency code, safe for PDF/CSV fonts.
  String plain(double amount) => '$code ${_full.format(amount)}';

  static String number(double amount) => _full.format(amount);
}
