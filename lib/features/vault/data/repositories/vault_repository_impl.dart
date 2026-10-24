// lib/features/vault/data/repositories/vault_repository_impl.dart
// Owner: Developer 3 — Tasks D3.1, D3.2, D3.3
//
// Implements the frozen VaultRepository interface (lib/core/contracts/services.dart).
// Responsibilities:
//   - Copy verified image to app-private storage (atomic with DB write)
//   - SHA-256 duplicate detection
//   - Save/search/list/delete DocumentRecord and DeadlineRecord
//   - Rollback file copy if DB transaction fails; never leave orphans
//   - Deadline queries: upcoming, overdue, unverified
//
// NO dependency on D1 (OCR) or D2 (classification).
// Accepts VerifiedDocumentInput at public boundary per frozen contract.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:lifevault/core/contracts/contracts.dart';
import '../database/vault_database.dart';
import '../models/vault_exceptions.dart';

class VaultRepositoryImpl implements VaultRepository {
  final Database _db;
  final Directory _storageDir;
  final Uuid _uuid;

  /// Prefer [VaultRepositoryImpl.create()] for production.
  /// For tests, inject a [VaultDatabase.openInMemory()] and a temp dir.
  VaultRepositoryImpl({
    required Database db,
    required Directory storageDir,
    Uuid? uuid,
  })  : _db = db,
        _storageDir = storageDir,
        _uuid = uuid ?? const Uuid();

  /// Production factory — resolves real paths and DB singleton.
  static Future<VaultRepositoryImpl> create() async {
    final db = await VaultDatabase.instance;
    final appDir = await getApplicationDocumentsDirectory();
    final storageDir = Directory(p.join(appDir.path, 'vault_documents'));
    if (!storageDir.existsSync()) {
      await storageDir.create(recursive: true);
    }
    return VaultRepositoryImpl(db: db, storageDir: storageDir);
  }

  // ─── VaultRepository interface ───────────────────────────────────────────────

  /// D3.2 — Save verified document.
  ///
  /// Order of operations (fail-safe):
  ///   1. Validate source file exists.
  ///   2. Compute SHA-256 (or use pre-computed from input); reject duplicate.
  ///   3. Copy file to private storage.
  ///   4. DB transaction (documents + evidence + deadlines).
  ///   5. On DB failure → delete copied file and rethrow.
  @override
  Future<DocumentRecord> saveVerified(VerifiedDocumentInput input) async {
    // 1. Validate source — use the alias .originalPath which maps to .originalTempPath
    final sourceFile = File(input.originalPath);
    if (!sourceFile.existsSync()) {
      throw FileNotFoundException(input.originalPath);
    }

    // 2. SHA-256 — use pre-computed if supplied, otherwise compute
    final String hash;
    if (input.sha256 != null && input.sha256!.isNotEmpty) {
      hash = input.sha256!;
    } else {
      final bytes = await sourceFile.readAsBytes();
      hash = sha256.convert(bytes).toString();
    }
    await _assertNoDuplicate(hash);

    final docId = _uuid.v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 3. Copy to private storage BEFORE DB write
    final ext = _safeExtension(input.originalPath);
    final privateFile = File(p.join(_storageDir.path, '$docId$ext'));
    try {
      await sourceFile.copy(privateFile.path);
    } catch (e) {
      throw VaultException('Failed to copy image to private storage', cause: e);
    }

    // 4. Atomic DB transaction
    try {
      await _db.transaction((txn) async {
        // documents row — store wireName for category/type/status
        await txn.insert('documents', {
          'id': docId,
          'title': input.title,
          'category': input.category.wireName,
          'document_type': input.documentType.wireName,
          'asset_name': input.assetName,
          'original_path': privateFile.path,
          'sha256': hash,
          'ocr_status': input.ocrStatus.wireName,
          'verification_status': input.verificationStatus.wireName,
          'created_at': nowIso,
          'updated_at': nowIso,
        });

        // evidence rows — from the EvidenceRecord list in input
        for (final ev in input.evidenceRecords) {
          final map = ev.toSqlMap();
          // Ensure foreign key is set to this document
          await txn.insert('evidence', {
            ...map,
            'id': map['id'] ?? _uuid.v4(),
            'document_id': docId,
          });
        }

        // deadline rows — only verified deadline inputs
        for (final dl in input.verifiedDeadlines) {
          await txn.insert('deadlines', {
            'id': _uuid.v4(),
            'document_id': docId,
            'kind': dl.kind.wireName,
            'due_date_iso': dl.dateIso,
            'evidence_id': null, // linked after evidence insert if needed
            'verified': 1,
            'reminder_offsets_json': _encodeIntList(dl.reminderOffsetsDays),
            'notification_ids_json': '[]',
            'updated_at': nowIso,
          });
        }
      });
    } catch (e) {
      // 5. Rollback: remove the copied file
      _silentDelete(privateFile);
      throw VaultTransactionException('DB write failed; image copy removed.',
          cause: e);
    }

    return _requireDocumentById(docId);
  }

  /// D3.2 — Search by free text and/or category.
  @override
  Future<List<DocumentRecord>> search({
    String? text,
    DocumentCategory? category,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (category != null) {
      conditions.add('category = ?');
      args.add(category.wireName);
    }
    if (text != null && text.trim().isNotEmpty) {
      final like = '%${text.trim().toLowerCase()}%';
      conditions.add(
        '(LOWER(title) LIKE ? OR LOWER(asset_name) LIKE ?)',
      );
      args.addAll([like, like]);
    }

    final rows = await _db.query(
      'documents',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at DESC',
    );
    return rows.map(_rowToDocument).toList();
  }

  /// D3.3 — List deadlines sorted by due date (upcoming first).
  @override
  Future<List<DeadlineRecord>> getDeadlines({
    bool verifiedOnly = true,
  }) async {
    final rows = await _db.query(
      'deadlines',
      where: verifiedOnly ? 'verified = 1' : null,
      orderBy: 'due_date_iso ASC',
    );
    return rows.map(_rowToDeadline).toList();
  }

  /// D3.3 — Delete document + private file.
  ///
  /// Caller must invoke ReminderService.cancelForDocument() BEFORE this
  /// so notifications are cleared. The DB cascade (ON DELETE CASCADE)
  /// removes evidence and deadline rows automatically.
  @override
  Future<void> deleteDocument(String documentId) async {
    final rows = await _db.query(
      'documents',
      columns: ['original_path'],
      where: 'id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (rows.isEmpty) return; // already gone — idempotent

    final path = rows.first['original_path'] as String;

    // DB delete first (cascade cleans evidence + deadlines)
    await _db.delete('documents', where: 'id = ?', whereArgs: [documentId]);

    // Then file
    _silentDelete(File(path));
  }

  // ─── Extended queries (called by QuestionService and UI layer) ───────────────

  Future<DocumentRecord?> findById(String documentId) async {
    final rows = await _db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    return rows.isEmpty ? null : _rowToDocument(rows.first);
  }

  /// D3.3 — Upcoming deadlines within [withinDays] from [now].
  Future<List<DeadlineRecord>> getUpcomingDeadlines({
    int withinDays = 30,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final cutoff = today.add(Duration(days: withinDays));
    final rows = await _db.query(
      'deadlines',
      where: 'verified = 1 AND due_date_iso >= ? AND due_date_iso <= ?',
      whereArgs: [_isoDate(today), _isoDate(cutoff)],
      orderBy: 'due_date_iso ASC',
    );
    return rows.map(_rowToDeadline).toList();
  }

  /// D3.3 — Overdue: verified deadlines whose due date is before today.
  Future<List<DeadlineRecord>> getOverdueDeadlines({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final rows = await _db.query(
      'deadlines',
      where: 'verified = 1 AND due_date_iso < ?',
      whereArgs: [_isoDate(today)],
      orderBy: 'due_date_iso ASC',
    );
    return rows.map(_rowToDeadline).toList();
  }

  /// D3.3 — Documents still in needs_review status.
  Future<List<DocumentRecord>> getUnverified() async {
    final rows = await _db.query(
      'documents',
      where: 'verification_status = ?',
      whereArgs: [VerificationStatus.needsReview.wireName], // 'needs_review'
      orderBy: 'created_at DESC',
    );
    return rows.map(_rowToDocument).toList();
  }

  /// D3.3 — Edit a verified deadline and return the updated record.
  /// Filters out offsets whose trigger time is already in the past.
  Future<DeadlineRecord> updateDeadline(
    DeadlineRecord updated, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final due = DateTime.parse(updated.dateIso);

    final futureOffsets = updated.reminderOffsetsDays
        .where((d) => due.subtract(Duration(days: d)).isAfter(today))
        .toList();

    final nowIso = today.toUtc().toIso8601String();
    await _db.update(
      'deadlines',
      {
        'kind': updated.kind.wireName,
        'due_date_iso': updated.dateIso,
        'reminder_offsets_json': _encodeIntList(futureOffsets),
        'notification_ids_json': _encodeIntList(updated.notificationIds),
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    return updated.copyWith(reminderOffsetsDays: futureOffsets);
  }

  /// D3.5 — Persist notification IDs after scheduling.
  Future<void> saveNotificationIds(
    String deadlineId,
    List<int> notificationIds,
  ) async {
    await _db.update(
      'deadlines',
      {'notification_ids_json': _encodeIntList(notificationIds)},
      where: 'id = ?',
      whereArgs: [deadlineId],
    );
  }

  Future<List<DeadlineRecord>> getDeadlinesForDocument(
    String documentId,
  ) async {
    final rows = await _db.query(
      'deadlines',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'due_date_iso ASC',
    );
    return rows.map(_rowToDeadline).toList();
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  Future<void> _assertNoDuplicate(String hash) async {
    final existing = await _db.query(
      'documents',
      columns: ['id'],
      where: 'sha256 = ?',
      whereArgs: [hash],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw DuplicateDocumentException(
        existingId: existing.first['id'] as String,
        sha256: hash,
      );
    }
  }

  Future<DocumentRecord> _requireDocumentById(String id) async {
    final rows = await _db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw VaultException('Document not found after insert: $id');
    }
    return _rowToDocument(rows.first);
  }

  DocumentRecord _rowToDocument(Map<String, Object?> row) => DocumentRecord(
        id: row['id'] as String,
        title: row['title'] as String,
        category: DocumentCategory.fromWire(row['category'] as String?),
        documentType: DocumentType.fromWire(row['document_type'] as String?),
        assetName: row['asset_name'] as String?,
        originalPath: row['original_path'] as String,
        sha256: row['sha256'] as String,
        ocrStatus: OcrStatus.fromWire(row['ocr_status'] as String?),
        verificationStatus:
            VerificationStatus.fromWire(row['verification_status'] as String?),
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );

  DeadlineRecord _rowToDeadline(Map<String, Object?> row) => DeadlineRecord(
        id: row['id'] as String,
        documentId: row['document_id'] as String,
        kind: DeadlineKind.fromWire(row['kind'] as String?),
        dateIso: row['due_date_iso'] as String,
        evidenceId: row['evidence_id'] as String?,
        isVerified: (row['verified'] as int) == 1,
        reminderOffsetsDays: _decodeIntList(
            row['reminder_offsets_json'] as String? ?? '[30,7,1]'),
        notificationIds:
            _decodeIntList(row['notification_ids_json'] as String? ?? '[]'),
      );

  String _encodeIntList(List<int> list) => jsonEncode(list);

  List<int> _decodeIntList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => (e as num).toInt()).toList();
      }
    } catch (_) {}
    return [];
  }

  String _isoDate(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}'
      '-${dt.month.toString().padLeft(2, '0')}'
      '-${dt.day.toString().padLeft(2, '0')}';

  String _safeExtension(String path) {
    final ext = p.extension(path);
    return ext.isNotEmpty ? ext : '.jpg';
  }

  void _silentDelete(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}
