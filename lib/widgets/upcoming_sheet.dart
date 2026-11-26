import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../models/upcoming.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import 'account_style_picker.dart';
import 'accounts_sheet.dart';
import 'ui.dart';

Future<void> showUpcomingSheet(BuildContext context, ExpenseStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _UpcomingSheet(store: store),
  );
}

class _UpcomingSheet extends StatelessWidget {
  const _UpcomingSheet({required this.store});
  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.upcoming;
        final total = store.upcomingTotalPaise();
        return SheetFrame(
          title: 'Upcoming payments',
          subtitle: items.isEmpty
              ? 'Nothing scheduled'
              : '${formatRupees(total / 100)} across ${items.length} '
                    '${items.length == 1 ? 'payment' : 'payments'}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final u in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _UpcomingTile(store: store, upcoming: u),
                ),
              const SizedBox(height: 6),
              FilledButton.tonalIcon(
                onPressed: () => _openAdd(context, store),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add upcoming payment'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.store, required this.upcoming});
  final ExpenseStore store;
  final Upcoming upcoming;

  String get _accountName {
    for (final a in store.accounts) {
      if (a.id == upcoming.accountId) return a.name;
    }
    return 'No account';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final u = upcoming;
    final today = DateTime.now();
    final overdue = u.dueDate.isBefore(
      DateTime(today.year, today.month, today.day),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: u.category.color.withValues(alpha: 0.18),
                child: Icon(u.category.icon, color: u.category.color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From $_accountName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      overdue
                          ? 'Overdue · ${formatDay(u.dueDate)}'
                          : 'Due ${formatDay(u.dueDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: overdue ? scheme.error : scheme.onSurfaceVariant,
                        fontWeight: overdue ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatRupees(u.amountPaise / 100),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.error,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => store.removeUpcoming(u.id),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
              ),
              const SizedBox(width: 6),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => openPaidFrom(context, store, u),
                child: const Text('Paid'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Paid from which account ----------

void openPaidFrom(BuildContext context, ExpenseStore store, Upcoming u) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PaidFromSheet(store: store, upcoming: u),
  );
}

class _PaidFromSheet extends StatefulWidget {
  const _PaidFromSheet({required this.store, required this.upcoming});
  final ExpenseStore store;
  final Upcoming upcoming;

  @override
  State<_PaidFromSheet> createState() => _PaidFromSheetState();
}

class _PaidFromSheetState extends State<_PaidFromSheet> {
  late String? _accountId;

  @override
  void initState() {
    super.initState();
    final ids = widget.store.accounts.map((a) => a.id).toList();
    _accountId = ids.contains(widget.upcoming.accountId)
        ? widget.upcoming.accountId
        : (ids.isEmpty ? null : ids.first);
  }

  Future<void> _confirm() async {
    final id = _accountId;
    if (id == null) return;
    await widget.store.markUpcomingPaid(widget.upcoming, accountId: id);
    if (!mounted) return;
    showAppToast(context, message: '"${widget.upcoming.title}" marked as paid');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = widget.upcoming;
    return SheetFrame(
      title: 'Paid from',
      subtitle: '${u.title} · ${formatRupees(u.amountPaise / 100)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in widget.store.accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AccountChoice(
                name: a.name,
                styleKey: a.styleKey,
                balancePaise: widget.store.balanceNow(a.id),
                selected: _accountId == a.id,
                onTap: () => setState(() => _accountId = a.id),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _accountId == null ? null : _confirm,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Confirm payment'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable account row: icon, name, live balance, selected tick.
class _AccountChoice extends StatelessWidget {
  const _AccountChoice({
    required this.name,
    required this.styleKey,
    required this.balancePaise,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String styleKey;
  final int balancePaise;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.6)
          : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              AccountAvatar(styleKey: styleKey, radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Balance ${formatRupees(balancePaise / 100)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Add an upcoming payment ----------

void _openAdd(BuildContext context, ExpenseStore store) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _AddUpcomingSheet(store: store),
  );
}

class _AddUpcomingSheet extends StatefulWidget {
  const _AddUpcomingSheet({required this.store});
  final ExpenseStore store;

  @override
  State<_AddUpcomingSheet> createState() => _AddUpcomingSheetState();
}

class _AddUpcomingSheetState extends State<_AddUpcomingSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  DateTime _due = DateTime.now().add(const Duration(days: 7));
  Category _category = Category.bills;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _amount = TextEditingController();
    _accountId =
        widget.store.focusAccount?.id ??
        (widget.store.accounts.isEmpty ? null : widget.store.accounts.first.id);
    widget.store.addListener(_syncAccount);
  }

  /// Keeps a valid account picked, even if one is created from this sheet.
  void _syncAccount() {
    if (!mounted) return;
    final ids = widget.store.accounts.map((a) => a.id).toList();
    if (!ids.contains(_accountId)) {
      setState(() => _accountId = ids.isEmpty ? null : ids.first);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_syncAccount);
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  int get _paise => ((double.tryParse(_amount.text.trim()) ?? 0) * 100).round();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _due = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) {
      showAppToast(context, message: 'Choose the account to pay from');
      return;
    }
    final title = _title.text.trim();
    widget.store.addUpcoming(
      Upcoming(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        amountPaise: _paise,
        dueDate: _due,
        accountId: _accountId!,
        category: _category,
      ),
    );
    showAppToast(context, message: 'Added "$title"');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final store = widget.store;
    final accounts = store.accounts;
    final today = DateTime.now();

    return SheetFrame(
      title: 'Upcoming payment',
      subtitle: 'Plan a bill or EMI before you pay it.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What is it for?',
                hintText: 'Rent, EMI, electricity',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => setState(() {}),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 18),

            // ---- From which account ----
            _label('From which account'),
            if (accounts.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No account yet. Add one so this bill is tied to a balance.',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => showAccountEditor(context, store),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add account'),
                    ),
                  ],
                ),
              )
            else
              for (final a in accounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AccountChoice(
                    name: a.name,
                    styleKey: a.styleKey,
                    balancePaise: store.balanceNow(a.id),
                    selected: _accountId == a.id,
                    onTap: () => setState(() => _accountId = a.id),
                  ),
                ),
            if (accounts.isNotEmpty &&
                _accountId != null &&
                _paise > store.balanceNow(_accountId!))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Heads up: this is more than the current balance.',
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),

            const SizedBox(height: 10),
            _label('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in Category.values)
                  if (c != Category.salary)
                    ChoiceChip(
                      avatar: Icon(c.icon, size: 18, color: c.color),
                      label: Text(c.label),
                      selected: _category == c,
                      selectedColor: c.color.withValues(alpha: 0.25),
                      onSelected: (_) => setState(() => _category = c),
                    ),
              ],
            ),

            const SizedBox(height: 18),
            _label('Due date'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _dueChip(
                  'Tomorrow',
                  DateTime(today.year, today.month, today.day + 1),
                ),
                _dueChip(
                  'In 7 days',
                  DateTime(today.year, today.month, today.day + 7),
                ),
                _dueChip(
                  'Next month',
                  DateTime(today.year, today.month + 1, today.day),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text('Due ${formatDay(_due)}'),
            ),

            const SizedBox(height: 20),
            FilledButton(
              onPressed: accounts.isEmpty ? null : _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Add upcoming payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dueChip(String text, DateTime date) {
    final selected =
        _due.year == date.year &&
        _due.month == date.month &&
        _due.day == date.day;
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => setState(() => _due = date),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}
