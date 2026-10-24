# LifeVault v0.1 — Integration & Hardware Test Report

**Owner:** Developer 4 (Integration Lead)  
**Target Artifact:** `LifeVault-Lite-v0.1-release-mode.apk`  
**Signing Identity:** Development/debug keystore (`release-mode hackathon/test build, NOT a production-signing identity`)

---

## 1. Environment & Toolchain Summary

| Component | Version / Details | Status |
|---|---|---|
| Repository | `https://github.com/besty07/Neam-Tame` | Active |
| CI Flutter SDK | `3.24.3` (stable) | Configured in `.github/workflows/flutter-ci.yml` |
| Target Android SDK | `minSdkVersion 29` (Android 10+), `targetSdkVersion 34` | Configured |
| Application ID | `com.lifevault.app` | Configured |

---

## 2. Integration Acceptance Checklist (Section H)

- [x] Base contracts committed and imported by all modules (`lib/core/contracts/`).
- [ ] Capture/gallery on actual Android hardware; image remains local (`D1`).
- [ ] Bundled English Tesseract OCR returns genuine text offline (`D1`).
- [ ] Medical / Finance / Appliances / Vehicles / Insurance / Home / Identity / Education / Legal / Other categories visible and editable (`D2` + `D4`).
- [ ] Type is independent of category; unsupported document types still store/search (`D2` + `D4`).
- [ ] Insurance/warranty/bill date proposals have source snippets; invalid/ambiguous dates aren't auto-approved (`D2` + `D4`).
- [ ] Confirmed record persisted in SQLite and app-private file storage (`D3`).
- [ ] Upcoming/overdue dashboard accurate on device date; delete/edit reschedule safe (`D3` + `D4`).
- [ ] Ask returns verified data and opens its document, or explicitly says missing/ambiguous (`D3` + `D4`).
- [ ] Local reminder tested with permission granted; denial state tested (`D3` + `D4`).
- [x] No network permission in `AndroidManifest.xml` (`tools:node="remove"` on `android.permission.INTERNET`), no cloud fallback/telemetry SDK.
- [x] Backups excluded (`android:allowBackup="false"`, `backup_rules.xml`, `data_extraction_rules.xml`) and security limits documented.
- [ ] Tests pass; APK installs on target phone in airplane mode.
- [ ] GitHub PRs merged with required reviews/checks and no force pushes.
- [x] Repo and APK contain no private household files or actual identifiers.
- [ ] APK checksum, release-mode build and signing-key type, compatible Android/RAM and known limits recorded.

---

## 3. Known v0.1 MVP Limitations

1. **English Printed OCR Only:** Uses bundled `eng.traineddata` (`tessdata_fast`). Handwritten notes or heavily skewed/low-light photos may require manual entry fallback.
2. **Single Page / Image per Document:** Multi-page PDFs and multi-image documents are deferred to P1.
3. **Deterministic Q&A Only:** `Ask LifeVault` queries verified local SQLite records for supported intents (`expiry`, `due_date`, `find_document`, `list_upcoming`) and does not perform open-ended generative LLM reasoning.
4. **No Encryption-at-Rest Claim:** Data is stored in app-private storage with zero network permissions and Android backup disabled, but without SQLCipher or file-level encryption in v0.1.
5. **Uninstalling Deletes Local Vault:** Because there is no cloud sync or automatic backup, uninstalling the app or clearing storage permanently deletes stored documents.
6. **OS Notification Delivery:** Uses Android local inexact notifications; exact delivery time depends on Android 13+ notification permissions and OEM battery optimization policies. The in-app Home deadline dashboard is always authoritative.
