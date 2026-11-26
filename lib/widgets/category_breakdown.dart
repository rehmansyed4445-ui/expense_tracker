import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/expense_store.dart';
import '../utils/format.dart';

class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({super.key, required this.groups});

  final List<SpendGroup> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = groups.map((g) => g.paise).reduce(math.max);

    return Column(
      children: [
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: g.category.color.withValues(alpha: 0.18),
                  child: Icon(
                    g.category.icon,
                    size: 18,
                    color: g.category.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(g.label, style: theme.textTheme.bodyLarge),
                          const Spacer(),
                          Text(
                            formatRupees(g.paise / 100),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: g.paise / max),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                            color: g.category.color,
                            backgroundColor: g.category.color.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
