import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/account_style.dart';
import '../models/transaction.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import 'ui.dart';

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({
    super.key,
    required this.store,
    this.initialType = TxType.expense,
    this.existing,
  });

  final ExpenseStore store;
  final TxType initialType;
  final Transaction? existing;

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _customController;

  late TxType _type;
  late String _accountId;
  String? _toAccountId;
  late Category _category;
  late DateTime _date;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final store = widget.store;
    final defaultAccount =
        store.focusAccount?.id ??
        (store.accounts.isEmpty ? '' : store.accounts.first.id);
    final storedId = e?.accountId ?? '';

    _type = e?.type ?? widget.initialType;
    _accountId = storedId.isNotEmpty ? storedId : defaultAccount;
    _toAccountId = e?.toAccountId ?? _otherAccount(_accountId);
    _category = e?.category ?? Category.food;
    _date = e?.date ?? DateTime.now();
    _titleController = TextEditingController(text: e?.title ?? '');
    _amountController = TextEditingController(
      text: e == null ? '' : _rupeesText(e.amountPaise),
    );
    _customController = TextEditingController(text: e?.customLabel ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _customController.dispose();
    super.dispose();
  }

  static String _rupeesText(int paise) =>
      (paise / 100).toStringAsFixed(paise % 100 == 0 ? 0 : 2);

  String? _otherAccount(String except) {
    for (final a in widget.store.accounts) {
      if (a.id != except) return a.id;
    }
    return null;
  }

  String _nameOf(String? id) {
    for (final a in widget.store.accounts) {
      if (a.id == id) return a.name;
    }
    return 'account';
  }

  int get _paise =>
      ((double.tryParse(_amountController.text.trim()) ?? 0) * 100).round();

  /// Money available in the source account, counting the saved amount when editing.
  int get _availablePaise {
    var b = widget.store.balanceNow(_accountId);
    final e = widget.existing;
    if (e != null && e.accountId == _accountId && e.type != TxType.income) {
      b += e.amountPaise;
    }
    return b;
  }

  bool get _canSave {
    if (_accountId.isEmpty) return false;
    if (!widget.store.accounts.any((a) => a.id == _accountId)) return false;
    if (_type == TxType.transfer) {
      return widget.store.accounts.length > 1 &&
          _toAccountId != null &&
          _toAccountId != _accountId;
    }
    return true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_canSave) return;
    setState(() => _saving = true);

    final custom = _customController.text.trim();
    final isTransfer = _type == TxType.transfer;
    final tx = Transaction(
      id:
          widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: isTransfer
          ? (_titleController.text.trim().isEmpty
                ? 'To ${_nameOf(_toAccountId)}'
                : _titleController.text.trim())
          : _titleController.text.trim(),
      amountPaise: _paise,
      type: _type,
      category: isTransfer ? Category.other : _category,
      date: _date,
      accountId: _accountId,
      toAccountId: isTransfer ? _toAccountId : null,
      customLabel:
          !isTransfer && _category == Category.other && custom.isNotEmpty
          ? custom
          : null,
    );

    widget.store.selectMonthOf(_date);
    if (_isEdit) {
      await widget.store.update(tx);
    } else {
      await widget.store.add(tx);
    }
    if (!mounted) return;
    showAppToast(context, message: _isEdit ? 'Changes saved' : 'Saved');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final store = widget.store;
    final isTransfer = _type == TxType.transfer;
    final overdrawn = _type != TxType.income && _paise > _availablePaise;

    return SheetFrame(
      title: _isEdit ? 'Edit transaction' : 'New transaction',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(
                  value: TxType.expense,
                  label: Text('Spent'),
                  icon: Icon(Icons.north_east_rounded),
                ),
                ButtonSegment(
                  value: TxType.income,
                  label: Text('Received'),
                  icon: Icon(Icons.south_west_rounded),
                ),
                ButtonSegment(
                  value: TxType.transfer,
                  label: Text('Move'),
                  icon: Icon(Icons.swap_horiz_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            if (store.accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Add an account first to log a transaction.',
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            TextFormField(
              controller: _amountController,
              autofocus: !_isEdit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            if (overdrawn)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Only ${formatRupees(_availablePaise / 100)} available in ${_nameOf(_accountId)}',
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            if (isTransfer) ...[
              _label('From'),
              _accountPicker(
                selected: _accountId,
                onPick: (id) => setState(() {
                  _accountId = id;
                  if (_toAccountId == id) _toAccountId = _otherAccount(id);
                }),
              ),
              const SizedBox(height: 12),
              _label('To'),
              _accountPicker(
                selected: _toAccountId,
                exclude: _accountId,
                onPick: (id) => setState(() => _toAccountId = id),
              ),
              if (!_canSave)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Add a second account, such as Cash, to move money.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ] else ...[
              _label('Account'),
              _accountPicker(
                selected: _accountId,
                onPick: (id) => setState(() => _accountId = id),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'What was it for?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 16),
              _label('Category'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in Category.values)
                    if (c != Category.salary || _type == TxType.income)
                      ChoiceChip(
                        avatar: Icon(c.icon, size: 18, color: c.color),
                        label: Text(c.label),
                        selected: _category == c,
                        selectedColor: c.color.withValues(alpha: 0.25),
                        onSelected: (_) => setState(() => _category = c),
                      ),
                ],
              ),
              if (_category == Category.other) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Name this "Other" spend',
                    hintText: 'e.g. Gifts, Pet care',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (store.customLabels.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in store.customLabels)
                        ActionChip(
                          label: Text(name),
                          onPressed: () =>
                              setState(() => _customController.text = name),
                        ),
                    ],
                  ),
                ],
              ],
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(formatDay(_date)),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_saving || !_canSave) ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_isEdit ? 'Save changes' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  Widget _accountPicker({
    required String? selected,
    required ValueChanged<String> onPick,
    String? exclude,
  }) {
    final accounts = widget.store.accounts
        .where((a) => a.id != exclude)
        .toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in accounts)
          ChoiceChip(
            avatar: Icon(
              styleFor(a.styleKey).icon,
              size: 18,
              color: styleFor(a.styleKey).color,
            ),
            label: Text(a.name),
            selected: selected == a.id,
            onSelected: (_) => onPick(a.id),
          ),
      ],
    );
  }
}
