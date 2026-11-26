import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../utils/format.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.tx, this.onTap});

  final Transaction tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isIncome = tx.type == TxType.income;
    final isTransfer = tx.isTransfer;

    final icon = isTransfer ? Icons.swap_horiz_rounded : tx.category.icon;
    final iconColor = isTransfer ? scheme.primary : tx.category.color;
    final amountColor = isTransfer
        ? scheme.onSurface
        : isIncome
        ? Colors.green.shade600
        : scheme.error;
    final sign = isTransfer ? '' : (isIncome ? '+' : '−');
    final subtitle = isTransfer
        ? 'Transfer · ${formatDay(tx.date)}'
        : '${tx.groupLabel} · ${formatDay(tx.date)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: iconColor.withValues(alpha: 0.18),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$sign${formatRupees(tx.amountPaise / 100, exact: true)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
