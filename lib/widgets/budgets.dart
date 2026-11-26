import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import 'ui.dart';

Future<void> showBudgetSheet(BuildContext context, ExpenseStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _BudgetSheet(store: store),
  );
}

class _BudgetSheet extends StatelessWidget {
  const _BudgetSheet({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final categories = Category.values
        .where((c) => c != Category.salary)
        .toList();
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => SheetFrame(
        title: 'Monthly budgets',
        subtitle: 'Tap a category to set its limit.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BudgetTile(store: store, category: c),
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.store, required this.category});

  final ExpenseStore store;
  final Category category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final budget = store.budgetFor(category.label);
    final spent = store.spentFor(category.label);
    final over = budget != null && spent > budget;
    final color = over ? scheme.error : category.color;

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _editBudget(context, store, category.label),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: category.color.withValues(alpha: 0.18),
                    child: Icon(category.icon, color: category.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    budget == null
                        ? 'Not set'
                        : '${formatRupees(spent / 100)} / ${formatRupees(budget / 100)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: over ? scheme.error : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (budget != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (spent / budget).clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _editBudget(
  BuildContext context,
  ExpenseStore store,
  String label,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _BudgetDialog(store: store, label: label),
  );
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.store, required this.label});

  final ExpenseStore store;
  final String label;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final current = widget.store.budgetFor(widget.label);
    _controller = TextEditingController(
      text: current == null ? '' : (current / 100).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(_controller.text.trim()) ?? 0;
    widget.store.setBudget(widget.label, v > 0 ? (v * 100).round() : null);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasBudget = widget.store.budgetFor(widget.label) != null;
    return AppDialog(
      title: '${widget.label} budget',
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          prefixText: '₹ ',
          labelText: 'Monthly limit',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      actions: [
        if (hasBudget)
          TextButton(
            onPressed: () {
              widget.store.setBudget(widget.label, null);
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
