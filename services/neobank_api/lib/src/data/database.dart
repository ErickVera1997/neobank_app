import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Capa de acceso a SQLite: apertura, PRAGMAs y migraciones.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  factory AppDatabase.open(String path) {
    final isMemory = path == ':memory:';
    if (!isMemory) {
      Directory(File(path).parent.path).createSync(recursive: true);
    }
    final db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    final instance = AppDatabase._(db);
    instance._migrate();
    return instance;
  }

  factory AppDatabase.inMemory() => AppDatabase.open(':memory:');

  void _migrate() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        phone TEXT,
        document_id TEXT,
        password_hash TEXT NOT NULL,
        segment TEXT NOT NULL DEFAULT 'standard',
        avatar_url TEXT,
        onboarding_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id),
        token_hash TEXT NOT NULL UNIQUE,
        expires_at TEXT NOT NULL,
        revoked INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS otp_challenges (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id),
        code_hash TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        consumed INTEGER NOT NULL DEFAULT 0,
        attempts INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id),
        type TEXT NOT NULL,
        alias TEXT NOT NULL,
        number_masked TEXT NOT NULL,
        currency TEXT NOT NULL,
        balance_minor INTEGER NOT NULL,
        available_minor INTEGER NOT NULL,
        credit_limit_minor INTEGER,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL REFERENCES accounts(id),
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount_minor INTEGER NOT NULL,
        currency TEXT NOT NULL,
        balance_after_minor INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'posted',
        merchant TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tx_account_created '
      'ON transactions(account_id, created_at DESC);',
    );
    db.execute('''
      CREATE TABLE IF NOT EXISTS device_tokens (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id),
        token TEXT NOT NULL,
        platform TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(user_id, token)
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id),
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        data_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS fx_cache (
        base TEXT PRIMARY KEY,
        rates_json TEXT NOT NULL,
        source TEXT NOT NULL,
        fetched_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS feature_flags (
        key TEXT PRIMARY KEY,
        enabled INTEGER NOT NULL,
        variant TEXT,
        payload_json TEXT NOT NULL DEFAULT '{}',
        segments TEXT NOT NULL DEFAULT '[]'
      );
    ''');
  }

  void close() => db.dispose();
}
