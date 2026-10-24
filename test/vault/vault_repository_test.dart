// test/vault/vault_repository_test.dart
// Owner: Developer 3 — D3.6
//
// Unit tests for VaultRepositoryImpl.
// Uses an in-memory SQLite database and a temp directory — no real device files.
// All fixtures use synthetic data; no personal or household content.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lifevault/features/vault/data/database/vault_database.dart';
import 'package:lifevault/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:lifevault/features/vault/data/models/vault_exceptions.dart';
import 'package:lifevault/core/contracts/contracts.dart';

import 'helpers/test_fixtures.dart';
import 'helpers/test_clock.dart';

void main() {
  // Initialize sqflite_ffi for desktop/unit test environments.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late VaultRepositoryImpl repo;
  late Directory tempDir;
  late File fakeImageA;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lifevault_test_');
    // Create unique fake image files (different bytes = different SHA-256)
    fakeImageA = File(p.join(tempDir.path, 'doc_a.jpg'));
    await fakeImageA.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x01]);

    db = await VaultDatabase.openInMemory();
    repo = VaultRepositoryImpl(db: db, storageDir: tempDir);
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  // Helper: write a fresh unique file so each test gets its own SHA-256
  Future<File> uniqueFile(String name) async {
    final f = File(p.join(tempDir.path, name));
    // Use timestamp as content to guarantee uniqueness across tests
    await f.writeAsBytes(
      name.codeUnits + [DateTime.now().microsecondsSinceEpoch & 0xFF],
    );
    return f;
  }

  // ─── D3.1: Schema / DB init ────────────────────────────────────────────────

  group('D3.1 – Database initialization', () {
    test('repository initializes without error', () async {
      final docs = await repo.search();
      expect(docs, isEmpty);
    });

    test('deadlines table is empty on fresh DB', () async {
      final deadlines = await repo.getDeadlines();
      expect(deadlines, isEmpty);
    });
  });

  // ─── D3.2: Save / SHA-256 / duplicate detection ───────────────────────────

  group('D3.2 – saveVerified', () {
    test('saves a document and returns a DocumentRecord', () async {
      final record = await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(imagePath: fakeImageA.path),
      );

      expect(record.id, isNotEmpty);
      expect(record.title, equals('Bike Insurance Policy'));
      expect(record.category, equals(DocumentCategory.insurance));
      expect(record.sha256, isNotEmpty);
      expect(record.verificationStatus, equals(VerificationStatus.verified));
    });

    test('copies image to private storage', () async {
      final record = await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(imagePath: fakeImageA.path),
      );

      final savedFile = File(record.originalPath);
      expect(savedFile.existsSync(), isTrue);
      expect(record.originalPath, startsWith(tempDir.path));
    });

    test('saves associated deadline record', () async {
      final record = await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(
          imagePath: fakeImageA.path,
          expiryDate: '2027-03-31',
        ),
      );

      final deadlines = await repo.getDeadlinesForDocument(record.id);
      expect(deadlines, hasLength(1));
      expect(deadlines.first.dateIso, equals('2027-03-31'));
      expect(deadlines.first.kind, equals(DeadlineKind.expiry));
      expect(deadlines.first.isVerified, isTrue);
    });

    test('saves document with no deadlines (medical record)', () async {
      final record = await repo.saveVerified(
        TestFixtures.medicalRecord(imagePath: fakeImageA.path),
      );

      final deadlines = await repo.getDeadlinesForDocument(record.id);
      expect(deadlines, isEmpty);
      expect(record.title, equals('Blood Test Report'));
    });

    test('duplicate SHA-256 throws DuplicateDocumentException', () async {
      await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(imagePath: fakeImageA.path),
      );

      // Same physical file → same SHA-256
      expect(
        () => repo.saveVerified(
          TestFixtures.medicalRecord(imagePath: fakeImageA.path),
        ),
        throwsA(isA<DuplicateDocumentException>()),
      );
    });

    test('duplicate exception contains the existing document ID', () async {
      final original = await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(imagePath: fakeImageA.path),
      );

      try {
        await repo.saveVerified(
          TestFixtures.medicalRecord(imagePath: fakeImageA.path),
        );
        fail('Should have thrown DuplicateDocumentException');
      } on DuplicateDocumentException catch (e) {
        expect(e.existingId, equals(original.id));
      }
    });

    test('throws FileNotFoundException when source path is missing', () async {
      expect(
        () => repo.saveVerified(
          TestFixtures.bikeInsuranceExpiry(
            imagePath: '/nonexistent/path/fake.jpg',
          ),
        ),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    test('two different files save successfully (no false duplicate)',
        () async {
      final fileB = await uniqueFile('doc_b.jpg');
      final fileC = await uniqueFile('doc_c.jpg');

      final r1 = await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(imagePath: fileB.path),
      );
      final r2 = await repo.saveVerified(
        TestFixtures.fridgeWarranty(imagePath: fileC.path),
      );

      expect(r1.id, isNot(equals(r2.id)));
      expect(r1.sha256, isNot(equals(r2.sha256)));
    });
  });

  // ─── D3.2: Search ─────────────────────────────────────────────────────────

  group('D3.2 – search', () {
    setUp(() async {
      // Seed with 3 different document types
      final f1 = await uniqueFile('s1.jpg');
      final f2 = await uniqueFile('s2.jpg');
      final f3 = await uniqueFile('s3.jpg');

      await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(imagePath: f1.path),
      );
      await repo.saveVerified(
        TestFixtures.electricityBill(imagePath: f2.path),
      );
      await repo.saveVerified(
        TestFixtures.medicalRecord(imagePath: f3.path),
      );
    });

    test('search() with no filters returns all documents', () async {
      final results = await repo.search();
      expect(results, hasLength(3));
    });

    test('search by category returns only matching documents', () async {
      final results = await repo.search(category: DocumentCategory.insurance);
      expect(results, hasLength(1));
      expect(results.first.title, equals('Bike Insurance Policy'));
    });

    test('search by title text is case-insensitive', () async {
      final results = await repo.search(text: 'ELECTRICITY');
      expect(results, hasLength(1));
      expect(results.first.category, equals(DocumentCategory.homeUtilities));
    });

    test('search by asset name works', () async {
      final results = await repo.search(text: 'bike');
      expect(results.any((d) => d.assetName == 'Bike'), isTrue);
    });

    test('search with no match returns empty list', () async {
      final results = await repo.search(text: 'nonexistent_xyz_123');
      expect(results, isEmpty);
    });

    test('combined category + text filter narrows results', () async {
      final results = await repo.search(
        category: DocumentCategory.medical,
        text: 'blood',
      );
      expect(results, hasLength(1));
      expect(results.first.documentType, equals(DocumentType.medicalRecord));
    });
  });

  // ─── D3.3: Upcoming / overdue ─────────────────────────────────────────────

  group('D3.3 – deadline queries', () {
    test('getUpcomingDeadlines returns deadlines within 30 days', () async {
      final f1 = await uniqueFile('u1.jpg');
      final f2 = await uniqueFile('u2.jpg');

      final clock = FixedClock.fromIso('2026-11-01');
      // Due in 14 days → in window
      await repo.saveVerified(
        TestFixtures.electricityBill(imagePath: f1.path, dueDate: '2026-11-15'),
      );
      // Due in 60 days → outside window
      await repo.saveVerified(
        TestFixtures.fridgeWarranty(
            imagePath: f2.path, warrantyEnd: '2027-01-01'),
      );

      final upcoming = await repo.getUpcomingDeadlines(
        withinDays: 30,
        now: clock.now,
      );
      expect(upcoming, hasLength(1));
      expect(upcoming.first.dateIso, equals('2026-11-15'));
    });

    test('getOverdueDeadlines returns only past deadlines', () async {
      final f1 = await uniqueFile('o1.jpg');
      final f2 = await uniqueFile('o2.jpg');

      final clock = FixedClock.fromIso('2026-10-24');
      await repo.saveVerified(
        TestFixtures.overdueInsurance(imagePath: f1.path),
      );
      await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(
          imagePath: f2.path,
          expiryDate: '2027-03-31',
        ),
      );

      final overdue = await repo.getOverdueDeadlines(now: clock.now);
      expect(overdue, hasLength(1));
      expect(overdue.first.dateIso, equals('2025-01-01'));
    });

    test('getUnverified returns empty when all docs are verified', () async {
      final f1 = await uniqueFile('v1.jpg');
      await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(imagePath: f1.path),
      );

      final unverified = await repo.getUnverified();
      expect(unverified, isEmpty);
    });
  });

  // ─── D3.3: Delete ─────────────────────────────────────────────────────────

  group('D3.3 – deleteDocument', () {
    test('deletes document record from DB', () async {
      final record = await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(imagePath: fakeImageA.path),
      );
      await repo.deleteDocument(record.id);

      final found = await repo.findById(record.id);
      expect(found, isNull);
    });

    test('deletes the copied private file', () async {
      final record = await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(imagePath: fakeImageA.path),
      );
      final privatePath = record.originalPath;

      await repo.deleteDocument(record.id);
      expect(File(privatePath).existsSync(), isFalse);
    });

    test('cascades delete to associated deadlines', () async {
      final record = await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(imagePath: fakeImageA.path),
      );
      await repo.deleteDocument(record.id);

      final deadlines = await repo.getDeadlinesForDocument(record.id);
      expect(deadlines, isEmpty);
    });

    test('deleteDocument is idempotent — safe to call on nonexistent ID',
        () async {
      await expectLater(
        repo.deleteDocument('nonexistent-id-xyz'),
        completes,
      );
    });
  });

  // ─── D3.3: Update deadline ─────────────────────────────────────────────────

  group('D3.3 – updateDeadline', () {
    test('updates deadline date and filters elapsed past offsets', () async {
      final record = await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(imagePath: fakeImageA.path),
      );
      final deadlines = await repo.getDeadlinesForDocument(record.id);
      final original = deadlines.first;

      // Move to far future — all offsets should survive
      final updated = await repo.updateDeadline(
        original.copyWith(dateIso: '2030-12-31'),
        now: FixedClock.fromIso('2026-10-24').now,
      );

      expect(updated.dateIso, equals('2030-12-31'));
      expect(updated.reminderOffsetsDays, isNotEmpty);
    });

    test('updateDeadline drops offsets already in the past', () async {
      final record = await repo.saveVerified(
        TestFixtures.bikeInsuranceExpiry(imagePath: fakeImageA.path),
      );
      final deadlines = await repo.getDeadlinesForDocument(record.id);
      final original = deadlines.first;

      // Set due date 5 days from now — offsets of 30 and 7 days are past,
      // offset of 1 day should survive if 5 > 1.
      final clock = FixedClock.fromIso('2026-10-24');
      const nearDue = '2026-10-29'; // 5 days from clock date
      final updated = await repo.updateDeadline(
        original.copyWith(
          dateIso: nearDue,
          reminderOffsetsDays: [30, 7, 1],
        ),
        now: clock.now,
      );

      // Only offsets where dueDate - offset > today should remain
      for (final offset in updated.reminderOffsetsDays) {
        final triggerDate =
            DateTime.parse(nearDue).subtract(Duration(days: offset));
        expect(
          triggerDate.isAfter(clock.now),
          isTrue,
          reason: 'Offset $offset is in the past but was not filtered out.',
        );
      }
    });
  });
}
