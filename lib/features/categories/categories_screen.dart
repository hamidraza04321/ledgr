import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/icons.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    return DefaultTabController(
      length: 2,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Categories'),
            bottom: const TabBar(
              tabs: [Tab(text: 'Expense'), Tab(text: 'Income')],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'add-category',
            onPressed: () {
              final index = DefaultTabController.of(context).index;
              showCategoryForm(
                context,
                type: index == 0 ? TxnType.expense : TxnType.income,
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Category'),
          ),
          body: TabBarView(
            children: [
              for (final type in const [TxnType.expense, TxnType.income])
                _CategoryList(
                  categories: all.where((c) => c.type == type).toList(),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          12, 12, 12, 96 + MediaQuery.paddingOf(context).bottom),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, i) {
        final c = categories[i];
        final details = [
          if (c.hasBudget) 'Budget ${currency.format(c.budget!)}',
          if (c.keywords.isNotEmpty)
            c.keywords.take(4).join(', ') +
                (c.keywords.length > 4 ? '…' : ''),
        ].join(' · ');
        return ListTile(
          leading: IconBadge(icon: categoryIcon(c.icon), color: Color(c.color)),
          title: Text(c.name, style: context.text.titleSmall),
          subtitle: details.isEmpty
              ? null
              : Text(details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showCategoryForm(context, category: c, type: c.type),
        );
      },
    );
  }
}

Future<void> showCategoryForm(
  BuildContext context, {
  Category? category,
  required TxnType type,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategoryForm(category: category, type: type),
  );
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({this.category, required this.type});

  final Category? category;
  final TxnType type;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late final _keywords =
      TextEditingController(text: widget.category?.keywords.join(', ') ?? '');
  late final _budget = TextEditingController(
    text: widget.category?.hasBudget == true
        ? widget.category!.budget!.toStringAsFixed(0)
        : '',
  );
  late String _icon = widget.category?.icon ?? 'category';
  late int _color = widget.category?.color ?? kColorChoices[8];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _keywords.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.category != null;
    final currency = ref.watch(currencyProvider);
    final isExpense = widget.type == TxnType.expense;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(icon: categoryIcon(_icon), color: Color(_color), size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    editing ? 'Edit category' : 'New ${widget.type.label.toLowerCase()} category',
                    style: context.text.titleLarge,
                  ),
                ),
                if (editing && !widget.category!.isFallback)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline_rounded,
                        color: context.palette.expense),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            Text('Icon', style: context.text.labelLarge),
            const SizedBox(height: 8),
            SizedBox(
              height: 112,
              child: GridView.count(
                crossAxisCount: 2,
                scrollDirection: Axis.horizontal,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final e in kCategoryIcons.entries)
                    _IconChoice(
                      icon: e.value,
                      color: Color(_color),
                      selected: e.key == _icon,
                      onTap: () => setState(() => _icon = e.key),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Color', style: context.text.labelLarge),
            const SizedBox(height: 8),
            ColorPickerRow(
              selected: _color,
              onSelect: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keywords,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Chat keywords',
                hintText: 'e.g. petrol, diesel, cng',
                helperText: 'Words that auto-pick this category in chat',
              ),
            ),
            if (isExpense) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _budget,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Monthly budget (optional)',
                  prefixText: '${currency.symbol} ',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: context.palette.expense)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: Text(editing ? 'Save changes' : 'Add category'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    final repo = ref.read(categoryRepoProvider);
    final budget = double.tryParse(_budget.text.trim());
    final keywords = splitKeywords(_keywords.text);
    final existing = widget.category;
    final c = existing != null
        ? existing.copyWith(
            name: name,
            icon: _icon,
            color: _color,
            keywords: keywords,
            budget: () => budget != null && budget > 0 ? budget : null,
          )
        : Category(
            id: const Uuid().v4(),
            name: name,
            type: widget.type,
            icon: _icon,
            color: _color,
            keywords: keywords,
            budget: budget != null && budget > 0 ? budget : null,
            sortOrder: await repo.nextSortOrder(),
          );
    await repo.save(c);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete "${widget.category!.name}"?',
      message: 'Existing entries will show under '
          '"${widget.type == TxnType.income ? 'Other Income' : 'Other'}".',
    );
    if (!ok) return;
    await ref.read(categoryRepoProvider).delete(widget.category!.id);
    if (mounted) Navigator.pop(context);
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? color.withValues(alpha: 0.16)
          : context.colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: selected ? color : Colors.transparent, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Icon(icon,
            color: selected ? color : context.colors.onSurfaceVariant),
      ),
    );
  }
}

class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kColorChoices.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = kColorChoices[i];
          final isSelected = c == selected;
          return GestureDetector(
            onTap: () => onSelect(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? context.colors.onSurface : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
