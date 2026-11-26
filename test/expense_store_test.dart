import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/services/storage.dart';
import 'package:expense_tracker/state/expense_store.dart';

class _MemoryStorage extends TransactionStorage {
  List<Transaction> saved = [];

  @override
  Future<List<Transaction>> load() async => List.of(saved);

  @override
  Future<void> save(List<Transaction> items) async => saved = List.of(items);
}

Transaction _tx(
  String id,
  TxType type,
  int paise,
  Category category,
  DateTime date,
) => Transaction(
  id: id,
  title: id,
  amountPaise: paise,
  type: type,
  category: category,
  date: date,
);

void main() {
  test('totals only include the selected month', () async {
    final storage = _MemoryStorage()
      ..saved = [
        _tx(
          'salary',
          TxType.income,
          100000,
          Category.salary,
          DateTime(2026, 11, 1),
        ),
        _tx(
          'lunch',
          TxType.expense,
          25050,
          Category.food,
          DateTime(2026, 11, 5),
        ),
        _tx(
          'old',
          TxType.expense,
          9900,
          Category.travel,
          DateTime(2026, 10, 30),
        ),
      ];
    final store = ExpenseStore(storage);
    await store.load();
    store.selectMonthOf(DateTime(2026, 11, 15));

    expect(store.incomePaise, 100000);
    expect(store.expensePaise, 25050);
    expect(store.balancePaise, 74950);
  });

  test('add and remove are persisted', () async {
    final storage = _MemoryStorage();
    final store = ExpenseStore(storage);
    await store.load();

    final t = _tx(
      'coffee',
      TxType.expense,
      15000,
      Category.food,
      DateTime(2026, 11, 20),
    );
    await store.add(t);
    expect(storage.saved.length, 1);

    await store.remove(t.id);
    expect(storage.saved, isEmpty);
  });

  test('category breakdown is sorted largest first', () async {
    final storage = _MemoryStorage()
      ..saved = [
        _tx('a', TxType.expense, 5000, Category.travel, DateTime(2026, 11, 2)),
        _tx('b', TxType.expense, 20000, Category.food, DateTime(2026, 11, 3)),
      ];
    final store = ExpenseStore(storage);
    await store.load();
    store.selectMonthOf(DateTime(2026, 11, 1));

    expect(store.spendBreakdown.first.label, 'Food');
  });
}
