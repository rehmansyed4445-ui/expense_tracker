import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/upcoming.dart';
import 'backup_service.dart';

/// One document per user holding the whole app state.
/// Same shape as a JSON backup, so both features share the model.
class CloudService {
  CloudService(this._uid);
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('data')
      .doc('snapshot');

  Future<void> push(BackupSnapshot s) => _doc.set({
    'formatVersion': BackupService.formatVersion,
    'exportedAt': s.exportedAt.toIso8601String(),
    'accounts': s.accounts.map((a) => a.toJson()).toList(),
    'transactions': s.transactions.map((t) => t.toJson()).toList(),
    'upcoming': s.upcoming.map((u) => u.toJson()).toList(),
    'budgets': s.budgets,
  });

  Future<BackupSnapshot?> pull() async {
    final snap = await _doc.get();
    if (!snap.exists) return null;
    final d = snap.data();
    if (d == null) return null;
    try {
      return BackupSnapshot(
        accounts: [
          for (final e in (d['accounts'] as List? ?? []))
            Account.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        transactions: [
          for (final e in (d['transactions'] as List? ?? []))
            Transaction.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        upcoming: [
          for (final e in (d['upcoming'] as List? ?? []))
            Upcoming.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        budgets: (d['budgets'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).round()),
        ),
        exportedAt: DateTime.tryParse('${d['exportedAt']}') ?? DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }
}
