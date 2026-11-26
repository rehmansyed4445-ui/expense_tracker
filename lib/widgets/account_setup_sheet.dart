import 'package:flutter/material.dart';

import '../state/expense_store.dart';
import 'account_style_picker.dart';
import 'ui.dart';

class AccountSetupSheet extends StatefulWidget {
  const AccountSetupSheet({super.key, required this.store});

  final ExpenseStore store;

  @override
  State<AccountSetupSheet> createState() => _AccountSetupSheetState();
}

class _AccountSetupSheetState extends State<AccountSetupSheet> {
  final _name = TextEditingController(text: 'Main account');
  final _balance = TextEditingController();
  String _style = 'bank';

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _name.text.trim();
    final rupees = double.tryParse(_balance.text.trim());
    if (name.isEmpty || rupees == null) {
      showAppToast(context, message: 'Enter a name and the current balance');
      return;
    }
    await widget.store.addAccount(
      name: name,
      balancePaise: (rupees * 100).round(),
      styleKey: _style,
    );
    if (!mounted) return;
    showAppToast(context, message: 'Account added. Log your first spend.');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Add your account',
      subtitle:
          'Enter the balance you have there right now. You can add cash and more accounts later.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Account name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Current balance',
              prefixText: '₹ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Style', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          AccountStylePicker(
            selectedKey: _style,
            onChanged: (k) => setState(() => _style = k),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _start,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text("Let's go"),
            ),
          ),
        ],
      ),
    );
  }
}
