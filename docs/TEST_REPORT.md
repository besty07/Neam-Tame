# LifeVault v0.1 — Integration, CI & Release Test Report

**Owner:** Developer 4 (Integration Lead & Release Owner)  
**Target Artifact:** `LifeVault-Lite-v0.1-release-mode.apk`  
**Release Tag:** `v0.1-hackathon`  
**Signing Identity Disclosure:** Development/debug keystore (`signingConfig signingConfigs.debug` — release-mode hackathon/test build, **NOT** a production-signing identity per Master Plan Section 7.4).

---

## 1. Environment, Toolchain & Release APK Summary

| Property | Value / Details | Status |
|---|---|---|
| Repository | `https://github.com/besty07/Neam-Tame` | Active (`main` + `v0.1-hackathon`) |
| CI Flutter SDK | `3.24.3` (stable) on `ubuntu-latest` (`Java 17 Temurin`) | Verified (`Run #40074974882`) |
| Android SDK Configuration | `minSdkVersion 29` (Android 10+), `targetSdkVersion 34`, `compileSdk 35` | Verified |
| Application ID | `com.lifevault.app` | Verified |
| Release APK Filename | `LifeVault-Lite-v0.1-release-mode.apk` | Built & Uploaded |
| Release APK Size | `84,471,067 bytes` (`80.56 MB`) | Verified |
| Release APK SHA-256 | `25c598b87e8b04690e1f545c075980dd91a859821c465e1cce9d79f50a158d98` | Verified |
| Bundled OCR Model | `assets/tessdata/eng.traineddata` (`4,113,088 bytes`) | Verified |
| Bundled OCR Model SHA-256 | `7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2` | Verified |
| Target Device Baseline | Android 10+ (`API 29–34`), `arm64-v8a` / `armeabi-v7a`, 4 GB+ RAM | Documented |

---

## 2. Automated Test Suite & Static Analysis Summary

All **102 / 102 automated tests** pass in CI (`flutter test`) with **zero warnings or errors** from `flutter analyze` and `dart format --output=none --set-exit-if-changed lib test`:

| Module | Owner | Test Suite Path | Tests | Status |
|---|---|---|---|---|
| Capture & Native OCR (`MethodChannel`, EXIF/bounds, retry, error codes) | Developer 1 | `test/capture_ocr/capture_ocr_test.dart` | 15 | PASS |
| Classification & Date Extraction (10 categories, document types, dates, ambiguity) | Developer 2 | `test/classification/` | 44 | PASS |
| Vault SQLite Storage, FTS/Deterministic Q&A & Reminders | Developer 3 | `test/vault/vault_test.dart` | 28 | PASS |
| App Shell, Review Gate, Vault & Ask UI Workflows | Developer 4 | `test/screens/boot_smoke_test.dart`, `test/screens/screens_workflow_test.dart` | 11 | PASS |
| Full End-to-End Integration (D1 + D2 + D3 + D4 Real Services) | Developer 4 | `test/screens/e2e_integration_test.dart` | 4 | PASS |
| **Total** | **All (D1–D4)** | `test/**` | **102** | **100% PASS** |

---

## 3. Merged Release Manifest & Privacy Audit

During CI job `Build Release APK (Manual / Tag)` (Run `#40074974882`), the final merged release manifest (`build/app/intermediates/merged_manifests/release/AndroidManifest.xml`) was inspected automatically:

- **Zero Network Permissions:** `grep -q "android.permission.INTERNET"` confirmed **zero** `android.permission.INTERNET` declarations in the merged release manifest (`tools:node="remove"` enforced in `android/app/src/main/AndroidManifest.xml`).
- **Backups Excluded:** `android:allowBackup="false"`, `android:fullBackupContent="@xml/backup_rules"`, and `android:dataExtractionRules="@xml/data_extraction_rules"` verified in the merged `<application>` tag.
- **Zero Cloud/Telemetry SDKs:** Only local packages (`sqflite`, `path_provider`, `image_picker`, `flutter_local_notifications`, `timezone`, `crypto`, `intl`, and native `cz.adaptech.tesseract4android:tesseract4android:4.7.0`) are linked.

---

## 4. Integration Acceptance Checklist (Section H)

- [x] Base contracts committed and imported by all modules (`lib/core/contracts/`).
- [x] Capture/gallery & local staging wired (`D1` `CaptureService` + `OfflineOcrServiceImpl`); image remains in app-private storage.
- [x] Bundled English Tesseract OCR (`eng.traineddata`, SHA-256 verified before JNI init) wired via `LifeVaultOcrChannel` on `lifevault/ocr` (`D1` + `D4`).
- [x] Medical / Finance / Appliances / Vehicles / Insurance / Home / Identity / Education / Legal / Other categories visible and editable (`D2` + `D4`).
- [x] Type is independent of category; unsupported document types still store/search (`D2` + `D4`).
- [x] Insurance/warranty/bill date proposals have source snippets; invalid/ambiguous dates aren't auto-approved (`D2` + `D4`).
- [x] Confirmed record persisted in SQLite and app-private file storage (`D3` `VaultRepositoryImpl`).
- [x] Upcoming/overdue dashboard accurate on device date; delete/edit reschedule safe (`D3` + `D4`).
- [x] Ask returns verified data and opens its document, or explicitly says missing/ambiguous (`D3` + `D4`).
- [x] Local reminder wired with permission request and graceful denial state (`D3` `ReminderServiceImpl` + `D4`).
- [x] No network permission in `AndroidManifest.xml` (`tools:node="remove"` on `android.permission.INTERNET`), no cloud fallback/telemetry SDK.
- [x] Backups excluded (`android:allowBackup="false"`, `backup_rules.xml`, `data_extraction_rules.xml`) and security limits documented.
- [x] All 102 automated tests pass; `LifeVault-Lite-v0.1-release-mode.apk` built for offline installation in airplane mode.
- [x] GitHub PRs (`#1` through `#8`) merged cleanly into `main` with green CI checks and zero force pushes.
- [x] Repo and APK contain no private household files or actual personal identifiers.
- [x] APK checksum (`25c598b87e8b04690e1f545c075980dd91a859821c465e1cce9d79f50a158d98`), release-mode build and signing-key type, compatible Android/RAM and known limits recorded.

---

## 5. 2-Minute Redacted-Data Demo Script (Airplane Mode)

1. **Airplane Mode & Offline Proof (0:00 – 0:20):**
   - Enable **Airplane Mode** (Wi-Fi off, Mobile Data off) on the Android 10+ device.
   - Launch **LifeVault**. Point out the **100% Offline & On-Device** banner on the Home dashboard (`No cloud sync • No internet permission`).
2. **Capture & On-Device OCR + Extraction (0:20 – 0:55):**
   - Tap **Scan** in the bottom navigation bar (or **Scan or Import Document** on Home).
   - Capture or pick a sample synthetic/redacted document (e.g., *State Farm Auto Insurance Policy* or *Samsung Refrigerator Warranty*) or load a sample in the Scan screen.
   - LifeVault runs on-device OCR and deterministic classification/date extraction, opening the **Review & Verify** screen.
3. **Human-in-the-Loop Verification Gate (0:55 – 1:25):**
   - Show the **Unverified Proposal** banner, suggested Category (`Insurance` / `Appliances`), Document Type (`Insurance Policy` / `Warranty`), and extracted Action Date with its **source snippet** and **Verify Date** checkbox.
   - Confirm the title, category, and check **Verify Date**, then tap **Confirm & Save to Vault**.
4. **Home Deadlines, Vault Filtering & Grounded Ask Q&A (1:25 – 2:00):**
   - On **Home**, show the newly scheduled deadline under **Upcoming (Next 30 Days)** (or **Overdue**).
   - Switch to **Vault**, filter by Category chip or search by keyword, and tap the record to open **Document Detail** (showing verified dates, reminder status, edit/delete actions).
   - Switch to **Ask**, tap a quick-question chip (e.g., *"When does my insurance expire?"* or *"When does my warranty end?"*), and show the deterministic grounded answer with a one-tap link back to the verified source document.

---

## 6. Known v0.1 MVP Limitations

1. **English Printed OCR Only:** Uses bundled `eng.traineddata` (`tessdata_fast`). Handwritten notes or heavily skewed/low-light photos may require manual entry fallback.
2. **Single Page / Image per Document:** Multi-page PDFs and multi-image documents are deferred to P1.
3. **Deterministic Q&A Only:** `Ask LifeVault` queries verified local SQLite records for supported intents (`expiry`, `due_date`, `find_document`, `list_upcoming`) and does not perform open-ended generative LLM reasoning.
4. **No Encryption-at-Rest Claim:** Data is stored in app-private storage with zero network permissions and Android backup disabled, but without SQLCipher or file-level encryption in v0.1.
5. **Uninstalling Deletes Local Vault:** Because there is no cloud sync or automatic backup, uninstalling the app or clearing storage permanently deletes stored documents.
6. **OS Notification Delivery:** Uses Android local inexact notifications; exact delivery time depends on Android 13+ notification permissions and OEM battery optimization policies. The in-app Home deadline dashboard is always authoritative.
