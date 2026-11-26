import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import '../widgets/category_donut.dart';
import '../widgets/month_switcher.dart';
import '../widgets/section_card.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/week_bar_chart.dart';
import '../widgets/quick_add.dart';

class ReportsView extends StatelessWidget {
  const ReportsView({super.key, required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final groups = store.spendBreakdown;
    final total = store.expensePaise;
    final monthName = DateFormat('MMMM').format(store.month);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: MonthSwitcher(store: store),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 8),
              _HeroCard(store: store, total: total, monthName: monthName),
              const SizedBox(height: 16),
              _InsightRow(store: store, groups: groups, total: total),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Breakdown',
                child: groups.isEmpty
                    ? const _NoData()
                    : Column(
                        children: [
                          Center(
                            child: CategoryDonut(
                              groups: groups,
                              totalPaise: total,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _Legend(groups: groups, total: total),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Since you started',
                child: WeekBarChart(totals: store.recentDayTotals()),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Categories',
                child: groups.isEmpty
                    ? const _NoData()
                    : Column(
                        children: [
                          for (final g in groups)
                            _GroupTile(store: store, group: g, total: total),
                        ],
                      ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.store,
    required this.total,
    required this.monthName,
  });

  final ExpenseStore store;
  final int total;
  final String monthName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final prev = store.expenseForMonth(
      DateTime(store.month.year, store.month.month - 1),
    );
    final change = prev == 0 ? null : (total - prev) / prev;
    final spends = store.monthTransactions
        .where((t) => t.type == TxType.expense)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spent in $monthName',
            style: textTheme.labelLarge?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatRupees(total / 100),
            style: textTheme.displaySmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(text: spends == 1 ? '1 spend' : '$spends spends'),
              if (change != null)
                _Pill(
                  icon: change >= 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  text: '${(change.abs() * 100).round()}% vs last month',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.store,
    required this.groups,
    required this.total,
  });

  final ExpenseStore store;
  final List<SpendGroup> groups;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = groups.isEmpty ? null : groups.first;
    final now = DateTime.now();
    final days = store.isCurrentMonth
        ? now.day
        : DateTime(store.month.year, store.month.month + 1, 0).day;
    final average = total / days;

    return Row(
      children: [
        Expanded(
          child: _InsightCard(
            icon: top?.category.icon ?? Icons.category_rounded,
            color: top?.category.color ?? scheme.primary,
            label: 'Top category',
            value: top?.label ?? 'None yet',
            detail: top == null
                ? 'Log a spend to see it'
                : formatRupees(top.paise / 100),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InsightCard(
            icon: Icons.calendar_view_day_rounded,
            color: scheme.tertiary,
            label: 'Daily average',
            value: formatRupees(average / 100),
            detail: 'Over $days days',
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.18),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.groups, required this.total});

  final List<SpendGroup> groups;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: g.category.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(g.label, style: theme.textTheme.bodyMedium),
                ),
                Text(
                  '${(g.paise / total * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatRupees(g.paise / 100),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.store,
    required this.group,
    required this.total,
  });

  final ExpenseStore store;
  final SpendGroup group;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final budget = store.budgetFor(group.label);
    final share = total == 0 ? 0.0 : group.paise / total;
    final ratio = budget == null ? share : group.paise / budget;
    final over = budget != null && group.paise > budget;
    final barColor = over ? scheme.error : group.category.color;
    final txs = store.transactionsFor(group.label);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: CircleAvatar(
            backgroundColor: group.category.color.withValues(alpha: 0.18),
            child: Icon(
              group.category.icon,
              color: group.category.color,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  group.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatRupees(group.paise / 100),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0).toDouble(),
                    minHeight: 6,
                    color: barColor,
                    backgroundColor: barColor.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  budget == null
                      ? '${(share * 100).round()}% of this month'
                      : '${formatRupees(group.paise / 100)} of ${formatRupees(budget / 100)}'
                            '${over ? ' · over budget' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: over ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          children: [
            for (final t in txs)
              TransactionTile(
                tx: t,
                onTap: () => openTransactionEditor(context, store, t),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'Nothing spent this month yet.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
