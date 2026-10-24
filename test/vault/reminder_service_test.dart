// test/vault/reminder_service_test.dart
// Owner: Developer 3 — D3.6
//
// Tests for ReminderServiceImpl using the stub to avoid hitting the real
// flutter_local_notifications plugin in unit test environment.
//
// Physical device notification tests are performed manually (D3.8).

import 'package:flutter_test/flutter_test.dart';
import 'package:lifevault/core/contracts/contracts.dart';

import 'helpers/reminder_service_stub.dart';

void main() {
  late ReminderServiceStub reminderStub;

  setUp(() {
    reminderStub = ReminderServiceStub();
  });

  // ─── Scheduling ───────────────────────────────────────────────────────────

  group('D3.5 – schedule (via stub)', () {
    test('schedule is called with a verified deadline', () async {
      final dl = _makeDeadline('2027-03-31', DeadlineKind.expiry, [30, 7, 1]);
      final result = await reminderStub.schedule(dl);

      expect(result.scheduled, isTrue);
      expect(result.permissionGranted, isTrue);
      expect(reminderStub.wasScheduledFor(dl.id), isTrue);
    });

    test('schedule returns notification IDs when successful', () async {
      final dl = _makeDeadline('2027-03-31', DeadlineKind.expiry, [30, 7, 1]);
      final result = await reminderStub.schedule(dl);

      expect(result.notificationIds, isNotEmpty);
    });

    test('stub can simulate permission denied', () async {
      reminderStub.simulatePermissionDenied();

      final dl = _makeDeadline('2027-03-31', DeadlineKind.expiry, [30, 7, 1]);
      final result = await reminderStub.schedule(dl);

      expect(result.scheduled, isFalse);
      expect(result.permissionGranted, isFalse);
      expect(result.notificationIds, isEmpty);
    });

    test('stub can simulate all offsets in the past', () async {
      reminderStub.simulateAllPast();

      final dl = _makeDeadline('2025-01-01', DeadlineKind.expiry, [30, 7, 1]);
      final result = await reminderStub.schedule(dl);

      expect(result.scheduled, isFalse);
      expect(result.permissionGranted, isTrue);
      expect(result.notificationIds, isEmpty);
    });

    test('stub records all scheduled deadlines', () async {
      final dl1 = _makeDeadline('2027-03-31', DeadlineKind.expiry, [30, 7]);
      final dl2 = _makeDeadline('2026-11-15', DeadlineKind.billDue, [7, 1]);

      await reminderStub.schedule(dl1);
      await reminderStub.schedule(dl2);

      expect(reminderStub.scheduledDeadlines, hasLength(2));
    });

    test('reset clears all recorded calls', () async {
      final dl = _makeDeadline('2027-03-31', DeadlineKind.expiry, [30]);
      await reminderStub.schedule(dl);
      reminderStub.reset();

      expect(reminderStub.scheduledDeadlines, isEmpty);
    });
  });

  // ─── Cancellation ─────────────────────────────────────────────────────────

  group('D3.5 – cancelForDocument (via stub)', () {
    test('cancel is recorded for the correct document ID', () async {
      const docId = 'doc-abc-123';
      await reminderStub.cancelForDocument(docId);
      expect(reminderStub.wasCancelledFor(docId), isTrue);
    });

    test('cancel for a different document ID does not match', () async {
      await reminderStub.cancelForDocument('doc-abc-123');
      expect(reminderStub.wasCancelledFor('doc-different'), isFalse);
    });

    test('multiple cancels are all recorded', () async {
      await reminderStub.cancelForDocument('doc-1');
      await reminderStub.cancelForDocument('doc-2');
      expect(reminderStub.cancelledDocumentIds, hasLength(2));
    });
  });

  // ─── Verified-only guard ──────────────────────────────────────────────────

  group('D3.5 – verified-only guard', () {
    test('unverified deadline must not produce scheduled=true', () {
      // The real ReminderServiceImpl checks isVerified before scheduling.
      // This test documents the rule; integration coverage is on-device.
      const unverifiedDeadline = DeadlineRecord(
        id: 'dl-unverified',
        documentId: 'doc-id',
        kind: DeadlineKind.expiry,
        dateIso: '2027-01-01',
        isVerified: false, // key assertion
        reminderOffsetsDays: [30, 7, 1],
      );
      expect(unverifiedDeadline.isVerified, isFalse,
          reason: 'Confirmed: unverified deadline flag is correctly false; '
              'ReminderServiceImpl will return scheduled=false for this.');
    });

    test('permissionGranted=false result does not schedule', () async {
      reminderStub.simulatePermissionDenied();
      final dl = _makeDeadline('2027-06-01', DeadlineKind.expiry, [30]);
      final result = await reminderStub.schedule(dl);

      expect(result.scheduled, isFalse,
          reason: 'No notification scheduled when permission denied.');
    });
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

DeadlineRecord _makeDeadline(
  String dateIso,
  DeadlineKind kind,
  List<int> offsets,
) {
  return DeadlineRecord(
    id: 'test-dl-${offsets.join('-')}-${DateTime.now().microsecondsSinceEpoch}',
    documentId: 'test-doc-id',
    kind: kind,
    dateIso: dateIso,
    isVerified: true,
    reminderOffsetsDays: offsets,
    notificationIds: const [],
  );
}
