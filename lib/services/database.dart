import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Owns the SQLite connection and the schema.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const fileName = 'expenses.db';
  static const schemaVersion = 1;

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    _opening ??= _open();
    _db = await _opening;
    return _db!;
  }

  Future<Database> _open() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    final path = kIsWeb ? fileName : p.join(await getDatabasesPath(), fileName);

    return openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, version) async {
        final b = db.batch();
        b.execute('''
          CREATE TABLE accounts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            starting_paise INTEGER NOT NULL,
            style_key TEXT NOT NULL
          )
        ''');
        b.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            amount_paise INTEGER NOT NULL,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            date_ms INTEGER NOT NULL,
            account_id TEXT NOT NULL,
            to_account_id TEXT,
            custom_label TEXT
          )
        ''');
        b.execute('CREATE INDEX idx_tx_date ON transactions(date_ms DESC)');
        b.execute('CREATE INDEX idx_tx_account ON transactions(account_id)');
        b.execute('''
          CREATE TABLE upcoming (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            amount_paise INTEGER NOT NULL,
            due_ms INTEGER NOT NULL,
            account_id TEXT NOT NULL,
            category TEXT NOT NULL
          )
        ''');
        b.execute('CREATE INDEX idx_upcoming_due ON upcoming(due_ms)');
        b.execute('''
          CREATE TABLE budgets (
            label TEXT PRIMARY KEY,
            amount_paise INTEGER NOT NULL
          )
        ''');
        await b.commit(noResult: true);
      },
      onUpgrade: (db, from, to) async {
        // Future migrations go here, one block per version:
        // if (from < 2) await db.execute('ALTER TABLE ...');
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _opening = null;
  }
}
