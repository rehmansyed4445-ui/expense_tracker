import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/upcoming.dart';
import 'backup_writer_stub.dart' if (dart.library.io) 'backup_writer_io.dart';
import 'storage.dart';

/// Everything a backup contains.
class BackupSnapshot {
  const BackupSnapshot({
    required this.accounts,
    required this.transactions,
    required this.upcoming,
    required this.budgets,
    required this.exportedAt,
  });

  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<Upcoming> upcoming;
  final Map<String, int> budgets;
  final DateTime exportedAt;
}

/// Export to JSON (restore) or CSV (Excel), and import a JSON backup.
class BackupService {
  const BackupService(this._storage);
  final TransactionStorage _storage;

  static const appName = 'expense_tracker';
  static const formatVersion = 1;

  Future<BackupSnapshot> readCurrent() async => BackupSnapshot(
    accounts: await _storage.loadAccounts(),
    transactions: await _storage.load(),
    upcoming: await _storage.loadUpcoming(),
    budgets: await _storage.loadBudgets(),
    exportedAt: DateTime.now(),
  );

  // ---------- Export ----------

  Future<bool> exportJson() async {
    final s = await readCurrent();
    final stamp = _stamp(s.exportedAt);
    return _save('expenses-backup-$stamp.json', _toJson(s));
  }

  Future<bool> exportCsv() async {
    final s = await readCurrent();
    final stamp = _stamp(s.exportedAt);
    return _save('expenses-$stamp.csv', _toCsv(s));
  }

  Future<bool> _save(String fileName, String content) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    final ext = fileName.split('.').last;

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $fileName',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [ext],
      bytes: bytes,
    );

    // On web the browser already downloaded it.
    if (kIsWeb) return true;
    if (path == null) return false; // user cancelled

    try {
      await writeBytesToPath(path, bytes);
      return true;
    } catch (e) {
      debugPrint('Backup: could not write "$path": $e');
      return false;
    }
  }

  String _toJson(BackupSnapshot s) =>
      const JsonEncoder.withIndent('  ').convert({
        'app': appName,
        'formatVersion': formatVersion,
        'exportedAt': s.exportedAt.toIso8601String(),
        'accounts': s.accounts.map((a) => a.toJson()).toList(),
        'transactions': s.transactions.map((t) => t.toJson()).toList(),
        'upcoming': s.upcoming.map((u) => u.toJson()).toList(),
        'budgets': s.budgets,
      });

  String _toCsv(BackupSnapshot s) {
    String nameOf(String id) {
      for (final a in s.accounts) {
        if (a.id == id) return a.name;
      }
      return '';
    }

    final buf = StringBuffer()
      ..writeln(
        'Date,Type,Title,Category,Custom label,Amount,Account,To account',
      );

    for (final t in s.transactions) {
      buf.writeln(
        [
          _date(t.date),
          t.type.name,
          t.title,
          t.category.label,
          t.customLabel ?? '',
          (t.amountPaise / 100).toStringAsFixed(2),
          nameOf(t.accountId),
          t.toAccountId == null ? '' : nameOf(t.toAccountId!),
        ].map(_csvField).join(','),
      );
    }
    return buf.toString();
  }

  /// Wraps a value in quotes only when CSV requires it.
  static String _csvField(String v) {
    final escaped = v.replaceAll('"', '""');
    final needsQuotes =
        v.contains(',') ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _stamp(DateTime d) =>
      '${_date(d)}-${d.hour.toString().padLeft(2, '0')}'
      '${d.minute.toString().padLeft(2, '0')}';

  // ---------- Import ----------

  /// Opens a file picker. Returns null if cancelled or the file is invalid.
  Future<BackupSnapshot?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a backup file',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final bytes = result.files.first.bytes;
    if (bytes == null) return null;

    try {
      return parseBackup(utf8.decode(bytes));
    } catch (e) {
      debugPrint('Backup: could not read file: $e');
      return null;
    }
  }

  /// Parses and validates a backup. Returns null if it is not ours.
  BackupSnapshot? parseBackup(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      if (decoded['app'] != appName) return null;
      if (decoded['accounts'] is! List || decoded['transactions'] is! List) {
        return null;
      }

      final accounts = <Account>[];
      for (final e in decoded['accounts'] as List) {
        if (e is! Map) continue;
        try {
          accounts.add(Account.fromJson(Map<String, dynamic>.from(e)));
        } catch (err) {
          debugPrint('Backup: skipped one account: $err');
        }
      }

      final transactions = <Transaction>[];
      for (final e in decoded['transactions'] as List) {
        if (e is! Map) continue;
        try {
          transactions.add(Transaction.fromJson(Map<String, dynamic>.from(e)));
        } catch (err) {
          debugPrint('Backup: skipped one transaction: $err');
        }
      }

      final upcoming = <Upcoming>[];
      for (final e in (decoded['upcoming'] as List? ?? [])) {
        if (e is! Map) continue;
        try {
          upcoming.add(Upcoming.fromJson(Map<String, dynamic>.from(e)));
        } catch (err) {
          debugPrint('Backup: skipped one upcoming payment: $err');
        }
      }

      final budgets = <String, int>{};
      final b = decoded['budgets'];
      if (b is Map) {
        b.forEach((k, v) {
          budgets[k.toString()] = v is num ? v.round() : 0;
        });
      }

      return BackupSnapshot(
        accounts: accounts,
        transactions: transactions,
        upcoming: upcoming,
        budgets: budgets,
        exportedAt:
            DateTime.tryParse('${decoded['exportedAt']}') ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('Backup: parse failed: $e');
      return null;
    }
  }
}
