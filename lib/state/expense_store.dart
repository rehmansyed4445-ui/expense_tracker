import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/upcoming.dart';
import '../services/storage.dart';

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backup_service.dart';
import '../services/cloud_service.dart';

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

/// Everything needed to undo an account deletion.
class DeletedAccountBundle {
  const DeletedAccountBundle({
    required this.account,
    required this.transactions,
    required this.upcoming,
  });

  final Account account;
  final List<Transaction> transactions;
  final List<Upcoming> upcoming;
}

/// Single source of truth. Widgets listen to it and rebuild.
class ExpenseStore extends ChangeNotifier {
  ExpenseStore(this._storage);

  /// Exposed so Settings can build backups.
  TransactionStorage get storage => _storage;

  final TransactionStorage _storage;
  static final DateTime _farFuture = DateTime(9999);

  List<Transaction> _all = [];
  List<Account> _accounts = [];
  List<Upcoming> _upcoming = [];
  Map<String, int> _budgets = {};
  bool _loaded = false;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedAccountId;

  // ---------- Cloud sync ----------
  // ---------- Cloud sync ----------
  CloudService? _cloud;
  Timer? _syncTimer;
  bool _dirty = false;
  bool _suppressSync = false;
  bool _syncing = false;
  String? _syncError;
  DateTime? lastSyncedAt;

  static const _kDirty = 'local_dirty';
  static const _kTombstones = 'deleted_ids';
  Set<String> _tombstones = {};
  Set<String> _knownIds = {};

  bool get syncing => _syncing;
  String? get syncError => _syncError;
  bool get cloudAttached => _cloud != null;

  /// Whether this device holds any data at all.
  bool get hasAnyData => _hasLocalData;

  void attachCloud(CloudService cloud) => _cloud = cloud;

  void detachCloud() {
    _syncTimer?.cancel();
    _cloud = null;
  }

  /// Call once from main() right after load().
  /// Restores pending-change flag + deletion history that survive restarts.
  Future<void> prepareSyncSafety() async {
    final prefs = await SharedPreferences.getInstance();
    _dirty = prefs.getBool(_kDirty) ?? false;
    _tombstones = (prefs.getStringList(_kTombstones) ?? []).toSet();
    _knownIds = _currentIds();
  }

  Set<String> _currentIds() => {
    ..._all.map((t) => t.id),
    ..._upcoming.map((u) => u.id),
    ..._accounts.map((a) => a.id),
    ..._budgets.keys.map((k) => 'budget:$k'),
  };

  Future<void> _persistTombstones() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _tombstones.toList();
    await prefs.setStringList(
      _kTombstones,
      list.length > 2000 ? list.sublist(list.length - 2000) : list,
    );
  }

  /// Runs after every mutation. Diffs IDs to record deletions / undos.
  void _markDirty() {
    if (_suppressSync) return;

    final current = _currentIds();
    if (_knownIds.isNotEmpty) {
      final removed = _knownIds.difference(current);
      final restored = current.difference(_knownIds);
      if (removed.isNotEmpty) _tombstones.addAll(removed);
      if (restored.isNotEmpty) _tombstones.removeAll(restored);
      if (removed.isNotEmpty || restored.isNotEmpty) _persistTombstones();
    }
    _knownIds = current;

    _dirty = true;
    SharedPreferences.getInstance().then((p) => p.setBool(_kDirty, true));
    _schedulePush();
  }

  void _schedulePush() {
    if (_cloud == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(
      const Duration(milliseconds: 1500),
      () => _pushToCloud(),
    );
  }

  BackupSnapshot _snapshot() => BackupSnapshot(
    accounts: List.of(_accounts),
    transactions: List.of(_all),
    upcoming: List.of(_upcoming),
    budgets: Map.of(_budgets),
    exportedAt: DateTime.now(),
  );

  bool get _hasLocalData =>
      _accounts.isNotEmpty ||
      _all.isNotEmpty ||
      _upcoming.isNotEmpty ||
      _budgets.isNotEmpty;

  /// Union by id. Local wins a true conflict; tombstoned ids are dropped.
  List<T> _mergeById<T>(
    List<T> local,
    List<T> remote,
    String Function(T) idOf,
  ) {
    final map = <String, T>{};
    for (final r in remote) {
      map[idOf(r)] = r;
    }
    for (final l in local) {
      map[idOf(l)] = l;
    }
    map.removeWhere((id, _) => _tombstones.contains(id));
    return map.values.toList();
  }

  Map<String, int> _mergeBudgets(
    Map<String, int> local,
    Map<String, int> remote,
  ) {
    final m = <String, int>{...remote, ...local};
    m.removeWhere((k, _) => _tombstones.contains('budget:$k'));
    return m;
  }

  Future<void> _pushToCloud({bool force = false}) async {
    final cloud = _cloud;
    if (cloud == null) return;
    if (!force && !_dirty) return;
    _syncing = true;
    _syncError = null;
    notifyListeners();
    try {
      await cloud.push(_snapshot());
      _dirty = false;
      lastSyncedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDirty, false);
      await prefs.setString('last_synced_at', lastSyncedAt!.toIso8601String());
    } catch (e) {
      _syncError = 'Sync failed';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _applyLocally(BackupSnapshot s) async {
    _suppressSync = true;
    try {
      _accounts = List.of(s.accounts);
      _all = List.of(s.transactions);
      _upcoming = List.of(s.upcoming);
      _budgets = Map.of(s.budgets);
      final sel = _selectedAccountId;
      if (sel != null && _accountById(sel) == null) _selectedAccountId = null;
      _sortNewestFirst();
      notifyListeners();

      await _storage.replaceAllData(
        accounts: _accounts,
        transactions: _all,
        upcoming: _upcoming,
        budgets: _budgets,
      );

      _knownIds = _currentIds();
      _dirty = false;
      lastSyncedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDirty, false);
      await prefs.setString('last_synced_at', lastSyncedAt!.toIso8601String());
    } finally {
      _suppressSync = false;
    }
  }

  /// Never loses data:
  ///  - cloud empty  -> push local
  ///  - local empty  -> pull cloud
  ///  - both have data -> MERGE, then write both sides
  Future<String> reconcileWithCloud() async {
    final cloud = _cloud;
    if (cloud == null) return 'offline';
    _syncing = true;
    _syncError = null;
    notifyListeners();
    try {
      final remote = await cloud.pull();

      if (remote == null) {
        if (_hasLocalData) {
          await _pushToCloud(force: true);
          return 'pushed';
        }
        return 'empty';
      }

      if (!_hasLocalData) {
        await _applyLocally(remote);
        return 'pulled';
      }

      final merged = BackupSnapshot(
        accounts: _mergeById(_accounts, remote.accounts, (a) => a.id),
        transactions: _mergeById(_all, remote.transactions, (t) => t.id),
        upcoming: _mergeById(_upcoming, remote.upcoming, (u) => u.id),
        budgets: _mergeBudgets(_budgets, remote.budgets),
        exportedAt: DateTime.now(),
      );

      await _applyLocally(merged);
      await _pushToCloud(force: true);
      return 'merged';
    } catch (e) {
      _syncError = 'Sync failed';
      return 'error';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Manual "Sync now" from Settings.
  Future<void> syncNow() async {
    if (_cloud == null) return;
    await _pushToCloud(force: true);
  }

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
      debugPrint('Could not read transactions: $e\n$s');
      _all = [];
    }
    try {
      _accounts = await _storage.loadAccounts();
    } catch (e, s) {
      debugPrint('Could not read accounts: $e\n$s');
      _accounts = [];
    }
    try {
      _upcoming = await _storage.loadUpcoming();
    } catch (e, s) {
      debugPrint('Could not read upcoming payments: $e\n$s');
      _upcoming = [];
    }
    try {
      _budgets = await _storage.loadBudgets();
    } catch (e, s) {
      debugPrint('Could not read budgets: $e\n$s');
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

  // ---------- Deleting accounts ----------

  int transactionCountFor(String accountId) => _all
      .where((t) => t.accountId == accountId || t.toAccountId == accountId)
      .length;

  int upcomingCountFor(String accountId) =>
      _upcoming.where((u) => u.accountId == accountId).length;

  bool hasTransfersFor(String accountId) => _all.any(
    (t) =>
        t.isTransfer &&
        (t.accountId == accountId || t.toAccountId == accountId),
  );

  /// Deletes the account plus its transactions and upcoming payments.
  /// Returns a bundle so the caller can offer Undo.
  Future<DeletedAccountBundle?> deleteAccount(String id) async {
    final account = _accountById(id);
    if (account == null) return null;

    final bundle = DeletedAccountBundle(
      account: account,
      transactions: _all
          .where((t) => t.accountId == id || t.toAccountId == id)
          .toList(),
      upcoming: _upcoming.where((u) => u.accountId == id).toList(),
    );

    _accounts.removeWhere((a) => a.id == id);
    _all.removeWhere((t) => t.accountId == id || t.toAccountId == id);
    _upcoming.removeWhere((u) => u.accountId == id);
    if (_selectedAccountId == id) _selectedAccountId = null;
    notifyListeners();

    await _storage.deleteAccountCascade(id);
    _markDirty();
    return bundle;
  }

  Future<void> restoreAccount(DeletedAccountBundle bundle) async {
    _accounts.add(bundle.account);
    _all.addAll(bundle.transactions);
    _upcoming.addAll(bundle.upcoming);
    _sortNewestFirst();
    notifyListeners();

    await _storage.restoreAccountBundle(
      account: bundle.account,
      transactions: bundle.transactions,
      upcoming: bundle.upcoming,
    );
    _markDirty();
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

  // ---------- Backup / restore ----------

  /// Re-reads everything from storage.
  Future<void> reload() async {
    try {
      _all = await _storage.load();
      _accounts = await _storage.loadAccounts();
      _upcoming = await _storage.loadUpcoming();
      _budgets = await _storage.loadBudgets();
    } catch (e, s) {
      debugPrint('Reload failed: $e\n$s');
    }
    final sel = _selectedAccountId;
    if (sel != null && _accountById(sel) == null) _selectedAccountId = null;
    _sortNewestFirst();
    notifyListeners();
  }

  /// Replaces ALL data with a backup. One atomic write.
  Future<void> replaceAllData({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required List<Upcoming> upcoming,
    required Map<String, int> budgets,
  }) async {
    await _storage.replaceAllData(
      accounts: accounts,
      transactions: transactions,
      upcoming: upcoming,
      budgets: budgets,
    );
    _accounts = List.of(accounts);
    _all = List.of(transactions);
    _upcoming = List.of(upcoming);
    _budgets = Map.of(budgets);
    _selectedAccountId = null;
    _sortNewestFirst();

    // A manual restore is a fresh start: forget old deletions and
    // overwrite the cloud with exactly this snapshot.
    _tombstones.clear();
    await _persistTombstones();
    _knownIds = _currentIds();
    _dirty = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDirty, true);

    notifyListeners();
    _schedulePush();
  }

  // ---------- Search ----------

  /// Searches every transaction in every month, inside the focused account.
  List<Transaction> searchTransactions({
    String query = '',
    TxType? type,
    Category? category,
    bool monthOnly = false,
  }) {
    final q = query.trim().toLowerCase();
    final parsed = double.tryParse(q);
    final amountPaise = parsed == null ? null : (parsed * 100).round();

    Iterable<Transaction> items = _all.where(_inScope);
    if (type != null) items = items.where((t) => t.type == type);
    if (category != null) items = items.where((t) => t.category == category);
    if (monthOnly) items = items.where((t) => _sameMonth(t.date, _month));
    if (q.isEmpty) return items.toList();

    return items.where((t) {
      if (t.title.toLowerCase().contains(q)) return true;
      if (t.groupLabel.toLowerCase().contains(q)) return true;
      if (amountPaise != null && t.amountPaise == amountPaise) return true;
      final from = _accountById(t.accountId)?.name.toLowerCase() ?? '';
      if (from.isNotEmpty && from.contains(q)) return true;
      final to = _accountById(t.toAccountId ?? '')?.name.toLowerCase() ?? '';
      if (to.isNotEmpty && to.contains(q)) return true;
      return false;
    }).toList();
  }

  /// Sum of one type across any list of transactions.
  int sumType(TxType type, Iterable<Transaction> items) =>
      _sumType(type, items);

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
    _markDirty();
  }

  // ---------- Helpers ----------
  void _sortNewestFirst() => _all.sort((a, b) => b.date.compareTo(a.date));

  Future<void> _persistTransactions() async {
    await _storage.save(List.of(_all));
    _markDirty();
  }

  Future<void> _persistAccounts() async {
    await _storage.saveAccounts(List.of(_accounts));
    _markDirty();
  }

  Future<void> _persistUpcoming() async {
    await _storage.saveUpcoming(List.of(_upcoming));
    _markDirty();
  }

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static int _sumType(TxType type, Iterable<Transaction> items) => items
      .where((t) => t.type == type)
      .fold<int>(0, (sum, t) => sum + t.amountPaise);
}
