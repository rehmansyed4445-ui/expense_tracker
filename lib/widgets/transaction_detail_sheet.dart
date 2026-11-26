import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import 'add_transaction_sheet.dart';
import 'ui.dart';

Future<void> showTransactionDetail(
  BuildContext context,
  ExpenseStore store,
  Transaction tx,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _TransactionDetail(store: store, tx: tx, host: context),
  );
}

class _TransactionDetail extends StatelessWidget {
  const _TransactionDetail({
    required this.store,
    required this.tx,
    required this.host,
  });

  final ExpenseStore store;
  final Transaction tx;

  /// Context of the screen that opened the sheet. Used after this sheet closes.
  final BuildContext host;

  String _accountName(String id) {
    for (final a in store.accounts) {
      if (a.id == id) return a.name;
    }
    return 'Unknown account';
  }

  void _edit(BuildContext context) {
    Navigator.of(context).pop();
    showModalBottomSheet<void>(
      context: host,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddTransactionSheet(store: store, existing: tx),
    );
  }

  void _delete(BuildContext context) {
    final h = host;
    Navigator.of(context).pop();
    store.remove(tx.id);
    showAppToast(
      h,
      message: 'Deleted "${tx.title}"',
      actionLabel: 'Undo',
      onAction: () => store.add(tx),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isIncome = tx.type == TxType.income;
    final isTransfer = tx.isTransfer;

    final color = isTransfer ? scheme.primary : tx.category.color;
    final icon = isTransfer ? Icons.swap_horiz_rounded : tx.category.icon;
    final amountColor = isTransfer
        ? scheme.onSurface
        : isIncome
        ? Colors.green.shade600
        : scheme.error;
    final sign = isTransfer ? '' : (isIncome ? '+' : '−');
    final typeLabel = switch (tx.type) {
      TxType.expense => 'Spent',
      TxType.income => 'Received',
      TxType.transfer => 'Moved',
    };
    final accountLine = isTransfer
        ? '${_accountName(tx.accountId)} → ${_accountName(tx.toAccountId ?? '')}'
        : _accountName(tx.accountId);

    return SheetFrame(
      title: tx.title,
      subtitle: typeLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(height: 14),
                Text(
                  '$sign${formatRupees(tx.amountPaise / 100, exact: true)}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _DetailRow(
            icon: Icons.category_rounded,
            label: 'Category',
            value: isTransfer ? 'Transfer' : tx.groupLabel,
          ),
          _DetailRow(
            icon: Icons.account_balance_wallet_rounded,
            label: isTransfer ? 'Between' : 'Account',
            value: accountLine,
          ),
          _DetailRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: formatDay(tx.date),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(
                      color: scheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
