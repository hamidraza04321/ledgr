import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/period.dart';
import '../../providers/providers.dart';
import '../../services/export_service.dart';

Future<void> showExportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ExportSheet(),
  );
}

enum _Format { pdf, csv }

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet();

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  late final List<(String, Period)> _options;
  int _selected = 0;
  _Format _format = _Format.pdf;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final current = ref.read(periodProvider);
    _options = [
      ('This month', Period.of(PeriodKind.month)),
      ('Last month',
          Period.of(PeriodKind.month, anchor: DateTime(now.year, now.month - 1))),
      ('This year', Period.of(PeriodKind.year)),
      ('All time', Period.of(PeriodKind.all)),
      if (current != Period.thisMonth()) ('Dashboard: ${current.label}', current),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Export report', style: context.text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Creates a file you can save to Files/Drive or send on WhatsApp.',
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Text('Period', style: context.text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _options.length; i++)
                  ChoiceChip(
                    label: Text(_options[i].$1),
                    selected: _selected == i,
                    onSelected: (_) => setState(() => _selected = i),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Format', style: context.text.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<_Format>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _Format.pdf,
                  label: Text('PDF report'),
                  icon: Icon(Icons.picture_as_pdf_rounded),
                ),
                ButtonSegment(
                  value: _Format.csv,
                  label: Text('CSV (Excel)'),
                  icon: Icon(Icons.table_chart_rounded),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: context.palette.expense)),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: Text(_busy ? 'Preparing…' : 'Export & share'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (label, period) = _options[_selected];
      final txns = await ref.read(txnRepoProvider).inSpan(period.span);
      final data = ExportData(
        label: label.startsWith('Dashboard') ? period.label : '$label (${period.label})',
        txns: txns,
        categories: ref.read(categoryMapProvider),
        wallets: ref.read(walletMapProvider),
        currency: ref.read(currencyProvider),
      );
      final service = ExportService();
      if (_format == _Format.pdf) {
        await service.sharePdf(data);
      } else {
        await service.shareCsv(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
