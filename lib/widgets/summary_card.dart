import 'package:flutter/material.dart';
import '../utils/format.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.balancePaise,
    required this.balanceLabel,
    required this.periodLabel,
    required this.incomePaise,
    required this.expensePaise,
    required this.upcomingPaise,
  });

  final String title;
  final IconData icon;
  final int balancePaise;
  final String balanceLabel;
  final String periodLabel;
  final int incomePaise;
  final int expensePaise;
  final int upcomingPaise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final onPrimary = scheme.onPrimary;
    final left = balancePaise - upcomingPaise;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28), // Professional large radius
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
          // Header Section
          Row(
            children: [
              Icon(icon, color: onPrimary.withValues(alpha: 0.9), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Balance Amount (Responsive with FittedBox to prevent overflow on small screens)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: balancePaise / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => Text(
                formatRupees(value),
                style: textTheme.displaySmall?.copyWith(
                  color: onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          Text(
            balanceLabel,
            style: textTheme.bodySmall?.copyWith(
              color: onPrimary.withValues(alpha: 0.8),
            ),
          ),

          // Upcoming Payments Box
          if (upcomingPaise > 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: onPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upcoming ${formatRupees(upcomingPaise / 100)}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    'Left ${formatRupees(left / 100)}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          Text(
            periodLabel,
            style: textTheme.labelMedium?.copyWith(
              color: onPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),

          // Stats Row (Received / Spent)
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Received',
                  icon: Icons.south_west_rounded,
                  amountPaise: incomePaise,
                  color: onPrimary,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Spent',
                  icon: Icons.north_east_rounded,
                  amountPaise: expensePaise,
                  color: onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.icon,
    required this.amountPaise,
    required this.color,
  });

  final String label;
  final IconData icon;
  final int amountPaise;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(end: amountPaise / 100),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => Text(
                  formatRupees(value),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
