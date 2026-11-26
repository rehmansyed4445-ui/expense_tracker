import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import 'account_style_picker.dart';
import 'budgets.dart';
import 'quick_add.dart';
import 'transaction_tile.dart';
import 'ui.dart';
import 'upcoming_sheet.dart';

import 'accounts_sheet.dart';

enum TileKind {
  profile,
  budgets,
  upcoming,
  balance,
  accounts,
  transfer,
  budgetList,
  month,
  transactions,
  actions,
}

Widget buildTile(
  BuildContext context,
  TileKind kind,
  ExpenseStore store, {
  bool expanded = false,
  ValueChanged<bool>? onExpanded,
}) {
  return switch (kind) {
    TileKind.profile => _ProfileTile(store: store),
    TileKind.budgets => _BudgetsTile(store: store),
    TileKind.upcoming => _UpcomingTile(store: store),
    TileKind.balance => _BalanceTile(store: store),
    TileKind.accounts => _AccountsTile(
      store: store,
      expanded: expanded,
      onExpanded: onExpanded ?? (_) {},
    ),
    TileKind.transfer => _TransferTile(store: store),
    TileKind.budgetList => _BudgetListTile(store: store),
    TileKind.month => _MonthTile(store: store),
    TileKind.transactions => _TransactionsTile(store: store),
    TileKind.actions => _ActionsTile(store: store),
  };
}

// ---------- Shared pieces ----------

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(12)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}

/// Half-height pill: round icon, title and one line of value.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: color.withValues(alpha: 0.18),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Half-height pills ----------

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      icon: Icons.person_rounded,
      color: Theme.of(context).colorScheme.primary,
      title: 'Your money',
      value: formatRupees(store.totalAllBalancePaise / 100),
      onTap: () => Scaffold.of(context).openDrawer(),
    );
  }
}

class _BudgetsTile extends StatelessWidget {
  const _BudgetsTile({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final over = store.budgets.keys
        .where((k) => store.spentFor(k) > (store.budgetFor(k) ?? 0))
        .length;
    final value = store.budgets.isEmpty
        ? 'Set limits'
        : over > 0
        ? '$over over'
        : '${store.budgets.length} on track';
    return _Pill(
      icon: Icons.pie_chart_rounded,
      color: Theme.of(context).colorScheme.tertiary,
      title: 'Budgets',
      value: value,
      onTap: () => showBudgetSheet(context, store),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final total = store.scopeUpcomingPaise;
    return _Pill(
      icon: Icons.event_rounded,
      color: const Color(0xFFF57C00),
      title: 'Upcoming',
      value: total > 0 ? formatRupees(total / 100) : 'None',
      onTap: () => showUpcomingSheet(context, store),
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final canMove = store.accounts.length > 1;
    return _Pill(
      icon: Icons.swap_horiz_rounded,
      color: Theme.of(context).colorScheme.primary,
      title: 'Move money',
      value: canMove ? 'Between accounts' : 'Add a 2nd account',
      onTap: () =>
          canMove ? openTransfer(context, store) : openAccounts(context, store),
    );
  }
}

// ---------- Balance ----------

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final balance = store.periodBalancePaise;
    final upcoming = store.scopeUpcomingPaise;
    final left = balance - upcoming;
    final onPrimary = scheme.onPrimary;

    return Pressable(
      onTap: () => openAccounts(context, store),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        // Scales the whole card down on narrow screens instead of overflowing.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.scopeName,
                style: TextStyle(color: onPrimary, fontWeight: FontWeight.w600),
              ),
              Text(
                formatRupees(balance / 100),
                style: TextStyle(
                  color: onPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                store.isCurrentMonth
                    ? 'Available balance'
                    : 'Balance on ${formatDay(store.monthEnd)}',
                style: TextStyle(
                  color: onPrimary.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Mini(
                    label: 'Received',
                    icon: Icons.south_west_rounded,
                    paise: store.incomePaise,
                    color: onPrimary,
                  ),
                  const SizedBox(width: 18),
                  _Mini(
                    label: 'Spent',
                    icon: Icons.north_east_rounded,
                    paise: store.expensePaise,
                    color: onPrimary,
                  ),
                ],
              ),
              if (upcoming > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Upcoming ${formatRupees(upcoming / 100)} · Left ${formatRupees(left / 100)}',
                  style: TextStyle(
                    color: onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _Mini extends StatelessWidget {
  const _Mini({
    required this.label,
    required this.icon,
    required this.paise,
    required this.color,
  });

  final String label;
  final IconData icon;
  final int paise;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
            Text(
              formatRupees(paise / 100),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------- Account switcher (scrolls sideways) ----------

class _AccountsTile extends StatelessWidget {
  const _AccountsTile({
    required this.store,
    required this.expanded,
    required this.onExpanded,
  });

  final ExpenseStore store;
  final bool expanded;
  final ValueChanged<bool> onExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focusId = store.focusAccount?.id;

    void pick(String? id) {
      store.selectAccount(id);
      onExpanded(false);
    }

    return NotificationListener<ScrollStartNotification>(
      onNotification: (_) {
        if (!expanded) onExpanded(true);
        return false;
      },
      child: _Card(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (store.accounts.length > 1)
                    _RoundAccount(
                      label: 'All',
                      selected: focusId == null,
                      onTap: () => pick(null),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          Icons.dashboard_rounded,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  for (final a in store.accounts)
                    _RoundAccount(
                      label: a.name,
                      selected: focusId == a.id,
                      onTap: () => pick(a.id),
                      child: AccountAvatar(styleKey: a.styleKey, radius: 24),
                    ),
                  _RoundAccount(
                    label: 'Add',
                    selected: false,
                    onTap: () => showAccountEditor(context, store),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.add_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (expanded)
              IconButton(
                tooltip: 'Close',
                onPressed: () => onExpanded(false),
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

/// Round account icon with its name below.
class _RoundAccount extends StatelessWidget {
  const _RoundAccount({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: child,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Budgets and upcoming (one tile, scrolls) ----------

// ... [previous code] ...
class _BudgetListTile extends StatelessWidget {
  const _BudgetListTile({required this.store});
  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // FIXED: Using a simple class instead of record syntax
    final rows =
        store.budgets.entries
            .map(
              (e) => _BudgetRow(
                label: e.key,
                budget: e.value,
                spent: store.spentFor(e.key),
              ),
            )
            .toList()
          ..sort((a, b) => (b.spent / b.budget).compareTo(a.spent / a.budget));

    final focusId = store.focusAccount?.id;
    final upcoming = store.upcoming
        .where((u) => focusId == null || u.accountId == focusId)
        .take(3)
        .toList();

    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Budgets & upcoming',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showBudgetSheet(context, store),
                child: const Text('Budgets'),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (rows.isEmpty)
                  Text(
                    'Set a budget to track it here.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  for (final r in rows.take(2))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${formatRupees(r.spent / 100)} / ${formatRupees(r.budget / 100)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: r.spent > r.budget
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (r.spent / r.budget)
                                  .clamp(0.0, 1.0)
                                  .toDouble(),
                              minHeight: 6,
                              color: r.spent > r.budget
                                  ? scheme.error
                                  : scheme.primary,
                              backgroundColor: scheme.primary.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'To pay',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  for (final u in upcoming)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Due ${formatDay(u.dueDate)} · ${formatRupees(u.amountPaise / 100)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => openPaidFrom(context, store, u),
                            child: const Text('Paid'),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// NEW: Helper class for budget rows
class _BudgetRow {
  final String label;
  final int budget;
  final int spent;

  _BudgetRow({required this.label, required this.budget, required this.spent});
}
// ... [rest of the code remains the same] ...

// ---------- Month switcher with calendar ----------

class _MonthTile extends StatelessWidget {
  const _MonthTile({required this.store});

  final ExpenseStore store;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: store.month,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked != null) store.selectMonthOf(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => store.changeMonth(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy').format(store.month),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Pick a month',
            onPressed: () => _pick(context),
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: () => store.changeMonth(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

// ---------- Transactions (scrolls) ----------

class _TransactionsTile extends StatelessWidget {
  const _TransactionsTile({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final txs = store.monthTransactions;
    return _Card(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Transactions',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${txs.length}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: txs.isEmpty
                ? Center(
                    child: Text(
                      'Nothing logged this month.\nUse Spent or Received below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: txs.length,
                    itemBuilder: (_, i) => TransactionTile(
                      tx: txs[i],
                      onTap: () =>
                          openTransactionEditor(context, store, txs[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------- Spent / Received ----------

class _ActionsTile extends StatelessWidget {
  const _ActionsTile({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => startAddFlow(context, store, TxType.expense),
              icon: const Icon(Icons.north_east_rounded),
              label: const Text('Spent'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => startAddFlow(context, store, TxType.income),
              icon: const Icon(Icons.south_west_rounded),
              label: const Text('Received'),
            ),
          ),
        ],
      ),
    );
  }
}
