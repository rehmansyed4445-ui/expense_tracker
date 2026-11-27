import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/upcoming.dart';
import 'database.dart';

/// SQLite-backed storage. Every write is one atomic transaction.
/// The old shared_preferences JSON is imported once and then left untouched
/// as a safety net.
class TransactionStorage {
  final AppDatabase _appDb = AppDatabase.instance;

  // Legacy keys (read-only, kept for the migration and as a backup).
  static const _txKey = 'transactions_v1';
  static const _accountKey = 'accounts_v1';
  static const _upcomingKey = 'upcoming_v1';
  static const _budgetKey = 'budgets_v1';
  static const _migratedFlag = 'migrated_to_sqlite_v1';

  // ---------- One-time migration ----------

  Future<void> migrateFromPrefsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedFlag) == true) return;

    final accounts = _prefsList(prefs, _accountKey, Account.fromJson);
    final txs = _prefsList(prefs, _txKey, Transaction.fromJson);
    final upcoming = _prefsList(prefs, _upcomingKey, Upcoming.fromJson);
    final budgets = _prefsBudgets(prefs);

    if (accounts.isEmpty &&
        txs.isEmpty &&
        upcoming.isEmpty &&
        budgets.isEmpty) {
      await prefs.setBool(_migratedFlag, true);
      debugPrint('Migration: nothing to import.');
      return;
    }

    final db = await _appDb.db;
    await db.transaction((txn) async {
      final b = txn.batch();
      for (final a in accounts) {
        b.insert(
          'accounts',
          _accountRow(a),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final t in txs) {
        b.insert(
          'transactions',
          _txRow(t),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final u in upcoming) {
        b.insert(
          'upcoming',
          _upcomingRow(u),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      budgets.forEach((label, paise) {
        b.insert('budgets', {
          'label': label,
          'amount_paise': paise,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
      await b.commit(noResult: true);
    });

    // Only mark done AFTER a successful commit. Old data is never deleted.
    await prefs.setBool(_migratedFlag, true);
    debugPrint(
      'Migration: imported ${accounts.length} accounts, '
      '${txs.length} transactions, ${upcoming.length} upcoming, '
      '${budgets.length} budgets.',
    );
  }

  /// Reads a legacy JSON list, skipping broken items. Falls back to the
  /// `_backup` copy written by the earlier fault-tolerant reader.
  List<T> _prefsList<T>(
    SharedPreferences prefs,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    for (final k in [key, '${key}_backup']) {
      final raw = prefs.getString(k);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) continue;
        final out = <T>[];
        for (final item in decoded) {
          if (item is! Map) continue;
          try {
            out.add(fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('Migration: skipped one item in "$k": $e');
          }
        }
        if (out.isNotEmpty) return out;
      } catch (e) {
        debugPrint('Migration: "$k" unreadable: $e');
      }
    }
    return [];
  }

  Map<String, int> _prefsBudgets(SharedPreferences prefs) {
    final raw = prefs.getString(_budgetKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return {};
      return map.map(
        (k, v) => MapEntry(k.toString(), v is num ? v.round() : 0),
      );
    } catch (e) {
      debugPrint('Migration: budgets unreadable: $e');
      return {};
    }
  }

  // ---------- Row mapping ----------

  Map<String, Object?> _accountRow(Account a) => {
    'id': a.id,
    'name': a.name,
    'starting_paise': a.startingPaise,
    'style_key': a.styleKey,
  };

  Map<String, dynamic> _accountJson(Map<String, Object?> r) => {
    'id': r['id'],
    'name': r['name'],
    'startingPaise': r['starting_paise'],
    'styleKey': r['style_key'],
  };

  Map<String, Object?> _txRow(Transaction t) => {
    'id': t.id,
    'title': t.title,
    'amount_paise': t.amountPaise,
    'type': t.type.name,
    'category': t.category.name,
    'date_ms': t.date.millisecondsSinceEpoch,
    'account_id': t.accountId,
    'to_account_id': t.toAccountId,
    'custom_label': t.customLabel,
  };

  Map<String, dynamic> _txJson(Map<String, Object?> r) => {
    'id': r['id'],
    'title': r['title'],
    'amountPaise': r['amount_paise'],
    'type': r['type'],
    'category': r['category'],
    'date': DateTime.fromMillisecondsSinceEpoch(
      (r['date_ms'] as num).toInt(),
    ).toIso8601String(),
    'accountId': r['account_id'],
    'toAccountId': r['to_account_id'],
    'customLabel': r['custom_label'],
  };

  Map<String, Object?> _upcomingRow(Upcoming u) => {
    'id': u.id,
    'title': u.title,
    'amount_paise': u.amountPaise,
    'due_ms': u.dueDate.millisecondsSinceEpoch,
    'account_id': u.accountId,
    'category': u.category.name,
  };

  Map<String, dynamic> _upcomingJson(Map<String, Object?> r) => {
    'id': r['id'],
    'title': r['title'],
    'amountPaise': r['amount_paise'],
    'dueDate': DateTime.fromMillisecondsSinceEpoch(
      (r['due_ms'] as num).toInt(),
    ).toIso8601String(),
    'accountId': r['account_id'],
    'category': r['category'],
  };

  /// Parses rows one by one so a single bad row can never wipe the list.
  List<T> _parse<T>(
    List<Map<String, Object?>> rows,
    Map<String, dynamic> Function(Map<String, Object?>) toJson,
    T Function(Map<String, dynamic>) fromJson,
    String table,
  ) {
    final out = <T>[];
    for (final r in rows) {
      try {
        out.add(fromJson(toJson(r)));
      } catch (e) {
        debugPrint('Storage: skipped one row in "$table": $e');
      }
    }
    return out;
  }

  /// Atomic replace: if the app dies mid-write, SQLite rolls back and the
  /// previous data survives intact.
  Future<void> _replaceAll(
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    final db = await _appDb.db;
    await db.transaction((txn) async {
      await txn.delete(table);
      final b = txn.batch();
      for (final r in rows) {
        b.insert(table, r, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await b.commit(noResult: true);
    });
  }

  // ---------- Public API (unchanged) ----------

  Future<List<Transaction>> load() async {
    final db = await _appDb.db;
    final rows = await db.query('transactions', orderBy: 'date_ms DESC');
    return _parse(rows, _txJson, Transaction.fromJson, 'transactions');
  }

  Future<void> save(List<Transaction> items) => _replaceAll(
    'transactions',
    items.map<Map<String, Object?>>(_txRow).toList(),
  );

  Future<List<Account>> loadAccounts() async {
    final db = await _appDb.db;
    final rows = await db.query('accounts', orderBy: 'name');
    return _parse(rows, _accountJson, Account.fromJson, 'accounts');
  }

  Future<void> saveAccounts(List<Account> items) => _replaceAll(
    'accounts',
    items.map<Map<String, Object?>>(_accountRow).toList(),
  );
  Future<List<Upcoming>> loadUpcoming() async {
    final db = await _appDb.db;
    final rows = await db.query('upcoming', orderBy: 'due_ms');
    return _parse(rows, _upcomingJson, Upcoming.fromJson, 'upcoming');
  }

  Future<void> saveUpcoming(List<Upcoming> items) => _replaceAll(
    'upcoming',
    items.map<Map<String, Object?>>(_upcomingRow).toList(),
  );

  Future<Map<String, int>> loadBudgets() async {
    final db = await _appDb.db;
    final rows = await db.query('budgets');
    final out = <String, int>{};
    for (final r in rows) {
      final label = r['label']?.toString();
      if (label == null) continue;
      out[label] = (r['amount_paise'] as num?)?.toInt() ?? 0;
    }
    return out;
  }

  Future<void> saveBudgets(Map<String, int> items) => _replaceAll(
    'budgets',
    items.entries
        .map((e) => {'label': e.key, 'amount_paise': e.value})
        .toList(),
  );

  /// Replaces every table in ONE transaction. Used by Restore.
  Future<void> replaceAllData({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required List<Upcoming> upcoming,
    required Map<String, int> budgets,
  }) async {
    final db = await _appDb.db;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('upcoming');
      await txn.delete('budgets');
      await txn.delete('accounts');

      final b = txn.batch();
      for (final a in accounts) {
        b.insert('accounts', _accountRow(a));
      }
      for (final t in transactions) {
        b.insert('transactions', _txRow(t));
      }
      for (final u in upcoming) {
        b.insert('upcoming', _upcomingRow(u));
      }
      budgets.forEach((label, paise) {
        b.insert('budgets', {'label': label, 'amount_paise': paise});
      });
      await b.commit(noResult: true);
    });
  }

  /// Removes an account and everything referencing it in ONE transaction.
  Future<void> deleteAccountCascade(String accountId) async {
    final db = await _appDb.db;
    await db.transaction((txn) async {
      await txn.delete(
        'transactions',
        where: 'account_id = ? OR to_account_id = ?',
        whereArgs: [accountId, accountId],
      );
      await txn.delete(
        'upcoming',
        where: 'account_id = ?',
        whereArgs: [accountId],
      );
      await txn.delete('accounts', where: 'id = ?', whereArgs: [accountId]);
    });
  }

  /// Puts a deleted account and its records back, atomically (Undo).
  Future<void> restoreAccountBundle({
    required Account account,
    required List<Transaction> transactions,
    required List<Upcoming> upcoming,
  }) async {
    final db = await _appDb.db;
    await db.transaction((txn) async {
      final b = txn.batch();
      b.insert(
        'accounts',
        _accountRow(account),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final t in transactions) {
        b.insert(
          'transactions',
          _txRow(t),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final u in upcoming) {
        b.insert(
          'upcoming',
          _upcomingRow(u),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await b.commit(noResult: true);
    });
  }
}
