import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/backup_service.dart';
import '../services/auth_service.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

Future<void> openSettings(
  BuildContext context,
  ExpenseStore store,
  AuthService auth,
) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SettingsScreen(store: store, auth: auth),
    ),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store, required this.auth});
  final ExpenseStore store;
  final AuthService auth;

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '$d.inDays day${d.inDays == 1 ? "" : "s"} ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _section(theme, 'Data'),
          _tile(
            context,
            icon: Icons.save_alt_rounded,
            color: scheme.primary,
            title: 'Export backup',
            subtitle: 'A .json file with everything. Use it to restore later.',
            onTap: () => _guard(
              context,
              () => BackupService(store.storage).exportJson(),
            ),
          ),
          _tile(
            context,
            icon: Icons.table_view_rounded,
            color: const Color(0xFF2E7D32),
            title: 'Export CSV',
            subtitle: 'Open your transactions in Excel or Google Sheets.',
            onTap: () =>
                _guard(context, () => BackupService(store.storage).exportCsv()),
          ),
          _tile(
            context,
            icon: Icons.settings_backup_restore_rounded,
            color: scheme.tertiary,
            title: 'Restore from backup',
            subtitle: 'Replaces all current data with a .json backup.',
            onTap: () => _restore(context),
          ),

          if (!auth.isGuest) ...[
            const SizedBox(height: 24),
            _section(theme, 'Cloud'),
            ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final user = FirebaseAuth.instance.currentUser;
                final sub = user == null
                    ? 'Not signed in — your data stays on this device'
                    : store.syncing
                    ? 'Syncing…'
                    : store.lastSyncedAt != null
                    ? 'Signed in as ${user.email} · synced ${_ago(store.lastSyncedAt!)}'
                    : 'Signed in as ${user.email} · not synced yet';
                return _tile(
                  context,
                  icon: store.syncing
                      ? Icons.cloud_upload_rounded
                      : user != null
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: store.syncError != null
                      ? scheme.error
                      : scheme.tertiary,
                  title: 'Cloud sync',
                  subtitle: store.syncError != null
                      ? '$sub · ${store.syncError}'
                      : sub,
                  onTap: user == null ? null : () => store.syncNow(),
                );
              },
            ),
          ],

          const SizedBox(height: 24),
          _section(theme, 'About'),
          _tile(
            context,
            icon: Icons.info_outline_rounded,
            color: scheme.onSurfaceVariant,
            title: 'Version',
            subtitle: '1.0.0',
            onTap: null,
          ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Expenses is a personal budgeting tool. It is not a bank, '
              'payment service or financial advisor. All data stays on this '
              'device unless you export it yourself or sign in to sync.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guard(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    bool ok = false;
    try {
      ok = await action();
    } catch (e) {
      debugPrint('Settings action failed: $e');
    }
    if (context.mounted && ok) {
      showAppToast(context, message: 'File saved');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final snapshot = await BackupService(store.storage).pickBackup();
    if (!context.mounted) return;

    if (snapshot == null) {
      showAppToast(context, message: 'That file is not a valid backup');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RestoreDialog(snapshot: snapshot, store: store),
    );
    if (confirmed != true || !context.mounted) return;

    await store.replaceAllData(
      accounts: snapshot.accounts,
      transactions: snapshot.transactions,
      upcoming: snapshot.upcoming,
      budgets: snapshot.budgets,
    );
    if (context.mounted) {
      showAppToast(context, message: 'Backup restored');
    }
  }

  Widget _section(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 4),
    child: Text(
      text.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestoreDialog extends StatelessWidget {
  const _RestoreDialog({required this.snapshot, required this.store});
  final BackupSnapshot snapshot;
  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = snapshot;

    return AppDialog(
      title: 'Restore this backup?',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exported ${formatDay(s.exportedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _line('${s.accounts.length} accounts'),
          _line('${s.transactions.length} transactions'),
          _line('${s.upcoming.length} upcoming payments'),
          _line('${s.budgets.length} budgets'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Everything on this device right now will be replaced. '
                    'Export a backup first if you are not sure.',
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Replace data'),
        ),
      ],
    );
  }

  Widget _line(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        const Icon(Icons.check_rounded, size: 16),
        const SizedBox(width: 8),
        Text(text),
      ],
    ),
  );
}
