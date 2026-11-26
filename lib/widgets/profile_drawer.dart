import 'package:flutter/material.dart';

import '../state/expense_store.dart';
import '../utils/format.dart';
import 'quick_add.dart';
import 'upcoming_sheet.dart';

/// Round avatar in the Home header. Tapping it opens the drawer.
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: () => Scaffold.of(context).openDrawer(),
      radius: 28,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
        ),
        child: Icon(Icons.person_rounded, color: scheme.onPrimary),
      ),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({
    super.key,
    required this.store,
    required this.hostContext,
    required this.onOpenReports,
  });

  final ExpenseStore store;

  /// Context of the home screen. Sheets open from here, because the drawer closes first.
  final BuildContext hostContext;
  final VoidCallback onOpenReports;

  void _run(BuildContext drawerContext, VoidCallback action) {
    Navigator.of(drawerContext).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = store.accounts.length;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: scheme.onPrimary.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.person_rounded,
                      color: scheme.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    formatRupees(store.totalAllBalancePaise / 100),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Total across $count ${count == 1 ? 'account' : 'accounts'}',
                    style: TextStyle(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _tile(
              context,
              icon: Icons.account_balance_wallet_rounded,
              title: 'Accounts & cash',
              subtitle: 'Balances, cash and transfers',
              onTap: () =>
                  _run(context, () => openAccounts(hostContext, store)),
            ),
            _tile(
              context,
              icon: Icons.event_rounded,
              title: 'Upcoming payments',
              subtitle: 'Bills and EMIs to pay',
              onTap: () =>
                  _run(context, () => showUpcomingSheet(hostContext, store)),
            ),
            _tile(
              context,
              icon: Icons.bar_chart_rounded,
              title: 'Reports',
              subtitle: 'Charts and category details',
              onTap: () => _run(context, onOpenReports),
            ),
            _tile(
              context,
              icon: Icons.settings_rounded,
              title: 'Settings',
              subtitle: 'Coming soon',
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}
