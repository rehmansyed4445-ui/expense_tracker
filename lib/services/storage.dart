import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/upcoming.dart';

/// Local storage. Each list is saved as one JSON string.
/// Reading is fault tolerant: one broken record can never delete the rest.
class TransactionStorage {
  static const _txKey = 'transactions_v1';
  static const _accountKey = 'accounts_v1';
  static const _upcomingKey = 'upcoming_v1';
  static const _budgetKey = 'budgets_v1';

  Future<List<T>> _readList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];

    List<dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      debugPrint('Storage: "$key" unreadable, keeping backup. $e');
      await prefs.setString('${key}_backup', raw);
      return [];
    }

    final out = <T>[];
    var broken = 0;
    for (final item in decoded) {
      if (item is! Map) {
        broken++;
        continue;
      }
      try {
        out.add(fromJson(Map<String, dynamic>.from(item)));
      } catch (e) {
        broken++;
        debugPrint('Storage: skipped one broken item in "$key": $e');
      }
    }
    // Keep the original text so nothing is ever truly lost.
    if (broken > 0) await prefs.setString('${key}_backup', raw);
    return out;
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
  }

  Future<List<Transaction>> load() => _readList(_txKey, Transaction.fromJson);
  Future<void> save(List<Transaction> items) =>
      _writeList(_txKey, items.map((t) => t.toJson()).toList());

  Future<List<Account>> loadAccounts() =>
      _readList(_accountKey, Account.fromJson);
  Future<void> saveAccounts(List<Account> items) =>
      _writeList(_accountKey, items.map((a) => a.toJson()).toList());

  Future<List<Upcoming>> loadUpcoming() =>
      _readList(_upcomingKey, Upcoming.fromJson);
  Future<void> saveUpcoming(List<Upcoming> items) =>
      _writeList(_upcomingKey, items.map((u) => u.toJson()).toList());

  Future<Map<String, int>> loadBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_budgetKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v is num ? v.round() : 0));
    } catch (e) {
      debugPrint('Storage: budgets unreadable, keeping backup. $e');
      await prefs.setString('${_budgetKey}_backup', raw);
      return {};
    }
  }

  Future<void> saveBudgets(Map<String, int> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_budgetKey, jsonEncode(items));
  }
}
