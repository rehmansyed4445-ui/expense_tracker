import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../state/expense_store.dart';
import 'account_setup_sheet.dart';
import 'accounts_sheet.dart';
import 'add_transaction_sheet.dart';
import 'transaction_detail_sheet.dart';

Future<bool?> openAccountSetup(BuildContext context, ExpenseStore store) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AccountSetupSheet(store: store),
  );
}

void openAccounts(BuildContext context, ExpenseStore store) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AccountsSheet(store: store),
  );
}

/// Spent or Received. Asks for an account first when none exists yet.
Future<void> startAddFlow(
  BuildContext context,
  ExpenseStore store,
  TxType type,
) async {
  if (!store.hasAccounts) {
    final created = await openAccountSetup(context, store);
    if (created != true || !store.hasAccounts || !context.mounted) return;
  }
  _openTxSheet(context, store, type: type);
}

/// Tapping a transaction opens its details, with Edit and Delete.
void openTransactionEditor(
  BuildContext context,
  ExpenseStore store,
  Transaction tx,
) {
  showTransactionDetail(context, store, tx);
}

void openTransfer(BuildContext context, ExpenseStore store) {
  _openTxSheet(context, store, type: TxType.transfer);
}

void _openTxSheet(
  BuildContext context,
  ExpenseStore store, {
  TxType type = TxType.expense,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AddTransactionSheet(store: store, initialType: type),
  );
}
