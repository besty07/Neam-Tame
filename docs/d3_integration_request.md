# D3 Integration Request for Developer 4

**Requester:** Developer 3
**Date:** 2026-10-24
**Urgency:** P0

---

## INTEGRATION REQUEST

```
Requester: D3
Shared files: pubspec.yaml, android/app/src/main/AndroidManifest.xml
```

---

## 1. `pubspec.yaml` — Required packages

Please add the following to the `dependencies:` section. Versions should be pinned by you to what's compatible with the installed Flutter SDK (run `flutter pub add` or resolve manually):

```yaml
dependencies:
  # D3 — Persistence
  sqflite: ^2.3.0
  path_provider: ^2.1.0
  path: ^1.9.0

  # D3 — Notifications
  flutter_local_notifications: ^17.0.0
  timezone: ^0.9.0

  # D3 — Crypto / ID
  crypto: ^3.0.3
  uuid: ^4.3.3
```

And for `dev_dependencies:` (for D3 unit tests):

```yaml
dev_dependencies:
  sqflite_common_ffi: ^2.3.0  # enables in-memory SQLite in flutter_test on desktop
```

**Why:** D3 uses sqflite for SQLite, path_provider for app-private storage paths, flutter_local_notifications + timezone for Android local reminders, crypto for SHA-256 duplicate detection, and uuid for document IDs.

---

## 2. `AndroidManifest.xml` — Required additions

Please add the following permissions and receivers inside `<manifest>` and `<application>` as appropriate. These are required by `flutter_local_notifications` v17+ on Android 13+.

### Inside `<manifest>` (at the same level as `<uses-permission android:name="android.permission.CAMERA">`):

```xml
<!-- D3: Local notifications — Android 13+ POST_NOTIFICATIONS -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- D3: Required for scheduling local notifications (inexact alarms only — no SCHEDULE_EXACT_ALARM needed) -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

### Inside `<application>`:

```xml
<!-- D3: Required by flutter_local_notifications for scheduling after reboot -->
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>

<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
    android:exported="false"/>
```

> **Note:** Receiver class names depend on the exact `flutter_local_notifications` version you pin. Please verify against the package's `CHANGELOG.md` or `README.md` for the exact version you select.

---

## 3. Privacy notes (important for D3)

- D3 **does not** add `INTERNET` or any network permission.
- Notification content is generic: `"You have a document deadline due in N days."` — no policy numbers, names, or personal data.
- D3 stores files in `getApplicationDocumentsDirectory()` which respects `android:allowBackup="false"` set by D4.
- No analytics, telemetry, or crash-reporting packages are included.

---

## 4. No changes needed to

- `MainActivity.kt` — D3 uses only Dart/Flutter notification APIs; no MethodChannel needed.
- `Gradle` files — flutter_local_notifications uses standard AndroidX; no NDK changes needed.
- Any other shared files.

---

## 5. Minimum safe implementation snippet

If you want to do a minimal test of the notification channel appearing, add only the `POST_NOTIFICATIONS` permission and the two receivers. The `RECEIVE_BOOT_COMPLETED` permission is needed for notifications to survive device reboot (P1 feature), but P0 works without it.

---

*D3 will not edit `pubspec.yaml` or `AndroidManifest.xml` directly. Awaiting your confirmation / merge of these changes before D3 tests notifications on device.*
