// lib/features/vault/services/reminder_service_impl.dart
// Owner: Developer 3 — Task D3.5
//
// Schedules Android local notifications for verified deadlines.
// Rules:
//   - Only schedules for verified deadlines (isVerified == true).
//   - Uses inexact alarms (AndroidScheduleMode.inexactAllowWhileIdle) to
//     avoid the SCHEDULE_EXACT_ALARM permission requirement.
//   - Notification content is generic; no policy numbers or personal details.
//   - Returns ReminderScheduleResult with scheduled + permissionGranted booleans.
//   - Persists notification IDs back to DB for cancellation/rescheduling.
//   - Skips offsets whose trigger time is already in the past.
//
// D3.7: manifest additions required from Dev 4 are listed in
//       docs/d3_integration_request.md

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:lifevault/core/contracts/contracts.dart';
import '../data/repositories/vault_repository_impl.dart';

class ReminderServiceImpl implements ReminderService {
  final FlutterLocalNotificationsPlugin _plugin;
  final VaultRepositoryImpl _repo;

  bool _initialized = false;
  bool _permissionGranted = false;

  /// [plugin] is injectable so tests can pass a stub (see test/vault/helpers/).
  ReminderServiceImpl({
    FlutterLocalNotificationsPlugin? plugin,
    required VaultRepositoryImpl repo,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _repo = repo;

  // ─── Initialization ──────────────────────────────────────────────────────────

  /// Must be called once during app startup (before scheduling anything).
  /// Returns true if permission was granted (Android 13+); false otherwise.
  Future<bool> initialize() async {
    if (_initialized) return _permissionGranted;

    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings);

    _initialized = true;

    // Request Android 13+ POST_NOTIFICATIONS permission
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      _permissionGranted = granted ?? false;
    } else {
      _permissionGranted = true; // non-Android platforms
    }
    return _permissionGranted;
  }

  // ─── ReminderService interface ───────────────────────────────────────────────

  /// D3.5 — Schedule inexact local notifications for [deadline].
  ///
  /// For each offset in [deadline.reminderOffsetsDays]:
  ///   - Compute trigger time = dueDate - offset days (at 09:00 local time).
  ///   - Skip if trigger is already in the past.
  ///   - Schedule with AndroidScheduleMode.inexactAllowWhileIdle.
  ///
  /// Returns [ReminderScheduleResult.scheduled] = true if at least one
  /// notification was successfully scheduled.
  @override
  Future<ReminderScheduleResult> schedule(DeadlineRecord deadline) async {
    if (!deadline.isVerified) {
      // Never auto-schedule from unverified deadlines — master plan §5, §9
      return const ReminderScheduleResult(
        scheduled: false,
        permissionGranted: false,
        statusMessage: 'Deadline is not verified; no automatic reminders.',
      );
    }

    if (!_initialized) await initialize();

    if (!_permissionGranted) {
      return const ReminderScheduleResult(
        scheduled: false,
        permissionGranted: false,
        statusMessage: 'Notification permission denied. '
            'Deadlines are visible on the dashboard.',
      );
    }

    final due = DateTime.parse(deadline.dateIso);
    final now = DateTime.now();
    final scheduledIds = <int>[];

    for (final offsetDays in deadline.reminderOffsetsDays) {
      // Trigger at 09:00 local time, [offsetDays] before due date
      final triggerLocal = DateTime(
        due.year,
        due.month,
        due.day,
        9, // 09:00
      ).subtract(Duration(days: offsetDays));

      if (!triggerLocal.isAfter(now)) {
        continue; // already in the past — skip silently
      }

      final notifId = _stableNotificationId(deadline.id, offsetDays);
      final tzTrigger = tz.TZDateTime.from(triggerLocal, tz.local);

      try {
        await _plugin.zonedSchedule(
          notifId,
          'LifeVault Reminder',
          // Generic content only — no policy numbers, names, diagnoses (§9)
          'You have a document deadline due in '
              '$offsetDays day${offsetDays == 1 ? '' : 's'}.',
          tzTrigger,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'lifevault_reminders',
              'Document Reminders',
              channelDescription: 'LifeVault document deadline reminders.',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.wallClockTime,
        );
        scheduledIds.add(notifId);
      } catch (_) {
        // If one notification fails, continue with remaining offsets.
        // The caller can detect partial scheduling via notificationIds count.
      }
    }

    // Persist notification IDs back to DB for cancellation on edit/delete
    if (scheduledIds.isNotEmpty) {
      await _repo.saveNotificationIds(deadline.id, scheduledIds);
    }

    return ReminderScheduleResult(
      scheduled: scheduledIds.isNotEmpty,
      permissionGranted: _permissionGranted,
      notificationIds: scheduledIds,
      statusMessage: scheduledIds.isEmpty
          ? 'All reminder offsets are in the past; no notifications scheduled.'
          : '${scheduledIds.length} reminder(s) scheduled.',
    );
  }

  /// D3.5 — Cancel all notifications associated with [documentId].
  /// Retrieves notification IDs from DB and cancels them individually.
  @override
  Future<void> cancelForDocument(String documentId) async {
    if (!_initialized) await initialize();

    final deadlines = await _repo.getDeadlinesForDocument(documentId);
    for (final dl in deadlines) {
      for (final id in dl.notificationIds) {
        await _plugin.cancel(id);
      }
    }
    // The DB cascade on deleteDocument clears the deadline rows automatically.
  }

  /// Cancel notifications for a single deadline (use after deadline edit).
  Future<void> cancelForDeadline(DeadlineRecord deadline) async {
    if (!_initialized) await initialize();
    for (final id in deadline.notificationIds) {
      await _plugin.cancel(id);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  /// Generates a stable int notification ID from deadline UUID + offset.
  /// IDs must fit in a signed 32-bit int for flutter_local_notifications.
  int _stableNotificationId(String deadlineId, int offsetDays) {
    final base = deadlineId.replaceAll('-', '');
    final hash = base.hashCode.abs() % 100000;
    return (hash * 100 + offsetDays) % 2147483647;
  }
}
