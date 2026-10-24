# LifeVault v0.1 — Master Implementation Plan & Agent Source of Truth

**Status:** LOCKED BASELINE for a five-hour hackathon; execution begins only after environment checks.  
**Date:** 2026-10-24  
**Audience:** Four human developers and their coding AI agents.  
**Companion:** [`LifeVault_TEAM_TASK_SPLIT_AND_GIT_RULES.md`](LifeVault_TEAM_TASK_SPLIT_AND_GIT_RULES.md).  
**Priority:** This document overrides brainstorming and earlier prototypes. Where source code or installed SDK constraints disagree, report the discrepancy to the integration lead, document a minimal amendment, and do not silently change the product contract.

---

## 0. Instructions to every coding agent (read first)

1. Read **both** plan files completely before writing code. Follow the file ownership, branch, PR, and merge instructions in the companion task-split document.
2. Implement a **real, installable Android APK**, **not** a website, hosted service, mock UI, or demo that relies on internet APIs.
3. Prioritize an end-to-end, functional **LifeVault Lite**. A generative LLM is **optional** and must not block the base application.
4. **Do not transmit** documents, images, OCR text, extracted values, identifiers, analytics, or usage data to any server. Do not add remote endpoints, telemetry, cloud OCR, Firebase, advertisements, crash uploaders, or `INTERNET` permission.
5. The **GitHub repository is for source code and CI only**. Never commit or upload actual household papers, policy numbers, medical data, photos, local databases, personal screenshots, OCR logs, or generated real-user exports.
6. No invented dates, coverage terms, model benchmarks, unsupported answers, or success claims. The app must visibly distinguish `proposed`, `verified`, `missing`, and `ambiguous` data.
7. At the five-hour cutoff, ship the strongest tested Lite APK, known limitations, test results, and source; defer unfinished AI and secondary features.
8. Agents may automatically commit, push, create PRs and merge **their authorized task work** through the protected workflow. No force-push, bypassed protection, cross-owned edits, or unreviewed merge.

## 1. Project definition and user problem

**Name:** LifeVault  
**Tagline:** *Photograph it once. Find it instantly. Never miss an important date.*

People keep bills, appliance invoices, insurance documents, medical papers, vehicle documents and letters in scattered physical/digital places. They struggle to retrieve a particular document, find its relevant date, or remember to renew or pay something on time. LifeVault transforms captured documents into **private, organized, locally searchable records**, with **confirmed dates** and **local reminders**.

**Primary persona:** Android owner managing personal/family paperwork.  
**Primary jobs:**
- Capture a new paper with the camera, or import an existing image.
- See a suggested category and document type, correct if necessary.
- Verify recognized dates from the actual photo and schedule a deadline reminder.
- Browse documents by household category; search by name/category/asset.
- Ask a targeted question ("When does my bike insurance expire?") and see a verifiable answer.

**Non-negotiable architecture:** all user content stays on their device; zero LifeVault backend. Runtime operation including first launch must work in airplane mode with model files bundled in the APK.

**What the hackathon proves:** offline scan -> OCR -> classification/date candidates -> user verification -> secure-ish *local* storage (NOT marketed as encrypted) -> dashboard -> reminder -> evidence-backed question.

**What it does NOT prove:** production-grade encryption, cross-device sync, complex policy/legal interpretation, clinical decisions, full general document AI, notification arrival under every OEM power policy, or actual insurance coverage eligibility.

## 2. Locked scope, priorities and acceptance

### P0 — Required and demo-blocking

- Android application, Flutter + Dart UI, initial device target Android 10+ / 64-bit ARM / 6 GB physical RAM.
- Offline `image_picker` camera capture and image import: JPG/PNG (and other phone camera formats only if decoder handles them); one page/image per document in v0.1.
- Native offline OCR: Tesseract 5 through Tesseract4Android Kotlin bridge; **English `eng.traineddata` packaged in APK**.
- OCR failure fallback: document may still be saved and user may enter title, category, and date manually.
- Category organization across **Medical, Finance, Appliances, Vehicles, Insurance, Home & Utilities, Identity & Personal, Education, Legal & Letters, Other**.
- Document type separate from category (insurance policy, warranty, bill, invoice/receipt, medical record, prescription, registration, certificate, letter, other).
- Best-effort *suggested* category/type for ALL imported documents, with **user correction**; automatic date extraction specialized only for **insurance expiry**, **warranty expiry**, and **bill due dates**.
- Editable review screen showing original image, extracted fields, evidence snippet, confidence/ambiguity indicator; explicit user confirm.
- Local SQLite database + app-private copy of original image; SHA-256 duplicate detection.
- Local Home dashboard: upcoming, overdue, unverified; Vault: category filter, search, open original, edit/delete.
- "Ask LifeVault" deterministic supported queries using verified local records only; document source and date evidence shown; ambiguity/not-found handled.
- Deadline alerts with Android local notifications (subject to Android notification permission, scheduling restrictions, OEM battery behavior). In-app deadline dashboard always works.
- Release APK install/launch and full core workflow **offline on a physical 6 GB Android phone**.
- Explicit privacy verification: no `INTERNET` permission in **merged release manifest**, no remote traffic, backups disabled/excluded, no PII logging.

### P1 — Only after all P0 passes

- Multiple images/pages in one logical document; PDF import and local page rendering.
- Hindi/Marathi `tessdata_fast` language selection (bundle only if tested).
- Calendar `.ics` export, persistent notification rescheduling after reboot, UI polish.
- Better matching of warranty duration with purchase dates, without unsupported assumptions.
- App lock / encryption only if thoroughly designed and validated; otherwise document as future work.

### P2 — Explicitly excluded from hackathon commitment

- Qwen3-0.6B Q4_K_M/llama.cpp **optional experimental separate APK**; never make the core app depend on it.
- Cloud sync, accounts, website/backend, hosted search, push notifications, WhatsApp/SMS, server-side scanning, Firebase analytics, family multi-user sharing, iOS, payments, policy renewal/claims submission, medical advice, automatic deletion/archiving of sensitive records.

### Measurable P0 demonstration criteria

1. Fresh release APK installation on physical target; launch and scan with airplane mode enabled (no model downloads).
2. A real, permitted **redacted** insurance/warranty/bill photo goes through capture -> OCR -> review -> save.
3. User can correct a mistaken date; the saved deadline is the **confirmed** value, not the original OCR guess.
4. Verified deadlines appear on dashboard, sortable with overdue and next-30-days states; at least one local notification is demonstrated on a device that grants permission.
5. At least three supported questions return correct stored dates with document ID/title and original image/evidence; ambiguous and missing questions do not fabricate answers.
6. All categories exist; medical/finance/appliance files can be added, categorized and retrieved even when no specialized extractor exists.
7. Force-stop/reopen or process restart preserves documents and dates; deleting a record removes its copied local file and cancels its associated reminders.
8. No merged `INTERNET` permission; offline runtime tested; no sensitive files shipped in Git or release bundle.

## 3. Information taxonomy: category ≠ document type

A category answers **Where do I find it?** A type answers **What kind of document is it?** These fields are independent.

| Category (enum) | Examples | v0.1 extraction behavior |
|---|---|---|
| `medical` | prescriptions, lab bills, reports, insurance paperwork | Store, label, browse/search; manual deadline unless recognizable as supported bill/policy |
| `finance` | bank letters, tax notices, credit-card statements, receipts | Store/search; supported bill due-date extraction only |
| `appliances` | fridge invoice, washing-machine warranty | Warranty date extraction; manual fallback |
| `vehicles` | registration certificate, servicing bill, PUC paper | Vehicle-related date proposals only if type is supported insurance policy/bill; otherwise manual |
| `insurance` | bike, vehicle, home, health policy | Policy expiry extraction, not coverage eligibility |
| `home_utilities` | electricity, broadband, water, rent papers | Bill due-date extraction |
| `identity_personal` | identity records, letters | Store/search only; no identity-number extraction or unmasked display |
| `education` | fees, certificates, enrollment documents | Store/search; manual deadlines |
| `legal_letters` | agreements, official letters | Store/search; manual deadlines |
| `other` | uncategorized | Safe fallback |

**Supported type values:** `insurance_policy`, `warranty`, `bill`, `invoice_receipt`, `medical_record`, `prescription`, `registration`, `certificate`, `letter`, `other`.

**Classification:** lightweight keyword/signal scoring from recognized text; category/type suggestions are independent. Show why a suggestion was made; if inconclusive default to `other`/`other`, never silently infer a high-risk category. Always allow manual category and type override. Suggested category `insurance` may carry an `asset_name = Bike` so it remains discoverable through queries about the bike. Do not claim medically meaningful document analysis.

**Search:** index normalized title, category, type, asset label, and safe user-defined tags. For the MVP, avoid full OCR-text search containing sensitive policy numbers; a local-only OCR search is a post-MVP improvement with masking/UX consideration.

## 4. User experience and screen contracts

Navigation: **Home / Scan / Vault / Ask** (Review is entered from Scan and can be reopened from Vault for edits). Keep it responsive for portrait mobile.

### Home
- Summary tiles: documents, next 30-day deadlines, records needing verification.
- Sections: overdue, upcoming (sorted by due date), needs review; empty-state CTA to Scan.
- Each deadline item shows safe friendly title, date, days remaining, open document, edit, optional "remind me" action.
- No insurance policy numbers or medical details in default list or lock-screen notifications.

### Scan
- Buttons **Take Photo** and **Choose from Gallery**; show preview, retake, process.
- Use `image_picker` from app UI; it puts captures in cache. Move/copy to private persistent storage after user confirms save; implement lost-data recovery on Android startup.
- One clear loading state with cancel; never run OCR on UI thread.
- Failures: permission denied, user cancels, unreadable photo, OCR initialization missing model, low memory. Permit manual entry.

### Review (the key conversion screen)
- Original image with zoom if feasible; editable title, category, type, asset name.
- Date candidate rows: label, proposed normalized date, source snippet, ambiguity indicator and optional user edits.
- Show **Confirm & Save**, **Save without deadline**, **Retry scan**.
- Only confirmed dates create reminders. Dates whose text is ambiguous must be corrected or explicitly selected.
- If category is medical, avoid pushing recognized personal content into diagnostics/analytics (none exist); medical dates are not medical advice.

### Vault
- List, search, category filters, document detail with image/source, metadata, verified dates, edit/recategorize, delete with confirmation.
- No network sharing button or automatic cloud backup.

### Ask
- Simple typed question input and suggested chips: "bike insurance expiry", "fridge warranty", "electricity bill due".
- Supported intents: `expiry`, `due_date`, `find_document`, `list_upcoming`. Rules select records by title/asset/category.
- Responses: `answered`, `multiple_matches`, `unverified`, `not_found`, `unsupported_question`.
- Answer = verified database value plus linked original and saved evidence; no generative unverified claims.
- If multiple candidates match, present a choice; if unsupported, offer document search rather than inventing meaning.

## 5. Exact scan-to-deadline business flow

1. User selects/captures one photo. App checks file size (suggest ≤12 MB), MIME/decoder support, estimated decoded pixel budget, and a SHA-256 digest. Request rescan for implausibly large/corrupt images. The original never leaves device.
2. App creates a processing derivative: correct EXIF orientation; resize toward max edge ~2000–2400 px (tune on device); keep original safe. Do not scale so far that small printed dates become unreadable.
3. Flutter invokes native `OcrService.recognizeImage(path, language="eng")` via a stable MethodChannel. Native code initializes bundled language data in app-private `tessdata` once, decodes safely, performs Tesseract recognition off main thread, returns extracted text and optional coarse OCR confidence.
4. Classifier scores title/keywords (`policy`, `insurance`, `warranty`, `valid until`, `due date`, `invoice`, etc.) and suggests category/type. Date engine identifies labeled dates with snippets and parses unambiguous formats. It distinguishes `coverage_start`, `expiry`, `purchase`, `issue`, `due`, and `unknown` — only `expiry`/`due` create candidate deadlines. If only issue/purchase date exists, do not call it expiry.
5. Review displays candidates and original; user corrects category, title, date and document type and explicitly confirms. Without a date, save a searchable document with `needs_review` or `verified_no_deadline`.
6. Repository persists the original image under an ID-generated filename in private storage and metadata in SQLite inside a transaction-like flow. If DB write fails, remove the new file; if file copy fails, do not create a broken DB record. Store supporting snippet/page and provenance (`ocr_proposed`, `user_confirmed`, `manual`). Duplicate SHA-256 prompts open-existing or save another labeled copy.
7. Confirmed `Deadline` created with type and date `YYYY-MM-DD`, in user's device local timezone. Default reminders suggested 30, 7, 1 days before where still in future. No automatic reminder from unverified data.
8. Android local notification service schedules notifications; permission-denied or OS restriction is a visible state, not a silent success. Save notification IDs and allow rescheduling after edits/deletes. Use reasonably timed **inexact** alarms by default to avoid Android exact-alarm special permission; do not guarantee minute-perfect delivery.
9. Home reads SQLite and computes overdue/upcoming using today's local date. Ask retrieves stored verified records, cites original document and snippet, and refuses unsupported claims.

## 6. Data model & source-of-truth API contracts

**All coding agents implement against the frozen Dart contracts committed by the integration lead in the first 20 minutes.** Do not independently redefine shared enums or classes. Suggested domain DTOs and signatures below are semantic contracts; the committed Dart API file is definitive for names/types.

### Entities

- `DocumentRecord`: `id` UUID/string, `title`, `category` enum, `documentType` enum, `assetName?`, `tags?`, `originalPath`, `sha256`, `ocrStatus`, `verificationStatus`, `createdAt`, `updatedAt`.
- `OcrOutput`: `text`, `language`, `page=1`, `confidence?` (null if unavailable), `processingMs?`, `errorCode?`.
- `ExtractionResult`: `suggestedCategory`, `suggestedType`, `categoryEvidence?`, `dateCandidates[]`, `assetNameSuggestion?`.
- `DateCandidate`: `fieldKind` (`expiry|due|start|purchase|issue|unknown`), `rawText`, `isoDate?`, `sourceSnippet`, `page=1`, `ambiguous`, `confidenceLevel` (`high|medium|low` = heuristic, not calibrated probability).
- `VerifiedDocumentInput`: original temporary path, corrected title/category/type/asset, verified deadline list, OCR evidence; can have no deadlines.
- `DeadlineRecord`: `id`, `documentId`, `kind` (`expiry|bill_due|manual`), `dateIso`, `evidenceSnippet?`, `page?`, `isVerified=true`, `reminderOffsetsDays`, `notificationIds`, `lastScheduledAt?`.
- `AnswerResult`: `status` (`answered|multiple_matches|unverified|not_found|unsupported_question`), `text`, `documentIds[]`, `deadlineIds[]`, `evidenceSnippet?`, `sourcePage?`.

### Frozen interface sketch

```dart
abstract interface class OfflineOcrService {
  Future<OcrOutput> recognizeImage(String localImagePath, {String language = 'eng'});
}
abstract interface class DocumentExtractionService {
  ExtractionResult extract(String ocrText);
}
abstract interface class VaultRepository {
  Future<DocumentRecord> saveVerified(VerifiedDocumentInput input);
  Future<List<DocumentRecord>> search({String? text, DocumentCategory? category});
  Future<List<DeadlineRecord>> getDeadlines({bool verifiedOnly = true});
  Future<void> deleteDocument(String documentId);
}
abstract interface class QuestionService {
  Future<AnswerResult> answer(String question);
}
abstract interface class ReminderService {
  Future<ReminderScheduleResult> schedule(DeadlineRecord deadline);
  Future<void> cancelForDocument(String documentId);
}
```

### SQLite v1 schema (migration 001, repository-owned)

```sql
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  document_type TEXT NOT NULL,
  asset_name TEXT,
  original_path TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  ocr_status TEXT NOT NULL,
  verification_status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX idx_documents_category ON documents(category);
CREATE INDEX idx_documents_hash ON documents(sha256);
CREATE TABLE evidence (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  field_kind TEXT NOT NULL,
  proposed_raw TEXT,
  proposed_iso TEXT,
  confirmed_iso TEXT,
  source_snippet TEXT,
  page_number INTEGER NOT NULL DEFAULT 1,
  provenance TEXT NOT NULL,
  is_verified INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE deadlines (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  due_date_iso TEXT NOT NULL,
  evidence_id TEXT REFERENCES evidence(id),
  verified INTEGER NOT NULL,
  reminder_offsets_json TEXT NOT NULL DEFAULT '[30,7,1]',
  notification_ids_json TEXT NOT NULL DEFAULT '[]',
  updated_at TEXT NOT NULL
);
CREATE INDEX idx_deadlines_due ON deadlines(due_date_iso);
```

SQLite `PRAGMA foreign_keys=ON` on every connection. Store only relative or validated app-private local paths when possible. Strict delete should cancel reminders and remove image/thumbnail; handle partial failure with recoverable error instead of silent orphaning.

**Note:** No broad OCR text table in Lite by default. Store only evidence snippets needed for provenance to reduce sensitive searchable copies. If full-text OCR storage becomes necessary, flag it as separate privacy-reviewed scope.

## 7. Module implementation specification

### 7.1 Capture and OCR (Owner: Developer 1)

- Flutter `image_picker` service (camera/gallery), persistent copy only after verified save, recovery via `retrieveLostData` on startup.
- Native Kotlin `MethodChannel('lifevault/ocr')` API: `recognizeImage({path, language})`. Return `text`, `page`, `processingMs`, `confidence` if reliably available. Report structured failure codes (`MODEL_MISSING`, `DECODE_FAILED`, `OCR_FAILED`).
- Bundle `eng.traineddata` in `assets/tessdata/` and copy it into native app files dir `.../tessdata/` with a one-time hash check; do not download it. `TessBaseAPI.init(datapath, "eng")`; perform OCR in background; call `recycle()`/`end()` to free native resources.
- Prevent big decoded bitmap OOM (limit dimension/resolution), accept valid rotated photos, use no runtime Internet.
- Test on real redacted paper photo and on air-gapped device.
- Android plugin/Gradle compatibility requires a genuine early spike; if Kotlin bridge unusable by minute 30, notify integration lead; fallback to native Android UI is a **team decision**, not a unilateral rewrite.

### 7.2 Classification and date extraction (Owner: Developer 2)

- Pure Dart synchronous `extract(text)` returns suggested enums and candidates, no network or model.
- Build keyword scoring/dictionaries for all ten categories; priority extraction on insurance, warranties and bills.
- Extract `dd MMM yyyy`, `dd/MM/yyyy`, `dd-MM-yyyy`, `yyyy-MM-dd` and strongly labeled variants. Reject invalid dates, two-digit years unless user confirms, ambiguous numerical day/month, OCR confusions like `O` vs `0` without evidence.
- Detect phrases `Expiry Date`, `Valid Upto`, `Policy Period To`, `Warranty Ends`, `Payment Due`, `Pay Before`; identify first/last date only when label is clear. Keep source snippet and location page=1.
- Warranty from "purchase + 12 months" may produce a marked derived *proposal* only if duration and purchase date clear; user must confirm. Do not calculate policy coverage validity or interpret exclusions.
- Return empty candidates rather than guess. Tests for mixed dates, ambiguous dates, false positives and keyword category overlap.

### 7.3 Persistence, questions, and reminders (Owner: Developer 3)

- Implement migrations and SQLite repositories with `sqflite`, file storage with `path_provider`, document IDs, safe copies/deletes, hash duplicate lookup, deadline query sorted by date.
- `QuestionService` uses verified `VaultRepository` records. Parse intent + matching of normalized document titles, asset labels and types; return correct status and source reference. No LLM/HTTP.
- `ReminderService` uses `flutter_local_notifications` and a timezone strategy; request notification permission on Android 13+, schedule local **inexact** notifications, visibly expose permission denial, keep notification IDs to cancel/reschedule on edit/delete. Use harmless generic notification text by default.
- Reminder logic never schedules from unverified extraction. Handle due dates in past and short offsets that have elapsed. Respect device's current local timezone for calendar dates; test timezone/device-date change.
- Ensure Android manifest additions needed by notification plugin are submitted as a short patch request to Dev 4, the only owner of the shared manifest.

### 7.4 App UI, navigation, integration, release (Owner: Developer 4 / Integration lead)

- Scaffold and freeze interfaces, dependencies, app ID and theme by 0:20; distribute to all members via main branch.
- Build Home, Scan, Review, Vault and Ask screens using the frozen DTOs and interfaces. Only concrete services permitted in final. For isolated widget tests, local test fixtures/fakes are permitted; remove demo hardcoded screens from APK.
- Build service composition at `lib/app/boot.dart`, manage processing state/errors, and connect real OCR -> extraction -> review -> DB -> alerts.
- Sole owner of shared files (`pubspec.yaml`, `pubspec.lock`, `android/app/src/main/AndroidManifest.xml`, `MainActivity.kt` platform-channel registration, app entrypoint, root Gradle settings, CI workflow, contract classes). Other agents file a dependency/manifest request rather than editing those files.
- Build **release-mode installable APK** as the mandatory privacy-tested artifact (`flutter build apk --release`). Verify the *final release APK merged manifest* has no `INTERNET` permission. If release is temporarily signed using a development/debug keystore, label this transparently as a **release-mode hackathon/test build, NOT a production-signing identity**; use a team-controlled release signing key for any later public distribution. Do not commit private keys. Flutter debug builds may include debug-only network permissions and are NOT valid evidence of the final no-network-permission claim.
- Validate on actual 6 GB phone, install with `adb install -r <path>`, run airplane-mode tests; save evidence screenshots with no personal details. Name the artifact based on actual build type, not falsely `release`.

## 8. Package and model policy

### Initial Flutter packages (integration lead pins compatible stable versions)

- `image_picker`: camera/gallery; test lost-data recovery and cache handling.
- `sqflite`, `path_provider`, `path`: SQLite/private paths.
- `flutter_local_notifications`, `timezone`: Android local scheduling and local-time conversion.
- `crypto`: SHA-256; `uuid` optional, otherwise secure UUID implementation.
- `intl`: date formatting (date parser can be custom, tested Dart code).
- `flutter_test` and analyzer for unit/widget tests.
- Native `cz.adaptech.tesseract4android:tesseract4android` and packaged Tesseract `eng.traineddata`.

**Version rule:** Run `flutter --version` and `flutter doctor -v` on the actual build machine, resolve SDK-compatible versions, pin the versions in `pubspec.lock` and record them in build notes. Do not blindly copy a package's current version if it exceeds the installed Flutter SDK. Avoid unsupported Gradle/Kotlin upgrades during hackathon.

**Licenses:** Tesseract, Tesseract4Android, and `tessdata_fast` are Apache 2.0; license notices for transitive dependencies must be bundled. Source and hashes of OCR model go in `docs/MODEL_MANIFEST.md`. `Qwen3-0.6B` is **optional open-weight** (Apache 2.0); `llama.cpp` inference runtime is open-source (MIT) and not in Lite APK.

**Do not add model runtime for Qwen to mandatory APK.** Any experimental Qwen APK must: use a separately reviewed branch/build, include weights before install, use only on-device inference, never override user-verified dates, and be dropped if not stable by hour 3.

## 9. Android platform and offline privacy requirements

- Android `minSdk` should satisfy **all selected packages**; app product baseline Android 10 (API 29) is intentionally conservative, test with installed toolchain. `targetSdk` must satisfy the latest published SDK/market distribution constraints if later released; hackathon APK can use a toolchain-supported version, but document it.
- Android `INTERNET` permission must **not exist** in merged release manifest. No network clients, analytics, crash uploaders, remote config or dynamic model downloads.
- Set `android:allowBackup="false"` and add appropriate `fullBackupContent` / `dataExtractionRules` exclusions for both cloud and device-to-device transfer. Test actual device behavior; manufacturer differences mean this is not a mathematical security guarantee.
- Store files in app-private directory, not shared MediaStore/gallery by default; OCR temporary images cleaned up. Never dump OCR/policy content to logs, analytics, Git or screenshots.
- Configure no exported providers/activity for document content except Android's required launch activity. Use Android system file/camera intents for input, validate returned URI/path, and do not trust external filenames.
- Default notification content to "LifeVault: document reminder due soon" rather than personal account numbers, diagnoses or policy details.
- Security claim for v0.1: **local and no app network transmission**. **Do not claim at-rest encryption**; consider file encryption, biometric auth and encrypted backup as production blockers, especially for medical/identity data.
- Explicitly explain to users that uninstalling app/clearing storage can delete vault contents unless they have exported copies; do not pretend backup exists.

## 10. Hardware tests, quality gates and failure handling

**Primary:** actual 6 GB RAM, `arm64-v8a`, Android 10+ phone. **Secondary if available:** different-chipset 6 GB phone; stress on 4 GB Lite phone optional. 

| Scenario | Target/acceptance | Failure behavior |
|---|---|---|
| Offline first launch | Starts in airplane mode, no downloads/sign-in | Hard fail if network needed |
| Image OCR | 10 clear redacted docs; target ≤10 sec per image on primary device (aspirational) | Offer retry/manual save |
| Extraction | Compare proposed dates against manually checked ground truth; never auto-verify | Mark ambiguous/missing |
| OCR 10 times | No OOM/crash; base app PSS engineering target ≤700 MB | Resize/page limit; document measured results |
| Persistence | Kill/relaunch restores records and dates | Show explicit recovery/error state |
| Questions | Verified dates exactly equal stored records, no invented answers in 5 negative queries | Multiple/not found/unverified/unsupported |
| Notifications | Test permission-granted near-term local alert, and denied-permission state | Dashboard remains reliable |
| Privacy | Inspect merged APK manifest; airplane-mode and network monitor check | Do not ship until no external path |
| Build | APK installs on a clean Android phone; no developer tools needed at runtime | Document blocker if packaging fails |

Sample capture: use **authorized and redacted real documents** in private local testing. Synthetic text fixtures are allowed for unit tests only; final demonstration must not pretend fixture outputs came from live OCR.

Suggested diagnostics (no sensitive content):

```bash
flutter doctor -v
flutter analyze
flutter test
flutter build apk --release
adb devices
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell dumpsys meminfo com.lifevault.app
```

For privacy, inspect release/debug merged manifest with Android APK Analyzer or `apkanalyzer manifest print <apk>` depending on installed SDK. Record APK SHA-256 and measured size in `docs/TEST_REPORT.md`. When testing lack of network usage, verify both missing permission and runtime behavior; airplane mode alone is not a complete independent network proof.

## 11. Five-hour schedule, gates and fallback rules

| Clock | Must be accomplished | Gate / fallback |
|---|---|---|
| 0:00–0:20 | Dev 4 scaffolds repo, locks DTO/contracts, ownership, lockfile, branch protection/CI; everyone verifies device/toolchain | No feature edits until baseline merge |
| 0:20–1:00 | D1 demonstrates native OCR on image; D2 tests classifier/date parser; D3 DB init + notification probe; D4 shell/screens | If OCR JNI fails by 0:30, make coordinated scope decision; never switch silently |
| 1:00–2:00 | Independent modules reach unit tests; app displays first real scan/extraction | Date extraction/manual fallback mandatory |
| 2:00–3:00 | D3 storage/query/reminders implemented; D4 composes first E2E; agents push PRs with checks | By hour 3, real document should be saved and shown in dashboard |
| 3:00–4:00 | Merge verified feature PRs; fix seams; test dashboard/Ask/notifications, category navigation | Freeze features at hour 3:30; skip Qwen |
| 4:00–5:00 | Packaging, physical-device stress, privacy checks, final demo, known limitations | Ship tested Lite even if some P1 omitted |

**Hard cutoffs:** no speculative new plugin after hour 2; no new user-facing P1 feature after hour 3:30; do not compromise reliability by building optional LLM near the deadline.

## 12. File tree & boundaries

```text
lifevault/
├── README.md
├── LifeVault_IMPLEMENTATION_MASTER_PLAN.md
├── LifeVault_TEAM_TASK_SPLIT_AND_GIT_RULES.md
├── pubspec.yaml                    # DEV 4 ONLY
├── pubspec.lock                    # DEV 4 ONLY
├── lib/
│   ├── main.dart                   # DEV 4
│   ├── app/                        # DEV 4; service composition / routing / theme
│   ├── core/contracts/             # DEV 4; frozen DTOs and interfaces
│   ├── features/capture_ocr/       # DEV 1
│   ├── features/classification/    # DEV 2
│   ├── features/vault/             # DEV 3; persistence + Q&A + reminders
│   └── features/screens/           # DEV 4; UI only
├── android/app/src/main/
│   ├── AndroidManifest.xml         # DEV 4 ONLY
│   └── kotlin/.../LifeVaultOcrChannel.kt  # DEV 1 ONLY
├── assets/tessdata/eng.traineddata # DEV 1 ONLY
├── test/
│   ├── capture_ocr/               # DEV 1
│   ├── classification/            # DEV 2
│   ├── vault/                     # DEV 3
│   └── screens/                   # DEV 4
├── docs/
│   ├── MODEL_MANIFEST.md          # DEV 1
│   ├── TEST_REPORT.md             # DEV 4
│   └── LICENSES.md                # DEV 4
├── .github/workflows/flutter-ci.yml  # DEV 4
└── .gitignore                     # DEV 4; exclude ALL private data
```

Note: `android` folder paths use the actual generated Kotlin package and must not be hardcoded until bootstrap. `AndroidManifest.xml`, `MainActivity.kt` registration, and Gradle build files remain under Dev 4 even when other features need platform changes; submit minimal patch notes to Dev 4.

## 13. Source control / agent policy (summary; full rules in companion)

- Branches: `feat/d1-capture-ocr`, `feat/d2-classify-extract`, `feat/d3-vault-reminders`, `feat/d4-ui-integration` created from stabilized main.
- Each agent works in its own clone or `git worktree`, not four agents in one working tree.
- Agents **automatically** `git fetch`, commit scoped files, push their branch, create/update PR with `gh`, and monitor checks; no direct pushes to protected `main`.
- Only integration lead's agent merges after green CI, conflicts resolved, and configured review approvals. Squash merge recommended. Human team members review real-device/privacy changes; no self-approval.
- Shared files changed only by owner to avoid merge conflicts. Agents do not rewrite contracts, Flutter or Android manifests, dependency lockfiles, CI, or others' modules.
- If permissions are unavailable, report the exact blocked Git command and hand over the prepared commit; do not bypass branch protection.

## 14. Release artifacts and definition of done

**Mandatory:**
- `LifeVault-Lite-v0.1-release-mode.apk` — tested/installable release-mode APK (signing-key type documented), SHA-256 published.
- GitHub source repo with commit/tag `v0.1-hackathon`, toolchain/dependency lock and build instructions.
- `docs/TEST_REPORT.md`: device model (no personal identifiers), Android version/RAM, OCR times, tests/limitations, network/permission validation, app backup setting.
- `docs/MODEL_MANIFEST.md`: Tesseract engine/wrapper/version, traineddata name/source/license/checksum, packaged/not packaged.
- License notices and a 2-minute redacted-data demo script.

**Definition of done:** A team member with the APK on a test Android device can install it with network disabled, scan a real redacted document, review a real extracted date or enter one manually, categorize the record (including a Medical or Finance example), save locally, find it again, see an upcoming deadline, answer a supported date question from that record, and receive a local notification when permissions/OS permit. Uncertain dates must not masquerade as verified facts.

**Known MVP limits to disclose:** English printed OCR only unless additional languages verified; one image per document; variable scan quality; no PDF in P0; no general conversational reasoning; no encryption-at-rest claim; OS notification timing is not guaranteed; app private data may be deleted on uninstall.

## 15. External engineering references (validate against selected local versions)

- Flutter platform channels (native Kotlin integration): https://docs.flutter.dev/platform-integration/platform-channels
- Tesseract4Android README and Android API/asset requirements: https://github.com/adaptech-cz/Tesseract4Android/blob/master/README.md
- Open OCR trained data and Apache 2.0 license: https://github.com/tesseract-ocr/tessdata_fast
- Flutter image_picker behavior / lost data / cached files: https://pub.dev/packages/image_picker
- Flutter path_provider app-private locations: https://pub.dev/packages/path_provider
- Flutter local notifications and Android exact-alarm restrictions: https://pub.dev/packages/flutter_local_notifications
- Android Auto Backup and data-extraction rules: https://developer.android.com/identity/data/autobackup
- GitHub branch protection and status checks: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches
- GitHub CLI for agent-created PRs: https://cli.github.com/manual/gh_pr_create and https://cli.github.com/manual/gh_pr_merge

**Never infer that a dependency exists on the build machine from the existence of these references. Verify installed Flutter/Gradle/NDK, phone, available model assets, `gh` authentication and GitHub permissions before coding.**
