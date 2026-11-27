import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import '../widgets/quick_add.dart';
import '../widgets/transaction_tile.dart';

/// Searches every transaction in every month, inside the focused account.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.store});
  final ExpenseStore store;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  TxType? _type;
  Category? _category;
  bool _monthOnly = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearAll() {
    _controller.clear();
    setState(() {
      _query = '';
      _type = null;
      _category = null;
      _monthOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final store = widget.store;
    final hasFilters =
        _query.isNotEmpty || _type != null || _category != null || _monthOnly;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search title, amount, category…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final results = store.searchTransactions(
            query: _query,
            type: _type,
            category: _category,
            monthOnly: _monthOnly,
          );
          final spent = store.sumType(TxType.expense, results);
          final received = store.sumType(TxType.income, results);

          return Column(
            children: [
              _FilterBar(
                type: _type,
                category: _category,
                monthOnly: _monthOnly,
                onType: (v) => setState(() => _type = v),
                onCategory: (v) => setState(() => _category = v),
                onMonthOnly: (v) => setState(() => _monthOnly = v),
              ),
              if (results.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: scheme.surfaceContainerLow,
                  child: Row(
                    children: [
                      Text(
                        '${results.length} '
                        '${results.length == 1 ? 'result' : 'results'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      if (spent > 0)
                        Text(
                          '−${formatRupees(spent / 100)}',
                          style: TextStyle(
                            color: scheme.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      if (spent > 0 && received > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '·',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      if (received > 0)
                        Text(
                          '+${formatRupees(received / 100)}',
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: results.isEmpty
                    ? _EmptyState(hasFilters: hasFilters, onClear: _clearAll)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                        itemCount: results.length,
                        itemBuilder: (_, i) => TransactionTile(
                          tx: results[i],
                          onTap: () =>
                              openTransactionEditor(context, store, results[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.type,
    required this.category,
    required this.monthOnly,
    required this.onType,
    required this.onCategory,
    required this.onMonthOnly,
  });

  final TxType? type;
  final Category? category;
  final bool monthOnly;
  final ValueChanged<TxType?> onType;
  final ValueChanged<Category?> onCategory;
  final ValueChanged<bool> onMonthOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _chip('All', type == null, () => onType(null)),
              _chip(
                'Spent',
                type == TxType.expense,
                () => onType(TxType.expense),
              ),
              _chip(
                'Received',
                type == TxType.income,
                () => onType(TxType.income),
              ),
              _chip(
                'Moved',
                type == TxType.transfer,
                () => onType(TxType.transfer),
              ),
              const SizedBox(width: 10),
              _chip(
                'This month',
                monthOnly,
                () => onMonthOnly(!monthOnly),
                icon: Icons.calendar_month_rounded,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _chip('All categories', category == null, () => onCategory(null)),
              for (final c in Category.values)
                _chip(
                  c.label,
                  category == c,
                  () => onCategory(c),
                  icon: c.icon,
                  color: c.color,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(
    String label,
    bool selected,
    VoidCallback onTap, {
    IconData? icon,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null
            ? null
            : Icon(icon, size: 16, color: selected ? null : color),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters, required this.onClear});
  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilters ? Icons.search_off_rounded : Icons.search_rounded,
              size: 56,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No matches' : 'Search your money',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try a different word, or clear the filters.'
                  : 'Find any spend by name, amount,\ncategory or account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 18),
              TextButton(onPressed: onClear, child: const Text('Clear all')),
            ],
          ],
        ),
      ),
    );
  }
}
