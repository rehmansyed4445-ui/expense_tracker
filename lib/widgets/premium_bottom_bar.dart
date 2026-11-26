import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted-glass panel. Used by the bottom bar and the notice bubble.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.radius = 28});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: isDark ? 0.45 : 0.55),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.6),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Floating bottom bar: [Home ›] or [‹ Reports], then Spent, Received, Budgets, Upcoming.
class PremiumBottomBar extends StatelessWidget {
  const PremiumBottomBar({
    super.key,
    required this.onHome,
    required this.onSwitchView,
    required this.onSpent,
    required this.onReceived,
    required this.onBudgets,
    required this.onUpcoming,
  });

  /// True on the Home page. The first item then points right to Reports, and the reverse on Reports.
  final bool onHome;
  final VoidCallback onSwitchView;
  final VoidCallback onSpent;
  final VoidCallback onReceived;
  final VoidCallback onBudgets;
  final VoidCallback onUpcoming;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: GlassPanel(
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  _ViewSwitch(onHome: onHome, onTap: onSwitchView),
                  _NavItem(
                    icon: Icons.north_east_rounded,
                    label: 'Spent',
                    color: scheme.error,
                    onTap: onSpent,
                  ),
                  _NavItem(
                    icon: Icons.south_west_rounded,
                    label: 'Received',
                    color: const Color(0xFF2E7D32),
                    onTap: onReceived,
                  ),
                  _NavItem(
                    icon: Icons.pie_chart_rounded,
                    label: 'Budgets',
                    color: scheme.tertiary,
                    onTap: onBudgets,
                  ),
                  _NavItem(
                    icon: Icons.event_rounded,
                    label: 'Upcoming',
                    color: const Color(0xFFF57C00),
                    onTap: onUpcoming,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Home or Reports, with an arrow that shows where the other screen is.
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.onHome, required this.onTap});

  final bool onHome;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.primary;
    final icon = onHome ? Icons.home_rounded : Icons.bar_chart_rounded;
    final label = onHome ? 'Home' : 'Reports';
    final arrow = onHome
        ? Icons.chevron_right_rounded
        : Icons.chevron_left_rounded;

    final circle = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 18),
    );
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
    );
    final arrowIcon = Icon(arrow, size: 18, color: color);

    return Expanded(
      flex: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            child: KeyedSubtree(
              key: ValueKey(onHome),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: onHome
                      ? [circle, const SizedBox(width: 4), text, arrowIcon]
                      : [arrowIcon, circle, const SizedBox(width: 4), text],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glass bubble above the bar. Shows a hint and can be closed.
class NoticeBubble extends StatelessWidget {
  const NoticeBubble({
    super.key,
    required this.text,
    required this.onView,
    required this.onClose,
  });

  final String text;
  final VoidCallback onView;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: GlassPanel(
          radius: 20,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onView,
                  child: Text(
                    'View',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
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
