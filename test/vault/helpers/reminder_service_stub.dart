// test/vault/helpers/reminder_service_stub.dart
// Owner: Developer 3 — D3.6 test utilities
//
// Test-only stub for ReminderService.
// Records calls to schedule() and cancelForDocument() without touching
// the real flutter_local_notifications plugin.

import 'package:lifevault/core/contracts/contracts.dart';

class ReminderServiceStub implements ReminderService {
  final List<DeadlineRecord> scheduledDeadlines = [];
  final List<String> cancelledDocumentIds = [];

  /// Controls what schedule() returns. Defaults to a successful schedule.
  bool nextScheduled;
  bool nextPermissionGranted;
  List<int> nextNotificationIds;
  String? nextStatusMessage;

  ReminderServiceStub({
    this.nextScheduled = true,
    this.nextPermissionGranted = true,
    List<int>? nextNotificationIds,
    this.nextStatusMessage,
  }) : nextNotificationIds = nextNotificationIds ?? [1001, 1002];

  @override
  Future<ReminderScheduleResult> schedule(DeadlineRecord deadline) async {
    scheduledDeadlines.add(deadline);
    return ReminderScheduleResult(
      scheduled: nextScheduled,
      permissionGranted: nextPermissionGranted,
      notificationIds: nextScheduled ? nextNotificationIds : const [],
      statusMessage: nextStatusMessage,
    );
  }

  @override
  Future<void> cancelForDocument(String documentId) async {
    cancelledDocumentIds.add(documentId);
  }

  void reset() {
    scheduledDeadlines.clear();
    cancelledDocumentIds.clear();
    nextScheduled = true;
    nextPermissionGranted = true;
    nextNotificationIds = [1001, 1002];
    nextStatusMessage = null;
  }

  /// Simulate permission denied for next schedule call.
  void simulatePermissionDenied() {
    nextScheduled = false;
    nextPermissionGranted = false;
    nextNotificationIds = [];
    nextStatusMessage = 'Notification permission denied.';
  }

  /// Simulate all offsets already in the past.
  void simulateAllPast() {
    nextScheduled = false;
    nextPermissionGranted = true;
    nextNotificationIds = [];
    nextStatusMessage =
        'All reminder offsets are in the past; no notifications scheduled.';
  }

  bool wasScheduledFor(String deadlineId) =>
      scheduledDeadlines.any((d) => d.id == deadlineId);

  bool wasCancelledFor(String documentId) =>
      cancelledDocumentIds.contains(documentId);
}
