import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import 'account_style_picker.dart';
import 'accounts_sheet.dart';
import 'quick_add.dart';
import 'transaction_tile.dart';
import 'ui.dart';

import '../screens/search_screen.dart';

const kUnit = 64.0;

/// Gradient header: top bar, balance, account switcher. Nothing below it.
class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key, required this.store});
  final ExpenseStore store;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final hasAccounts = store.accounts.isNotEmpty;
    final many = store.accounts.length > 6;
    final rowHeight = many ? 136.0 : 72.0; // was 180 / 96
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 10),
      child: Column(
        children: [
          _HeaderTop(store: store),
          const SizedBox(height: 8),
          _HeaderBalance(store: store),
          // No accounts yet -> no selector, no Move money.
          if (hasAccounts) ...[
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
                          padding: const EdgeInsets.only(left: 6),
                          child: SizedBox(
                            width: 72,
                            height: rowHeight,
                            child: _HeaderTransfer(store: store),
                          ),
                        ),
                ),
              ],
            ),
          ],
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
    final on = theme.colorScheme.onPrimary;

    return Row(
      children: [
        InkResponse(
          onTap: () => Scaffold.of(context).openDrawer(),
          radius: 22,
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on.withValues(alpha: 0.2),
            ),
            child: Icon(Icons.person_rounded, color: on, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Expenses',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: on,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            backgroundColor: on.withValues(alpha: 0.2),
            foregroundColor: on,
          ),
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
    final on = Theme.of(context).colorScheme.onPrimary;

    return Pressable(
      onTap: () => openAccounts(context, store),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: on.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on.withValues(alpha: 0.15)),
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
                fontSize: 13,
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
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              store.isCurrentMonth
                  ? 'Available balance'
                  : 'Balance on ${formatDay(store.monthEnd)}',
              style: TextStyle(color: on.withValues(alpha: 0.8), fontSize: 12),
            ),
            const SizedBox(height: 10),
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
            Icon(icon, size: 14, color: color.withValues(alpha: 0.9)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color.withValues(alpha: 0.85),
                  fontSize: 12,
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
              fontSize: 15,
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
    final on = Theme.of(context).colorScheme.onPrimary;
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
            radius: 18,
            backgroundColor: on.withValues(alpha: 0.25),
            child: Icon(Icons.dashboard_rounded, size: 17, color: on),
          ),
        ),
      for (final a in store.accounts)
        _HeaderAccount(
          label: a.name,
          selected: focusId == a.id,
          onTap: () => pick(a.id),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: AccountAvatar(styleKey: a.styleKey, radius: 18),
          ),
        ),
    ];

    Widget strip(List<Widget> xs) => ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 2),
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
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: on.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Expanded(child: body),
              if (expanded)
                IconButton(
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onExpanded(false),
                  icon: Icon(Icons.close_rounded, size: 18, color: on),
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
    final on = Theme.of(context).colorScheme.onPrimary;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          width: 60,
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
                    color: selected ? on : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: child,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: on,
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
    final on = Theme.of(context).colorScheme.onPrimary;
    final canMove = store.accounts.length > 1;

    return Pressable(
      onTap: () =>
          canMove ? openTransfer(context, store) : openAccounts(context, store),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: on.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: on.withValues(alpha: 0.25),
              child: Icon(Icons.swap_horiz_rounded, size: 18, color: on),
            ),
            const SizedBox(height: 3),
            Text(
              'Move money',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: on,
                fontSize: 10.5,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain scrolling area under the gradient.
/// Scrolling part under the header: month switcher, search, transactions.
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
          const SizedBox(height: 10),
          if (store.hasAccounts) ...[
            _SearchBar(store: store),
            const SizedBox(height: 14),
          ],
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

/// Premium search pill. Looks like a search field; opens the full search screen.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.store});
  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Pressable(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SearchScreen(store: store))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.search_rounded,
                size: 18,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search your money…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Container(
              width: 1,
              height: 22,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.tune_rounded,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Previous month',
            onPressed: () => store.changeMonth(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy').format(store.month),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Pick a month',
            onPressed: () => _pick(context),
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
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
            'Let\'s set up your money',
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
