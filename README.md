# LifeVault v0.1 (Lite)

> **Photograph it once. Find it instantly. Never miss an important date.**

LifeVault transforms captured household documents (insurance policies, appliance warranties, utility bills, medical papers, vehicle records, and letters) into **private, organized, locally searchable records**, with **user-confirmed dates** and **local deadline reminders**.

---

## Privacy & Security Guarantee (v0.1)

- **100% On-Device & Offline:** Works completely in airplane mode from first launch.
- **Zero Network Transmission:** No LifeVault backend, no cloud OCR, no telemetry, no analytics, and **no `android.permission.INTERNET`** in the merged release manifest.
- **Explicit Verification:** OCR and date extraction proposals are always marked as unverified until explicitly reviewed and confirmed by the user.
- **Honest v0.1 Scope Disclosure:** Data is stored in app-private SQLite and private file storage with Android Auto Backup disabled (`android:allowBackup="false"`). **At-rest file/DB encryption and encrypted cloud backups are not yet implemented in v0.1**; uninstalling the app or clearing storage deletes local vault records.

---

## Repository Architecture & Team Ownership

See [`LifeVault_IMPLEMENTATION_MASTER_PLAN.md`](LifeVault_IMPLEMENTATION_MASTER_PLAN.md) and [`LifeVault_TEAM_TASK_SPLIT_AND_GIT_RULES.md`](LifeVault_TEAM_TASK_SPLIT_AND_GIT_RULES.md) for the locked product specifications and Git rules.

| Module | Owner | Branch | Owned Paths |
|---|---|---|---|
| Capture & Native OCR | Developer 1 | `feat/d1-capture-ocr` | `lib/features/capture_ocr/**`, `android/app/src/main/kotlin/**/LifeVaultOcrChannel.kt`, `assets/tessdata/**`, `docs/MODEL_MANIFEST.md`, `test/capture_ocr/**` |
| Classification & Date Extraction | Developer 2 | `feat/d2-classify-extract` | `lib/features/classification/**`, `test/classification/**` |
| Vault Storage, Grounded Q&A & Reminders | Developer 3 | `feat/d3-vault-reminders` | `lib/features/vault/**`, `test/vault/**` |
| App Shell, UI Screens, Contracts & Release | Developer 4 | `feat/d4-ui-integration` | `lib/core/contracts/**`, `lib/app/**`, `lib/features/screens/**`, `lib/main.dart`, `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `MainActivity.kt`, `.github/**`, `docs/TEST_REPORT.md`, `docs/LICENSES.md`, `test/screens/**` |

---

## Development Quickstart

```bash
# 1. Fetch and branch from main (use your assigned developer branch)
git fetch origin --prune
git switch main
git pull --ff-only origin main

# 2. Install dependencies & run checks
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

# 3. Build release-mode APK for offline physical-device testing
flutter build apk --release
```
