import 'package:flutter/material.dart';

import '../models/account.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import 'account_style_picker.dart';
import 'quick_add.dart';
import 'ui.dart';

class AccountsSheet extends StatelessWidget {
  const AccountsSheet({super.key, required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final accounts = store.accounts;
        final focusId = store.focusAccount?.id;
        final count = accounts.length;
        final total = accounts.fold<int>(0, (s, a) => s + amountFor(a));
        final past = !store.isCurrentMonth;

        return SheetFrame(
          title: 'Accounts & cash',
          subtitle:
              'Total ${formatRupees(total / 100)} across '
              '$count ${count == 1 ? 'account' : 'accounts'}'
              '${past ? ' · as of ${formatDay(store.monthEnd)}' : ''}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => showAccountEditor(context, store),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add account'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: count < 2
                          ? null
                          : () => openTransfer(context, store),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Move money'),
                    ),
                  ),
                ],
              ),
              if (count < 2)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Add Cash as a second account to move money from your bank to hand cash.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (count == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No accounts yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (count > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AccountRow(
                    selected: focusId == null,
                    title: 'All accounts',
                    subtitle: 'Combined balance',
                    amountPaise: total,
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        Icons.dashboard_rounded,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    onTap: () {
                      store.selectAccount(null);
                      Navigator.pop(context);
                    },
                  ),
                ),
              for (final a in accounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AccountRow(
                    selected: focusId == a.id,
                    title: a.name,
                    subtitle: _upcomingLine(a),
                    subtitleIsAccent:
                        store.upcomingTotalPaise(accountId: a.id) > 0,
                    amountPaise: amountFor(a),
                    leading: AccountAvatar(styleKey: a.styleKey, radius: 22),
                    onTap: () {
                      store.selectAccount(a.id);
                      Navigator.pop(context);
                    },
                    onEdit: () => showAccountEditor(context, store, a),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Current balance in the current month, and the balance at month end for past months.
  int amountFor(Account a) => store.isCurrentMonth
      ? store.balanceNow(a.id)
      : store.balanceAt(a.id, store.monthEnd);

  String _upcomingLine(Account a) {
    final upcoming = store.upcomingTotalPaise(accountId: a.id);
    return upcoming > 0
        ? 'Upcoming ${formatRupees(upcoming / 100)}'
        : 'No upcoming payments';
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.amountPaise,
    required this.leading,
    required this.onTap,
    this.subtitleIsAccent = false,
    this.onEdit,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final int amountPaise;
  final Widget leading;
  final VoidCallback onTap;
  final bool subtitleIsAccent;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtitleIsAccent
                            ? scheme.tertiary
                            : scheme.onSurfaceVariant,
                        fontWeight: subtitleIsAccent
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatRupees(amountPaise / 100),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit account',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add or edit an account: name, current balance and style.
Future<void> showAccountEditor(
  BuildContext context,
  ExpenseStore store, [
  Account? account,
]) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AccountEditor(store: store, account: account),
  );
}

class _AccountEditor extends StatefulWidget {
  const _AccountEditor({required this.store, this.account});

  final ExpenseStore store;
  final Account? account;

  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late String _style;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _balance = TextEditingController(
      text: a == null
          ? ''
          : (widget.store.balanceNow(a.id) / 100).toStringAsFixed(2),
    );
    _style = a?.styleKey ?? 'bank';
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final paise = (double.parse(_balance.text.trim()) * 100).round();
    final a = widget.account;
    if (a == null) {
      await widget.store.addAccount(
        name: _name.text.trim(),
        balancePaise: paise,
        styleKey: _style,
      );
    } else {
      await widget.store.updateAccount(
        id: a.id,
        name: _name.text.trim(),
        balancePaise: paise,
        styleKey: _style,
      );
    }
    if (!mounted) return;
    showAppToast(
      context,
      message: a == null ? 'Account added' : 'Account updated',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.account == null;
    return AppDialog(
      title: isNew ? 'Add account' : 'Edit account',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. HDFC, Cash',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _balance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Current balance',
                prefixText: '₹ ',
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Style', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            AccountStylePicker(
              selectedKey: _style,
              onChanged: (k) => setState(() => _style = k),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
