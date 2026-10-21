import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../widgets/common.dart';

/// Compact Expense / Income switch used on dashboard cards.
class TypeToggle extends StatelessWidget {
  const TypeToggle({super.key, required this.value, required this.onChanged});

  final TxnType value;
  final ValueChanged<TxnType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in const [TxnType.expense, TxnType.income])
            _Pill(
              label: t == TxnType.expense ? 'Expense' : 'Income',
              selected: value == t,
              color: typeColor(context, t),
              onTap: () => onChanged(t),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? context.palette.card : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: selected ? color : context.colors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
