import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../state/expense_store.dart';
import '../utils/format.dart';
import 'account_style_picker.dart';
import 'accounts_sheet.dart';
import 'quick_add.dart';
import 'transaction_tile.dart';
import 'ui.dart';

/// Kept for older layout files.
const kUnit = 64.0;

/// Fixed top section: profile, balance and account switcher. Does not scroll.
class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key, required this.store});

  final ExpenseStore store;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  /// True while the account row is widened by scrolling. Move money hides then.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final many = store.accounts.length > 6;
    final rowHeight = many ? 180.0 : 96.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          _HeaderTop(store: store),
          const SizedBox(height: 8),
          _HeaderBalance(store: store),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _HeaderAccounts(
                  store: store,
                  height: rowHeight,
                  many: many,
                  expanded: _expanded,
                  onExpanded: (v) => setState(() => _expanded = v),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: _expanded
                    ? const SizedBox(width: 0)
                    : Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: SizedBox(
                          width: 84,
                          height: rowHeight,
                          child: _HeaderTransfer(store: store),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderTop extends StatelessWidget {
  const _HeaderTop({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        InkResponse(
          onTap: () => Scaffold.of(context).openDrawer(),
          radius: 24,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.tertiary],
              ),
            ),
            child: Icon(
              Icons.person_rounded,
              color: scheme.onPrimary,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Expenses',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () => showAccountEditor(context, store),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add account'),
        ),
      ],
    );
  }
}

class _HeaderBalance extends StatelessWidget {
  const _HeaderBalance({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = scheme.onPrimary;

    return Pressable(
      onTap: () => openAccounts(context, store),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              store.scopeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: on,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatRupees(store.periodBalancePaise / 100),
                style: TextStyle(
                  color: on,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              store.isCurrentMonth
                  ? 'Available balance'
                  : 'Balance on ${formatDay(store.monthEnd)}',
              style: TextStyle(color: on.withValues(alpha: 0.8), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Received',
                    icon: Icons.south_west_rounded,
                    paise: store.incomePaise,
                    color: on,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Spent',
                    icon: Icons.north_east_rounded,
                    paise: store.expensePaise,
                    color: on,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Upcoming',
                    icon: Icons.event_rounded,
                    paise: store.scopeUpcomingPaise,
                    color: on,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color.withValues(alpha: 0.9)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatRupees(paise / 100),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderAccounts extends StatelessWidget {
  const _HeaderAccounts({
    required this.store,
    required this.height,
    required this.many,
    required this.expanded,
    required this.onExpanded,
  });

  final ExpenseStore store;
  final double height;
  final bool many;
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

    final items = <Widget>[
      if (store.accounts.length > 1)
        _HeaderAccount(
          label: 'All',
          selected: focusId == null,
          onTap: () => pick(null),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: scheme.primaryContainer,
            child: Icon(
              Icons.dashboard_rounded,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      for (final a in store.accounts)
        _HeaderAccount(
          label: a.name,
          selected: focusId == a.id,
          onTap: () => pick(a.id),
          child: AccountAvatar(styleKey: a.styleKey, radius: 22),
        ),
    ];

    Widget strip(List<Widget> xs) => ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: xs,
    );

    final Widget body = many
        ? Column(
            children: [
              Expanded(
                child: strip([
                  for (var i = 0; i < items.length; i += 2) items[i],
                ]),
              ),
              Expanded(
                child: strip([
                  for (var i = 1; i < items.length; i += 2) items[i],
                ]),
              ),
            ],
          )
        : strip(items);

    return SizedBox(
      height: height,
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (_) {
          if (!expanded) onExpanded(true);
          return false;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Expanded(child: body),
              if (expanded)
                IconButton(
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onExpanded(false),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAccount extends StatelessWidget {
  const _HeaderAccount({
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.primary : Colors.transparent,
                    width: 2.5,
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
                style: TextStyle(
                  fontSize: 13,
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

class _HeaderTransfer extends StatelessWidget {
  const _HeaderTransfer({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canMove = store.accounts.length > 1;
    return Pressable(
      onTap: () =>
          canMove ? openTransfer(context, store) : openAccounts(context, store),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primary.withValues(alpha: 0.16),
              child: Icon(
                Icons.swap_horiz_rounded,
                size: 20,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Move money',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scrolling part under the header: month switcher and transactions.
class HomeBody extends StatelessWidget {
  const HomeBody({super.key, required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final txs = store.monthTransactions;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 130),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 56, child: _MonthBar(store: store)),
          const SizedBox(height: 12),
          if (!store.hasAccounts)
            _Welcome(store: store)
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Transactions',
                    style: theme.textTheme.titleMedium?.copyWith(
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
            const SizedBox(height: 6),
            if (txs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'Nothing logged this month.\nUse the bar below to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              for (final tx in txs)
                TransactionTile(
                  tx: tx,
                  onTap: () => openTransactionEditor(context, store, tx),
                ),
          ],
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.store});

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
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
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

class _Welcome extends StatelessWidget {
  const _Welcome({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Let’s set up your money',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add the account you spend from, with its balance right now.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => openAccountSetup(context, store),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add my account'),
          ),
        ],
      ),
    );
  }
}
