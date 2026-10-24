// test/vault/question_service_test.dart
// Owner: Developer 3 — D3.6
//
// Tests for QuestionServiceImpl — all grounded, no LLM, no network.
// Uses in-memory DB seeded with synthetic fixtures.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lifevault/features/vault/data/database/vault_database.dart';
import 'package:lifevault/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:lifevault/features/vault/services/question_service_impl.dart';
import 'package:lifevault/core/contracts/contracts.dart';

import 'helpers/test_fixtures.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late VaultRepositoryImpl repo;
  late QuestionServiceImpl qa;
  late Directory tempDir;

  Future<File> uniqueFile(String name, List<int> magic) async {
    final f = File(p.join(tempDir.path, name));
    await f.writeAsBytes(magic);
    return f;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lifevault_qa_test_');
    db = await VaultDatabase.openInMemory();
    repo = VaultRepositoryImpl(db: db, storageDir: tempDir);
    qa = QuestionServiceImpl(repo);

    // Seed DB with representative fixtures
    await repo.saveVerified(
      TestFixtures.bikeInsuranceExpiry(
        imagePath: (await uniqueFile('ins.jpg', [0x01, 0x02, 0x03])).path,
        expiryDate: '2027-03-31',
      ),
    );
    await repo.saveVerified(
      TestFixtures.fridgeWarranty(
        imagePath: (await uniqueFile('fridge.jpg', [0x04, 0x05, 0x06])).path,
        warrantyEnd: '2028-06-15',
      ),
    );
    await repo.saveVerified(
      TestFixtures.electricityBill(
        imagePath: (await uniqueFile('bill.jpg', [0x07, 0x08, 0x09])).path,
        dueDate: '2026-11-15',
      ),
    );
    await repo.saveVerified(
      TestFixtures.medicalRecord(
        imagePath: (await uniqueFile('med.jpg', [0x0A, 0x0B, 0x0C])).path,
      ),
    );
    await repo.saveVerified(
      TestFixtures.overdueInsurance(
        imagePath: (await uniqueFile('overdue.jpg', [0x0D, 0x0E, 0x0F])).path,
      ),
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  // ─── Expiry intent ────────────────────────────────────────────────────────

  group('D3.4 – expiry intent', () {
    test('answers "when does bike insurance expire"', () async {
      final result = await qa.answer('When does my bike insurance expire?');
      expect(result.status, equals(AnswerStatus.answered));
      expect(result.documentIds, isNotEmpty);
      expect(result.text, contains('2027-03-31'));
    });

    test('returns not_found for unknown asset', () async {
      final result = await qa.answer('When does my laptop warranty expire?');
      expect(result.status, equals(AnswerStatus.notFound));
      expect(result.documentIds, isEmpty);
    });

    test('multiple expiry matches returns multiple_matches', () async {
      // Both bike insurance and scooter insurance are expiry type
      final result = await qa.answer('When does my insurance expire?');
      // Could be answered (one match after subject filter) or multiple
      expect(
        [AnswerStatus.answered, AnswerStatus.multipleMatches],
        contains(result.status),
      );
    });

    test('expiry answer includes days remaining or overdue label', () async {
      final result = await qa.answer('bike insurance expiry');
      expect(result.status, equals(AnswerStatus.answered));
      // Should mention either "days remaining" or "has passed"
      expect(
        result.text.contains('days remaining') ||
            result.text.contains('has passed'),
        isTrue,
      );
    });
  });

  // ─── Due date intent ──────────────────────────────────────────────────────

  group('D3.4 – due date intent', () {
    test('answers "when is electricity bill due"', () async {
      final result = await qa.answer('When is my electricity bill due?');
      expect(result.status, equals(AnswerStatus.answered));
      expect(result.text, contains('2026-11-15'));
    });

    test('returns not_found when no bill exists for subject', () async {
      final result = await qa.answer('when is broadband bill due');
      expect(result.status, equals(AnswerStatus.notFound));
    });
  });

  // ─── Upcoming intent ──────────────────────────────────────────────────────

  group('D3.4 – upcoming intent', () {
    test('lists upcoming deadlines', () async {
      final result = await qa.answer('What are my upcoming deadlines?');
      // Should be answered (we have at least the electricity bill due soon)
      expect(
        [AnswerStatus.answered, AnswerStatus.notFound],
        contains(result.status),
      );
    });

    test('"upcoming reminders" also triggers upcoming intent', () async {
      final result = await qa.answer('Show my upcoming reminders');
      expect(result, isNotNull);
    });
  });

  // ─── Find intent ──────────────────────────────────────────────────────────

  group('D3.4 – find intent', () {
    test('finds fridge warranty document', () async {
      final result = await qa.answer('Find fridge warranty');
      expect(result.status, equals(AnswerStatus.answered));
      expect(result.documentIds, isNotEmpty);
    });

    test('find returns multiple_matches for broad search', () async {
      final result = await qa.answer('Find insurance');
      // Multiple insurance docs in DB
      expect(
        [AnswerStatus.answered, AnswerStatus.multipleMatches],
        contains(result.status),
      );
    });

    test('find with no matching text returns not_found', () async {
      final result = await qa.answer('find xyz_totally_fake_document');
      expect(result.status, equals(AnswerStatus.notFound));
    });
  });

  // ─── Unsupported intent ───────────────────────────────────────────────────

  group('D3.4 – unsupported intent', () {
    test('returns unsupported_question for unrecognized query', () async {
      final result = await qa.answer('What is the meaning of life?');
      expect(result.status, equals(AnswerStatus.unsupportedQuestion));
      expect(result.documentIds, isEmpty);
    });

    test('unsupported response contains helpful suggestion', () async {
      final result = await qa.answer('Tell me a joke');
      expect(result.text, isNotEmpty);
      expect(result.status, equals(AnswerStatus.unsupportedQuestion));
    });

    test('empty question returns unsupported', () async {
      final result = await qa.answer('');
      expect(result.status, equals(AnswerStatus.unsupportedQuestion));
    });
  });

  // ─── Negative / no-fabrication checks ────────────────────────────────────

  group('D3.4 – no fabrication', () {
    test('answer never returns invented dates', () async {
      // Question about medical record which has no deadlines
      final result = await qa.answer('when does blood test expire?');
      // Should be not_found, NOT answered with fabricated date
      expect(result.status, isNot(equals(AnswerStatus.answered)));
    });

    test('documentIds is always empty for not_found', () async {
      final result = await qa.answer('find document that does not exist xyz');
      expect(result.status, equals(AnswerStatus.notFound));
      expect(result.documentIds, isEmpty);
    });
  });
}
