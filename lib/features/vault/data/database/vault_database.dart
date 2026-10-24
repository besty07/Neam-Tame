// lib/features/vault/data/database/vault_database.dart
// Owner: Developer 3 — SQLite initialization + migration 001
//
// PRAGMA foreign_keys=ON is enforced on every connection.
// Schema is the exact DDL from LifeVault_IMPLEMENTATION_MASTER_PLAN.md §6.
// For in-memory (test) usage, call VaultDatabase.openInMemory().

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class VaultDatabase {
  VaultDatabase._();

  static const String _dbName = 'lifevault.db';
  static const int _schemaVersion = 1;

  static Database? _instance;

  /// Returns the shared singleton database instance (production).
  static Future<Database> get instance async {
    _instance ??= await _openProduction();
    return _instance!;
  }

  /// Opens an **in-memory** database for unit tests.
  /// Each call returns a fresh, independent database — safe for parallel tests.
  static Future<Database> openInMemory({String? path}) async {
    return openDatabase(
      path ?? inMemoryDatabasePath,
      singleInstance: false,
      version: _schemaVersion,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  /// Closes the singleton and resets it. Used in tests or hot-restart scenarios.
  static Future<void> closeAndReset() async {
    await _instance?.close();
    _instance = null;
  }

  // ─── Internal ────────────────────────────────────────────────────────────────

  static Future<Database> _openProduction() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);
    return openDatabase(
      fullPath,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  /// Always enforce foreign keys on every connection open.
  static Future<void> _onOpen(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _migration001(db);
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // Future migrations will be added here as sequential numbered steps.
    // e.g. if (oldVersion < 2) await _migration002(db);
  }

  /// Migration 001 — exact schema from master plan §6 SQLite v1 schema.
  static Future<void> _migration001(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE documents (
        id                  TEXT PRIMARY KEY,
        title               TEXT NOT NULL,
        category            TEXT NOT NULL,
        document_type       TEXT NOT NULL,
        asset_name          TEXT,
        original_path       TEXT NOT NULL,
        sha256              TEXT NOT NULL,
        ocr_status          TEXT NOT NULL,
        verification_status TEXT NOT NULL,
        created_at          TEXT NOT NULL,
        updated_at          TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_documents_category ON documents(category)',
    );
    await db.execute(
      'CREATE INDEX idx_documents_hash ON documents(sha256)',
    );

    await db.execute('''
      CREATE TABLE evidence (
        id              TEXT PRIMARY KEY,
        document_id     TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        field_kind      TEXT NOT NULL,
        proposed_raw    TEXT,
        proposed_iso    TEXT,
        confirmed_iso   TEXT,
        source_snippet  TEXT,
        page_number     INTEGER NOT NULL DEFAULT 1,
        provenance      TEXT NOT NULL,
        is_verified     INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE deadlines (
        id                    TEXT PRIMARY KEY,
        document_id           TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        kind                  TEXT NOT NULL,
        due_date_iso          TEXT NOT NULL,
        evidence_id           TEXT REFERENCES evidence(id),
        verified              INTEGER NOT NULL,
        reminder_offsets_json TEXT NOT NULL DEFAULT '[30,7,1]',
        notification_ids_json TEXT NOT NULL DEFAULT '[]',
        updated_at            TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_deadlines_due ON deadlines(due_date_iso)',
    );
  }
}
