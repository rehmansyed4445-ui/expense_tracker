import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../state/expense_store.dart';

class WeekBarChart extends StatelessWidget {
  const WeekBarChart({super.key, required this.totals});

  final List<DayTotal> totals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    final maxValue = totals.fold<int>(1, (m, t) => math.max(m, t.expensePaise));

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, t) in totals.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: t.expensePaise / maxValue),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack,
                      builder: (_, fraction, _) {
                        final isToday = i == totals.length - 1;
                        return Container(
                          height: 4 + 100 * fraction,
                          decoration: BoxDecoration(
                            color: isToday
                                ? scheme.primary
                                : scheme.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(DateFormat.E().format(t.day), style: labelStyle),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
