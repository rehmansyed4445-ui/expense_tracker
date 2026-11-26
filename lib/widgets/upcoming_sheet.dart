import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../models/upcoming.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import 'account_style_picker.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final u = upcoming;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: u.category.color.withValues(alpha: 0.18),
            child: Icon(u.category.icon, color: u.category.color, size: 20),
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Due ${formatDay(u.dueDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatRupees(u.amountPaise / 100),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => store.removeUpcoming(u.id),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
          FilledButton.tonal(
            onPressed: () => openPaidFrom(context, store, u),
            child: const Text('Paid'),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
              child: Material(
                color: _accountId == a.id
                    ? scheme.primaryContainer.withValues(alpha: 0.6)
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => setState(() => _accountId = a.id),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        AccountAvatar(styleKey: a.styleKey, radius: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            a.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(formatRupees(widget.store.balanceNow(a.id) / 100)),
                        const SizedBox(width: 10),
                        Icon(
                          _accountId == a.id
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: _accountId == a.id
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
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
  late final TextEditingController _title;
  late final TextEditingController _amount;
  DateTime _due = DateTime.now().add(const Duration(days: 7));
  Category _category = Category.bills;
  late String? _accountId;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _amount = TextEditingController();
    final store = widget.store;
    _accountId =
        store.focusAccount?.id ??
        (store.accounts.isEmpty ? null : store.accounts.first.id);
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

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
    final title = _title.text.trim();
    final rupees = double.tryParse(_amount.text.trim()) ?? 0;
    if (title.isEmpty || rupees <= 0 || _accountId == null) {
      showAppToast(context, message: 'Add a title and a valid amount');
      return;
    }
    widget.store.addUpcoming(
      Upcoming(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        amountPaise: (rupees * 100).round(),
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
    final store = widget.store;
    return SheetFrame(
      title: 'Upcoming payment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'What is it for?',
              hintText: 'Rent, EMI, electricity',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                    onSelected: (_) => setState(() => _category = c),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in store.accounts)
                ChoiceChip(
                  avatar: AccountAvatar(styleKey: a.styleKey, radius: 10),
                  label: Text(a.name),
                  selected: _accountId == a.id,
                  onSelected: (_) => setState(() => _accountId = a.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text('Due ${formatDay(_due)}'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Add')),
        ],
      ),
    );
  }
}
