import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/utils/currency.dart';
import '../data/models/models.dart';

class ExportData {
  const ExportData({
    required this.label,
    required this.txns,
    required this.categories,
    required this.wallets,
    required this.currency,
  });

  final String label;
  final List<Txn> txns;
  final Map<String, Category> categories;
  final Map<String, Wallet> wallets;
  final Currency currency;

  String categoryName(Txn t) => t.type == TxnType.transfer
      ? 'Transfer'
      : categories[t.categoryId]?.name ??
          (t.type == TxnType.income ? 'Other Income' : 'Other');

  String walletName(Txn t) {
    final from = wallets[t.walletId]?.name ?? 'Wallet';
    if (t.type != TxnType.transfer) return from;
    return '$from -> ${wallets[t.toWalletId]?.name ?? 'Wallet'}';
  }

  Totals get totals {
    var income = 0.0, expense = 0.0;
    for (final t in txns) {
      if (t.type == TxnType.income) income += t.amount;
      if (t.type == TxnType.expense) expense += t.amount;
    }
    return Totals(income: income, expense: expense);
  }

  /// (name, total, count) sorted by total.
  List<(String, double, int)> breakdown(TxnType type) {
    final map = <String, (double, int)>{};
    for (final t in txns.where((t) => t.type == type)) {
      final name = categoryName(t);
      final cur = map[name] ?? (0.0, 0);
      map[name] = (cur.$1 + t.amount, cur.$2 + 1);
    }
    return [for (final e in map.entries) (e.key, e.value.$1, e.value.$2)]
      ..sort((a, b) => b.$2.compareTo(a.$2));
  }
}

class ExportService {
  static final _date = DateFormat('yyyy-MM-dd');
  static final _time = DateFormat('HH:mm');
  static final _prettyDate = DateFormat('d MMM yyyy');

  Future<void> shareCsv(ExportData data) async {
    final rows = <List<String>>[
      ['Date', 'Time', 'Type', 'Category', 'Wallet', 'Amount', 'Currency', 'Note'],
      for (final t in data.txns.reversed)
        [
          _date.format(t.date),
          _time.format(t.date),
          t.type.label,
          data.categoryName(t),
          data.walletName(t),
          t.amount.toStringAsFixed(2),
          data.currency.code,
          t.note,
        ],
    ];
    final csv = rows.map((r) => r.map(_csvCell).join(',')).join('\r\n');
    // BOM so Excel opens Urdu text correctly.
    final file = await _file('csv');
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
    await _share(file, 'text/csv', data.label);
  }

  Future<void> sharePdf(ExportData data) async {
    final c = data.currency;
    final totals = data.totals;
    final brand = PdfColor.fromInt(0xFF5B4CF0);
    final muted = PdfColor.fromInt(0xFF6B7080);
    final green = PdfColor.fromInt(0xFF15A35A);
    final red = PdfColor.fromInt(0xFFE5484D);

    pw.Widget stat(String label, double value, PdfColor color) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE4E6EE)),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 9)),
                pw.SizedBox(height: 4),
                pw.Text(
                  c.plain(value),
                  style: pw.TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );

    pw.Widget breakdown(String title, TxnType type, double total) {
      final rows = data.breakdown(type);
      if (rows.isEmpty) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 18),
          pw.Text(title,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Category', 'Entries', 'Amount', 'Share'],
            data: [
              for (final r in rows)
                [
                  _safe(r.$1),
                  '${r.$3}',
                  c.plain(r.$2),
                  total == 0 ? '-' : '${(r.$2 / total * 100).toStringAsFixed(1)}%',
                ],
            ],
            headerStyle: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: brand),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            border: null,
            oddRowDecoration:
                pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F6FA)),
          ),
        ],
      );
    }

    final doc = pw.Document(title: 'Ledgr report', author: 'Ledgr');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(color: muted, fontSize: 8)),
      ),
      build: (ctx) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Ledgr',
                    style: pw.TextStyle(
                        color: brand,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('Income & expense report',
                    style: pw.TextStyle(color: muted, fontSize: 10)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(_safe(data.label),
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generated ${_prettyDate.format(DateTime.now())}',
                    style: pw.TextStyle(color: muted, fontSize: 9)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Row(children: [
          stat('Income', totals.income, green),
          pw.SizedBox(width: 10),
          stat('Expense', totals.expense, red),
          pw.SizedBox(width: 10),
          stat('Net', totals.net, totals.net >= 0 ? green : red),
        ]),
        breakdown('Expenses by category', TxnType.expense, totals.expense),
        breakdown('Income by category', TxnType.income, totals.income),
        pw.SizedBox(height: 18),
        pw.Text('Transactions (${data.txns.length})',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (data.txns.isEmpty)
          pw.Text('No entries in this period.',
              style: pw.TextStyle(color: muted, fontSize: 9))
        else
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Category', 'Wallet', 'Note', 'Amount'],
            data: [
              for (final t in data.txns)
                [
                  _prettyDate.format(t.date),
                  _safe(data.categoryName(t)),
                  _safe(data.walletName(t)),
                  _safe(t.note),
                  switch (t.type) {
                    TxnType.income => '+${c.plain(t.amount)}',
                    TxnType.expense => '-${c.plain(t.amount)}',
                    TxnType.transfer => c.plain(t.amount),
                  },
                ],
            ],
            headerStyle: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: brand),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(62),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(2.5),
              4: const pw.FixedColumnWidth(80),
            },
            cellAlignments: {4: pw.Alignment.centerRight},
            border: null,
            oddRowDecoration:
                pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F6FA)),
          ),
      ],
    ));

    final file = await _file('pdf');
    await file.writeAsBytes(await doc.save());
    await _share(file, 'application/pdf', data.label);
  }

  static String _csvCell(String v) {
    if (v.contains(RegExp(r'[",\r\n]'))) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  /// The built-in PDF font only covers Latin-1.
  static String _safe(String s) => s
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('→', '->')
      .replaceAll(RegExp(r'[^\x00-\xFF]'), '?');

  Future<File> _file(String ext) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return File('${dir.path}/ledgr_report_$stamp.$ext');
  }

  Future<void> _share(File file, String mime, String label) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mime)],
      subject: 'Ledgr report – $label',
      title: 'Ledgr report',
    ));
  }
}
