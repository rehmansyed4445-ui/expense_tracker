import 'package:flutter/material.dart';
import '../state/expense_store.dart';
import '../services/auth_service.dart';
import '../screens/settings_screen.dart';
import '../widgets/budgets.dart';
import '../widgets/upcoming_sheet.dart';

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({
    super.key,
    required this.store,
    required this.auth,
    required this.hostContext,
    required this.onOpenReports,
  });

  final ExpenseStore store;
  final AuthService auth;
  final BuildContext hostContext;
  final VoidCallback onOpenReports;

  void _closeAndRun(VoidCallback action) {
    Navigator.pop(hostContext); // Close drawer first
    Future.delayed(const Duration(milliseconds: 300), () {
      action(); // Then trigger the sign out/route change
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 32, left: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        auth.isGuest ? Icons.person_outline : Icons.person,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.isGuest
                                ? 'Guest User'
                                : (auth.displayName ?? 'User'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            auth.isGuest
                                ? 'Local data only'
                                : (auth.email ?? ''),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              _tile(
                context,
                icon: Icons.pie_chart_rounded,
                title: 'Reports',
                subtitle: 'Spending breakdown',
                onTap: () => _closeAndRun(onOpenReports),
              ),
              _tile(
                context,
                icon: Icons.upcoming_rounded,
                title: 'Upcoming',
                subtitle: '${store.upcoming.length} payments',
                onTap: () =>
                    _closeAndRun(() => showUpcomingSheet(hostContext, store)),
              ),
              _tile(
                context,
                icon: Icons.track_changes_rounded,
                title: 'Budgets',
                subtitle: 'Monthly limits',
                onTap: () =>
                    _closeAndRun(() => showBudgetSheet(hostContext, store)),
              ),

              const Divider(height: 32),

              _tile(
                context,
                icon: Icons.settings_rounded,
                title: 'Settings',
                subtitle: 'Backup, export and restore',
                onTap: () =>
                    _closeAndRun(() => openSettings(hostContext, store, auth)),
              ),

              const Spacer(),

              if (auth.isGuest)
                _tile(
                  context,
                  icon: Icons.login_rounded,
                  title: 'Sign in to sync',
                  subtitle: 'Save your data to the cloud',
                  onTap: () => _closeAndRun(() => auth.signOut()),
                )
              else
                _tile(
                  context,
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  subtitle: auth.email ?? 'Your account',
                  onTap: () => _closeAndRun(() => auth.signOut()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: scheme.onSurfaceVariant, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
