import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/account.dart';
import '../models/transaction.dart';
import '../models/upcoming.dart';
import '../services/storage.dart';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;

class DayTotal {
  const DayTotal(this.day, this.expensePaise);

  final DateTime day;
  final int expensePaise;
}

class SpendGroup {
  const SpendGroup(this.label, this.category, this.paise);

  final String label;
  final Category category;
  final int paise;
}

/// Single source of truth. Widgets listen to it and rebuild.
class ExpenseStore extends ChangeNotifier {
  ExpenseStore(this._storage);

  final TransactionStorage _storage;
  static final DateTime _farFuture = DateTime(9999);

  List<Transaction> _all = [];
  List<Account> _accounts = [];
  List<Upcoming> _upcoming = [];
  Map<String, int> _budgets = {};
  bool _loaded = false;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedAccountId;

  // ---------- Basics ----------

  bool get isLoaded => _loaded;
  DateTime get month => _month;
  bool get isCurrentMonth => _sameMonth(_month, DateTime.now());
  DateTime get monthEnd =>
      DateTime(_month.year, _month.month + 1, 0, 23, 59, 59);

  Future<void> load() async {
    try {
      _all = await _storage.load();
    } catch (e, s) {
      debugPrint('Could not read transactions: $e\n$s'); // FIXED: Added \n
      _all = [];
    }
    try {
      _accounts = await _storage.loadAccounts();
    } catch (e, s) {
      debugPrint('Could not read accounts: $e\n$s'); // FIXED
      _accounts = [];
    }
    try {
      _upcoming = await _storage.loadUpcoming();
    } catch (e, s) {
      debugPrint('Could not read upcoming payments: $e\n$s'); // FIXED
      _upcoming = [];
    }
    try {
      _budgets = await _storage.loadBudgets();
    } catch (e, s) {
      debugPrint('Could not read budgets: $e\n$s'); // FIXED
      _budgets = {};
    }
    _sortNewestFirst();
    _loaded = true;
    notifyListeners();
  }

  // ---------- Accounts and scope ----------

  List<Account> get accounts => List.unmodifiable(_accounts);
  bool get hasAccounts => _accounts.isNotEmpty;

  /// The account the screen is focused on, or null for "all accounts".
  Account? get focusAccount {
    final id = _selectedAccountId;
    if (id != null) {
      for (final a in _accounts) {
        if (a.id == id) return a;
      }
    }
    return _accounts.length == 1 ? _accounts.first : null;
  }

  String get scopeName =>
      focusAccount?.name ?? (hasAccounts ? 'All accounts' : 'Your money');

  void selectAccount(String? id) {
    _selectedAccountId = id;
    notifyListeners();
  }

  bool _inScope(Transaction t) {
    final f = focusAccount;
    if (f == null) return true;
    return t.accountId == f.id || t.toAccountId == f.id;
  }

  Account? _accountById(String id) {
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  // ---------- Balances ----------

  /// Balance of one account as of [until]. Transfers move money between accounts.
  int balanceAt(String accountId, DateTime until) {
    final account = _accountById(accountId);
    if (account == null) return 0;
    var net = 0;
    for (final t in _all) {
      if (t.date.isAfter(until)) continue;
      switch (t.type) {
        case TxType.income:
          if (t.accountId == accountId) net += t.amountPaise;
        case TxType.expense:
          if (t.accountId == accountId) net -= t.amountPaise;
        case TxType.transfer:
          if (t.accountId == accountId) net -= t.amountPaise;
          if (t.toAccountId == accountId) net += t.amountPaise;
      }
    }
    return account.startingPaise + net;
  }

  int balanceNow(String accountId) => balanceAt(accountId, _farFuture);

  int get totalAllBalancePaise =>
      _accounts.fold<int>(0, (sum, a) => sum + balanceNow(a.id));

  /// Balance for the focused account (or all accounts), right now.
  int get scopeBalancePaise {
    final f = focusAccount;
    if (f != null) return balanceNow(f.id);
    return totalAllBalancePaise;
  }

  /// Balance for the focused account (or all accounts) at the end of the selected month.
  int get scopeBalanceAtMonthEnd {
    final f = focusAccount;
    if (f != null) return balanceAt(f.id, monthEnd);
    return _accounts.fold<int>(0, (sum, a) => sum + balanceAt(a.id, monthEnd));
  }

  /// Shown on the account card: live balance this month, month-end for past months.
  int get periodBalancePaise =>
      isCurrentMonth ? scopeBalancePaise : scopeBalanceAtMonthEnd;

  Future<void> addAccount({
    required String name,
    required int balancePaise,
    String styleKey = 'bank',
  }) async {
    _accounts.add(
      Account(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        startingPaise: balancePaise,
        styleKey: styleKey,
      ),
    );
    notifyListeners();
    await _persistAccounts();
  }

  /// Edits name, style and current balance. The starting amount is recomputed
  /// so the balance matches what the user typed.
  Future<void> updateAccount({
    required String id,
    required String name,
    required int balancePaise,
    required String styleKey,
  }) async {
    final i = _accounts.indexWhere((a) => a.id == id);
    if (i == -1) return;
    final current = _accounts[i];
    final net = balanceNow(id) - current.startingPaise;
    _accounts[i] = Account(
      id: id,
      name: name,
      startingPaise: balancePaise - net,
      styleKey: styleKey,
    );
    notifyListeners();
    await _persistAccounts();
  }

  // ---------- Month and totals ----------

  List<Transaction> get monthTransactions =>
      _all.where((t) => _sameMonth(t.date, _month) && _inScope(t)).toList();

  int get incomePaise => _sumType(TxType.income, monthTransactions);
  int get expensePaise => _sumType(TxType.expense, monthTransactions);
  int get balancePaise => incomePaise - expensePaise;

  int expenseForMonth(DateTime m) => _sumType(
    TxType.expense,
    _all.where((t) => _sameMonth(t.date, m) && _inScope(t)),
  );

  void changeMonth(int delta) {
    _month = DateTime(_month.year, _month.month + delta);
    notifyListeners();
  }

  void selectMonthOf(DateTime date) {
    _month = DateTime(date.year, date.month);
    notifyListeners();
  }

  // ---------- Reports ----------

  /// Expense totals per category for the selected month, largest first.
  Map<Category, int> get expenseByCategory {
    final totals = <Category, int>{};
    for (final t in monthTransactions) {
      if (t.type != TxType.expense) continue;
      totals.update(
        t.category,
        (v) => v + t.amountPaise,
        ifAbsent: () => t.amountPaise,
      );
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  /// Expense totals grouped by name (custom names for Other), largest first.
  List<SpendGroup> get spendBreakdown {
    final totals = <String, int>{};
    final categories = <String, Category>{};
    for (final t in monthTransactions) {
      if (t.type != TxType.expense) continue;
      final key = t.groupLabel;
      totals.update(
        key,
        (v) => v + t.amountPaise,
        ifAbsent: () => t.amountPaise,
      );
      categories.putIfAbsent(key, () => t.category);
    }
    final groups = [
      for (final e in totals.entries)
        SpendGroup(e.key, categories[e.key]!, e.value),
    ]..sort((a, b) => b.paise.compareTo(a.paise));
    return groups;
  }

  List<Transaction> transactionsFor(String label) => monthTransactions
      .where((t) => t.type == TxType.expense && t.groupLabel == label)
      .toList();

  /// Custom "Other" names used before, for quick picks.
  List<String> get customLabels {
    final names = <String>{};
    for (final t in _all) {
      final c = t.customLabel?.trim();
      if (c != null && c.isNotEmpty) names.add(c);
    }
    return names.toList();
  }

  /// Daily spend from the first logged day, up to [maxDays] days ending today.
  List<DayTotal> recentDayTotals({int maxDays = 7}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final spends = _all
        .where((t) => t.type == TxType.expense && _inScope(t))
        .toList();
    if (spends.isEmpty) return [];

    final first = spends
        .map((t) => DateTime(t.date.year, t.date.month, t.date.day))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final span = today.difference(first).inDays + 1;
    final count = span > maxDays ? maxDays : span;
    final start = DateTime(today.year, today.month, today.day - (count - 1));

    return List.generate(count, (i) {
      final day = DateTime(start.year, start.month, start.day + i);
      final total = spends
          .where(
            (t) =>
                t.date.year == day.year &&
                t.date.month == day.month &&
                t.date.day == day.day,
          )
          .fold<int>(0, (sum, t) => sum + t.amountPaise);
      return DayTotal(day, total);
    });
  }

  // ---------- Transactions ----------

  Future<void> add(Transaction t) async {
    _all.add(t);
    _sortNewestFirst();
    notifyListeners();
    await _persistTransactions();
  }

  Future<void> update(Transaction t) async {
    final i = _all.indexWhere((x) => x.id == t.id);
    if (i == -1) return;
    _all[i] = t;
    _sortNewestFirst();
    notifyListeners();
    await _persistTransactions();
  }

  Future<void> remove(String id) async {
    _all.removeWhere((t) => t.id == id);
    notifyListeners();
    await _persistTransactions();
  }

  // ---------- Upcoming payments ----------

  List<Upcoming> get upcoming {
    final list = List.of(_upcoming)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  int upcomingTotalPaise({String? accountId}) => _upcoming
      .where((u) => accountId == null || u.accountId == accountId)
      .fold<int>(0, (sum, u) => sum + u.amountPaise);

  int get scopeUpcomingPaise => upcomingTotalPaise(accountId: focusAccount?.id);

  Future<void> addUpcoming(Upcoming u) async {
    _upcoming.add(u);
    notifyListeners();
    await _persistUpcoming();
  }

  Future<void> removeUpcoming(String id) async {
    _upcoming.removeWhere((u) => u.id == id);
    notifyListeners();
    await _persistUpcoming();
  }

  /// Turns an upcoming payment into a spend today. [accountId] is the account
  /// the money came from; it defaults to the account the payment was planned on.
  Future<void> markUpcomingPaid(Upcoming u, {String? accountId}) async {
    final i = _upcoming.indexWhere((x) => x.id == u.id);
    if (i == -1) return;
    _upcoming.removeAt(i);
    final now = DateTime.now();
    _all.add(
      Transaction(
        id: now.microsecondsSinceEpoch.toString(),
        title: u.title,
        amountPaise: u.amountPaise,
        type: TxType.expense,
        category: u.category,
        date: now,
        accountId: accountId ?? u.accountId,
      ),
    );
    _sortNewestFirst();
    notifyListeners();
    await Future.wait<void>([_persistTransactions(), _persistUpcoming()]);
  }

  // ---------- Budgets ----------

  Map<String, int> get budgets => Map.unmodifiable(_budgets);

  int? budgetFor(String label) => _budgets[label];

  int spentFor(String label) => _sumType(
    TxType.expense,
    monthTransactions.where((t) => t.groupLabel == label),
  );

  /// Pass null (or 0) to remove the budget.
  Future<void> setBudget(String label, int? paise) async {
    if (paise == null || paise <= 0) {
      _budgets.remove(label);
    } else {
      _budgets[label] = paise;
    }
    notifyListeners();
    await _storage.saveBudgets(Map.of(_budgets));
  }

  // ---------- Helpers ----------

  void _sortNewestFirst() => _all.sort((a, b) => b.date.compareTo(a.date));

  Future<void> _persistTransactions() => _storage.save(List.of(_all));
  Future<void> _persistAccounts() => _storage.saveAccounts(List.of(_accounts));
  Future<void> _persistUpcoming() => _storage.saveUpcoming(List.of(_upcoming));

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static int _sumType(TxType type, Iterable<Transaction> items) => items
      .where((t) => t.type == type)
      .fold<int>(0, (sum, t) => sum + t.amountPaise);
}
