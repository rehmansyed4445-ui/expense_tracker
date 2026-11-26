import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/expense_store.dart';
import '../utils/format.dart';

class CategoryDonut extends StatelessWidget {
  const CategoryDonut({
    super.key,
    required this.groups,
    required this.totalPaise,
  });

  final List<SpendGroup> groups;
  final int totalPaise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TweenAnimationBuilder<double>(
      key: ValueKey(totalPaise),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => SizedBox(
        width: 200,
        height: 200,
        child: CustomPaint(
          painter: _DonutPainter(
            groups: groups,
            total: totalPaise,
            progress: progress,
            track: scheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Spent',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatRupees(totalPaise / 100),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.groups,
    required this.total,
    required this.progress,
    required this.track,
  });

  final List<SpendGroup> groups;
  final int total;
  final double progress;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final arcRect = (Offset.zero & size).deflate(stroke / 2);

    canvas.drawArc(
      arcRect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final g in groups) {
      final sweep = (g.paise / total) * 2 * math.pi * progress;
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = g.category.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.total != total || old.groups != groups;
}
