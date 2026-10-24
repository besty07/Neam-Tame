# LifeVault v0.1 — Four-Developer Task Split, Agent Prompts & GitHub Rules

**Status:** LOCKED delivery protocol for the five-hour hackathon.  
**Date:** 2026-10-24  
**Source of truth for product:** [`LifeVault_IMPLEMENTATION_MASTER_PLAN.md`](LifeVault_IMPLEMENTATION_MASTER_PLAN.md).  
**Audience:** 4 human developers, each paired with an AI coding agent; one shared GitHub repository.  
**Primary purpose:** Maximize parallel work, reduce shared-file collisions, and let agents perform their own fetch/commit/push/PR operations safely.

---

## A. Team operating agreement (mandatory)

1. **Developer 4 is integration lead/release owner.** The other developers build in isolated, non-overlapping folders. Developer 4 owns app wiring, shared dependencies, Android manifest, CI, and final APK.
2. **One branch per developer; one clone or worktree per agent.** Never let four agents run Git mutations in the same worktree.
3. **The `main` branch is protected.** No direct feature pushes to main, force push, `--no-verify`, deleted history, or `--admin` protection bypass.
4. The coding agents are **authorized to commit and push their own assigned implementation** and create PRs without recurring permission requests. Only authorized authenticated users/agents may push to the actual repository. No agent may leak credentials or private data.
5. Agents may merge PRs **only when** status checks pass, GitHub's required independent review is present, no unresolved comments/conflicts remain, and integration lead has not placed a freeze. Dev 4's agent should execute the merges in order. Never auto-approve your own PR or bypass approvals.
6. All changes to common contracts/dependencies/platform manifest belong to Dev 4. Other developers issue a short integration request; do not "quickly fix" another developer's files.
7. Tests may use synthetic in-repo strings/images if safely created; the final running app and live demo may not fake OCR, data, answers or notifications. Actual authorized household images stay local to devices and outside the repo.
8. When blocked, **preserve working code**, push an honest WIP branch/PR if it is safe, write the blocker, and continue independent tests. Never claim success based on unexecuted commands.

## B. Repository bootstrap: first 20 minutes (Dev 4 leads)

**Before anyone starts feature code:**

1. Confirm repo owner/name and that each person has push access; `gh auth status`, `git remote -v` and correct local git identity.
2. Confirm one real Android phone with ~6 GB RAM; `flutter doctor -v`, `adb devices`, Android SDK toolchain, emulator/device compatibility, and GitHub network access **for source control only**.
3. Create Flutter project (or validate existing scaffold) with application ID `com.lifevault.app` unless already reserved; Android 10+ target; record actual toolchain versions.
4. Commit the two plan files into repo root. Add privacy-conscious `.gitignore`: ignore local documents, vault DBs, captured images, OCR outputs, personal samples, secrets, private keys, generated export files, build intermediates. Do **not** ignore the required licensed `assets/tessdata/eng.traineddata` asset.
5. Commit the frozen DTO/interface definitions under `lib/core/contracts/`; skeleton folders, app entrypoint, plugin dependency list (`pubspec.yaml` + lock), and minimal passing widget test; do not build everyone's features in this phase.
6. Configure GitHub protection/ruleset on `main` where available: PR required, 1 approval from a different human team member, required CI, no force push/delete, conversation resolution. Enable squash merge. Require no `--admin` bypass. Repo administrators may need to configure this manually; agents must check actual settings instead of pretending they exist.
7. Add lean GitHub Actions Flutter CI for `flutter pub get`, formatting check (`dart format --output=none --set-exit-if-changed lib test`), `flutter analyze`, `flutter test`. Android APK build may be a separate/manual job because native toolchain is more fragile/time-consuming.
8. Push this bootstrap commit and let all teammates branch from the same main commit. Record its SHA in chat or a shared coordination message.

**Bootstrap commands (run only in the authorized GitHub clone; adjust URLs and existing state):**

```bash
# Run once on a fresh repo/workspace; if repo already exists, do not reinitialize destructively.
git status --short
git remote -v
gh auth status
flutter doctor -v
adb devices

git switch main
git pull --ff-only origin main
# Dev 4 creates/commits scaffold, contracts, plans, CI and shared config.
git add README.md pubspec.yaml pubspec.lock lib/core lib/main.dart .gitignore .github LifeVault_*.md
# Stage only paths that actually exist; names above are illustrative.
git commit -m "chore: initialize LifeVault contracts and hackathon scaffold"
git push origin main    # ONLY for authorized initial bootstrap; after protection, PRs only.
```

**If `main` was protected before bootstrap**, use `chore/bootstrap-contracts` and merge it through an approved PR. Do not disable protection.

**Best practice:** each developer clones independently. If sharing one machine, use `git worktree add ../lifevault-d1 -b feat/d1-capture-ocr origin/main` etc., and run each coding agent from its own path.

## C. Ownership matrix: zero planned file overlap

| Owner | Branch | Exclusive production code ownership | Exclusive tests | Must NOT edit |
|---|---|---|---|---|
| Dev 1 — Capture/OCR | `feat/d1-capture-ocr` | `lib/features/capture_ocr/**`, `android/app/src/main/kotlin/**/LifeVaultOcrChannel.kt` and related own Kotlin OCR files, `assets/tessdata/**`, `docs/MODEL_MANIFEST.md` | `test/capture_ocr/**` | UI, contracts, pubspec, Gradle root, manifest, DB |
| Dev 2 — Categories/Extraction | `feat/d2-classify-extract` | `lib/features/classification/**` | `test/classification/**` | UI, contracts, platform code, DB, manifest, pubspec |
| Dev 3 — Vault/Reminders/Questions | `feat/d3-vault-reminders` | `lib/features/vault/**` | `test/vault/**` | UI, contracts, native OCR, manifest, pubspec, CI |
| Dev 4 — App/UI/Release | `feat/d4-ui-integration` | `lib/app/**`, `lib/features/screens/**`, `lib/main.dart`, `lib/core/contracts/**`, `pubspec.yaml`, `pubspec.lock`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/**/MainActivity.kt` channel registration, Gradle/shared Android configs, `.github/**`, `.gitignore`, `README.md`, `docs/TEST_REPORT.md`, `docs/LICENSES.md` | `test/screens/**` | Others' feature implementations unless fixing merge integration with owner approval |

**Shared Dart imports must point only to committed `lib/core/contracts/**` types/interfaces.** Agents may add private DTOs inside their own folders but must map to frozen contracts at public boundaries. If a contract change is needed, raise a brief change request to Dev 4; Dev 4 updates main and all branches pull/rebase accordingly.

### Dependency request protocol

An agent needing a package, manifest permission, native build tweak or DTO change sends:

```text
INTEGRATION REQUEST
Requester: D<n>
Shared file: <pubspec.yaml | AndroidManifest.xml | contracts | Gradle>
Exact change: <package+constraint or manifest declaration or function signature>
Why: <user-visible feature that requires it>
Minimum safe implementation: <snippet or one-line change>
Urgency: P0/P1
```

Dev 4 alone applies the change to common files, commits and pushes it; the requester rebases onto the new main once Dev 4's PR has merged.

## D. Independent task packets (AI agent execution scopes)

### Developer 1 — Camera, native on-device OCR & model assets

**Goal:** From a real local image path, return genuine OCR text on Android without network access.

**Owned tasks (ordered):**

- D1.1: Add `CaptureService` camera/gallery using `image_picker`; handle cancellation, Android lost data at startup, persisted copy after verify, and file validation/EXIF orientation.
- D1.2: Bundle `eng.traineddata` from `tessdata_fast`; record exact source URL, license, sha256 in model manifest.
- D1.3: Kotlin `LifeVaultOcrChannel` implementing Flutter platform channel `lifevault/ocr`; copy asset to app-private `tessdata` on first use; init OCR in worker/background thread; cleanup native API after use. Provide a registration snippet for Dev 4 to put into Dev 4-owned `MainActivity.kt`; do not edit `MainActivity.kt` yourself.
- D1.4: Return `OcrOutput` per contract; gracefully handle decoder/model/init/OOM errors; never call external services.
- D1.5: Run a real, redacted photograph on a 6 GB phone. Log **time only** (not OCR text), record sample type/result privately.
- D1.6: Unit/native tests, `flutter analyze` for owned code; commit/push PR.

**Definition of done:** D4 can invoke `OfflineOcrService.recognizeImage(path)` to get genuine OCR output from a local photo in airplane mode; a bad photo yields a clear error not an app crash.

**No dependency on D2/D3:** return `OcrOutput` and nothing else. D1 does not classify, save to SQLite or build the Scan screen.

**P0 cutoff:** by hour 1 OCR loads real image; by hour 2 integration-ready.

### Developer 2 — Broad categories + narrow date extraction

**Goal:** Stateless pure-Dart text -> suggested category/type/date candidates.

**Owned tasks (ordered):**

- D2.1: Define category keyword dictionaries for the frozen ten categories: medical, finance, appliances, vehicles, insurance, home/utilities, identity/personal, education, legal/letters, other. Do NOT redefine enums.
- D2.2: Type suggestions (insurance policy, warranty, bill, invoice/receipt, medical, etc.), with keyword evidence; 'other' fallback and low-confidence flags.
- D2.3: Labeled date extraction: expiry/valid until/policy end, warranty end and bill due; parse supported date formats, reject impossible dates and ambiguous day/month.
- D2.4: Return multiple candidates where evidence conflicts; preserve snippet and candidate kind; user has final say. Never substitute issue/purchase date as expiration.
- D2.5: Add optional derived warranty end proposal only where purchase date and warranty duration are unambiguous; explicit derived flag; user confirmation remains mandatory.
- D2.6: Create 20+ synthetic unit text fixtures for true/false positives, category overlap, missing/ambiguous dates; `flutter test`.
- D2.7: Commit/push PR with test report and sample `ExtractionResult` JSON description for integration.

**Definition of done:** `extract(String)` works without Android, OCR, DB, internet or UI; tests cover every category and the three supported deadline domains.

**No dependency on D1/D3:** use local synthetic OCR-like text test fixtures, not D1's actual OCR implementation.

**P0 cutoff:** by hour 2 tested extractor; by hour 3 integrate with D1 output.

### Developer 3 — SQLite, document vault, grounded Q&A, local notifications

**Goal:** Implement all reliable persisted business state and actions independently of UI/OCR.

**Owned tasks (ordered):**

- D3.1: Database initialization/migration `001`, indices, foreign keys, `DocumentRecord`, `DeadlineRecord`, evidence mapping to frozen contracts.
- D3.2: Save operation copies verified image to app-private path, writes SQLite metadata/links, SHA-256 duplicate lookup, handles rollback/partial errors; search/filter by category/type/title/asset.
- D3.3: List upcoming/overdue and unverified; edit verified deadline and recalculate reminder schedule; delete record/file with notification cancellation.
- D3.4: Grounded question parser `expiry`, `due`, `find`, `upcoming`; exact verified DB result with document and snippet; status for no match, several matches, unverified, unsupported.
- D3.5: Local notification scheduler using `flutter_local_notifications` with Android 13+ permission and inexact timing; neutral notification content; cancellation/rescheduling by record ID.
- D3.6: Repository unit tests using temp DB/files, clock injection for deterministic date tests and a notification service stub (test-only).
- D3.7: Prepare a concise manifest/settings request for D4 (e.g., notification permission, receivers as required by **selected** plugin version), but do not edit shared manifest.
- D3.8: Commit/push PR; report physical notification test result or limitations.

**Definition of done:** With a manually provided `VerifiedDocumentInput`, records are stored, retrieved, asked about and scheduled locally; no OCR or UI needed to test.

**No dependency on D1/D2:** use constructor-level test inputs conforming to frozen contracts; never import OCR implementation.

**P0 cutoff:** DB by hour 2, Q&A and notification hooks by hour 3.

### Developer 4 — App shell, UI, integration, quality and APK

**Goal:** Produce the actual installable, working offline LifeVault application.

**Owned tasks (ordered):**

- D4.1: Bootstrap repo (Section B), freeze enums/contracts and toolchain; add compatible dependencies and CI. Publish baseline before branches start.
- D4.2: Build UI views using service interfaces, not fake permanent data: Home with deadline cards; Scan camera/gallery + spinner/error; Review with photo and editable candidates; Vault categories/search/document detail; Ask input/answers and source image navigation.
- D4.3: Add state management with a lightweight approach already available in Flutter (e.g., `ChangeNotifier`); do not introduce unnecessary frameworks in five hours.
- D4.4: At integration stage bind real D1 OCR, D2 extractor and D3 repository/QA to screens; no hardcoded demo results.
- D4.5: Solely apply shared package/manifest/dependency integration requests, register D1 OCR channel in `MainActivity.kt`, and handle notification setup/build settings; ensure no INTERNET permission, backups excluded and IDs safe.
- D4.6: Review/merge green PRs with approvals; test integrated app and user errors. Run full `flutter analyze`, `flutter test` and physical device demonstration.
- D4.7: Build appropriate APK, tag version, upload GitHub release artifact **without user content**, write `TEST_REPORT` and README install/use instructions.

**Definition of done:** Entire P0 path works on real 6 GB Android in airplane mode, APK is available, provenance preserved, and no unverified deadlines silently trigger notifications.

**Coordination load:** D4 owns integration; D1-D3 must keep interfaces small and return actionable errors.

## E. Timeline with branch/PR checkpoints

| Time | Dev 1 | Dev 2 | Dev 3 | Dev 4 | PR/merge event |
|---|---|---|---|---|---|
| 0:00–0:20 | Device/OCR dependency verification | Classifier test-case outline | Schema + notification compatibility check | Bootstrap + frozen contracts + tools/CI | Bootstrap on main (approved) |
| 0:20–1:00 | Real OCR spike on phone | Pure date/category parser | SQLite repository skeleton | Home/Scan/Review shell | Each branch has first commit pushed |
| 1:00–2:00 | OCR completed/tested | All categories + three date intents tested | Save/query/notification APIs | Vault/Ask + handling states | First PRs open; CI running |
| 2:00–3:00 | Fix OCR edge cases, handoff | Hand off extractor evidence format | Complete Q&A/reminder tests | Wire modules for first E2E | Merge stable D1/D2/D3 via checked PRs |
| 3:00–3:30 | Support integration defects | Support extraction defects | Support DB/notification defects | E2E error handling | Freeze new features at 3:30 |
| 3:30–4:15 | OCR/device troubleshooting | Date correctness regression | Persistence/reminder regression | Finalize manifest and UI | Last mandatory merges + checks |
| 4:15–5:00 | Physical OCR test | Validate ambiguous cases | Offline notification testing | Package/measure/privacy/release | Version tag and tested APK |

**Merge sequencing rule:** Integrator should merge the first passing stable feature PR as soon as it is reviewed; update integration branch between merges. Since folders don't overlap, D1/D2/D3 can merge in whichever order becomes ready. **Do not merge half-working code just to satisfy a schedule.**

## F. Agent Git lifecycle — automatic source control, protected main

**Prerequisites:** `git`, authenticated `gh` GitHub CLI or equivalent authorized connector with write permission, correct repo remote. If `gh` unavailable, install or authenticate during bootstrap; never paste personal access tokens into files/chat or commit credentials. If automated access is denied, agents must stop and report missing permission rather than claim a push.

### First checkout (each agent in its OWN clone/worktree)

```bash
git fetch origin --prune
git switch main
git pull --ff-only origin main
# Replace with YOUR assigned name; must be unique and not already used by another agent.
git switch -c feat/d1-capture-ocr
# Develop only assigned paths.
```

### Small automated commits and push (each agent)

```bash
git status --short
git diff --check
# Run your owned tests and analyze before committing.
# Explicitly stage only files under OWNED paths, not `git add -A` blindly.
git add lib/features/capture_ocr/ test/capture_ocr/ docs/MODEL_MANIFEST.md assets/tessdata/
# Dev 1 example: also stage ONLY the owned native OCR Kotlin file after inspecting.
git diff --cached --stat
git diff --cached --check
git commit -m "feat(ocr): recognize local images with bundled tesseract"
git push -u origin feat/d1-capture-ocr
```

**Before any push, agent must inspect the staged diff for secrets/PII, private images and accidental binary files.** The only expected bundled binary model asset is the approved licensed OCR traineddata. A failed secret scan must block the push.

### Create/update PR (same agent)

```bash
gh pr create --base main --head feat/d1-capture-ocr \
  --title "feat(ocr): offline camera and tesseract" \
  --body "Owned scope: capture/OCR. Tests: <real commands/results>. Privacy: no network or user samples. Integration: uses frozen OfflineOcrService."
# If PR already exists, use `gh pr view`, `gh pr edit`, then simply push further commits.
gh pr checks
```

PR body MUST include: scope/files changed; endpoint/contracts used; tests with results; device test if applicable; privacy implications; known limitations; integration requests. Never fabricate test output.

### Rebase/update if main changed (only on your OWN branch)

```bash
git fetch origin
git rebase origin/main
# Resolve only changes within files you OWN. For cross-owned conflicts, STOP and notify D4.
# Then run tests again.
git push origin HEAD
```

**Do not force push.** If rebasing a previously pushed feature branch causes a non-fast-forward push rejection, prefer `git merge origin/main` into that feature branch (regular merge commit) and push, rather than force pushing. Alternatively Dev 4 can use GitHub's PR update branch functionality. Do not rewrite publicly reviewed commits. If branch protection requires strict up-to-date checks, update and rerun them before merge.

### Cross-review + merge done by Dev 4's agent

```bash
gh pr list --state open
# Inspect PR diff and requested checks; human teammates provide needed independent approval.
gh pr checks <PR_NUMBER>
gh pr view <PR_NUMBER> --json mergeable,reviewDecision,statusCheckRollup
# When reviews and checks are passed, no conflict and no freeze:
gh pr merge <PR_NUMBER> --squash --delete-branch
# If repo auto-merge is configured and review/check requirements are in progress:
# gh pr merge <PR_NUMBER> --auto --squash --delete-branch
```

**Agent merge authorization:** Dev 4's agent should execute routine merges after the configured safeguards report satisfied. It **must not** issue self-approvals, spoof review, turn off checks, use `--admin`, or merge merely because the agent thinks a PR is safe. Human reviewers can approve quickly; the actual click/merge operation is automated.

### After a merge

```bash
git fetch origin --prune
git switch main
git pull --ff-only origin main
flutter analyze
flutter test
```

Dev 4 resumes integration from latest main. Agents with open PRs update their own branches only when necessary. To avoid conflicts, don't all edit `README.md` / `pubspec.yaml` / `AndroidManifest.xml` simultaneously.

### Recommended GitHub settings

- Protect `main`; PR required, one different-author reviewer approval, required status checks, conversation resolution, disallow force-push/deletion.
- Repository permissions: team members get write, agents act through each member's authorized credential context; least-privilege tokens, no secrets in artifacts.
- Prefer squash merge for 4 clear feature PRs; do not use queue unless repo already has one (it adds setup).
- Single uniquely named CI check for `Flutter checks` to avoid ambiguous required status names.
- If a merge is blocked by required approvals or branch settings, leave PR open and report exact condition. No silent bypass. Initial bootstrap exception only if protected rules not yet applied and owner explicitly authorized it.

## G. Scope freeze, blockers, collision handling

- **Ownership collision:** stop editing, restore cross-owned unstaged modifications (after preserving any legitimate work), and request a patch by the proper owner. Never run `git reset --hard` on someone else's worktree.
- **Contract change:** submit integration request. Dev 4 makes one change on main; agents update their branches, re-run tests, and adapt within their own folders.
- **Package conflict:** only Dev 4 edits `pubspec.yaml`/lockfile. Do not run `flutter pub add` if it modifies shared files outside your ownership; request package through coordinator.
- **Android manifest conflict:** Dev 1 owns OCR Kotlin only; Dev 3 owns notification Dart only; Dev 4 applies Android manifest/Gradle patches.
- **Time risk:** if camera is flaky, provide gallery import; if OCR fails, allow manual entry while fixing OCR (OCR live success still required to claim P0); if notification permission is denied, display clear unsupported status and use dashboard; if Qwen can't load, do not include it.
- **Hard scope freeze:** no optional Qwen/PDF/multilingual packages after hour 3; after 3:30 only fixes/tests/builds.
- **Privacy block:** if any telemetry, INTERNET permission or external OCR request is found, quarantine build and fix before calling it offline.

## H. Integration acceptance checklist

Dev 4 marks each item **PASS/FAIL, not assumptions** in `docs/TEST_REPORT.md`:

- [ ] Base contracts committed and imported by all modules.
- [ ] Capture/gallery on actual Android hardware; image remains local.
- [ ] Bundled English Tesseract OCR returns genuine text offline.
- [ ] Medical / Finance / Appliances / Vehicles / Insurance / Home / Identity / Education / Legal / Other categories visible and editable.
- [ ] Type is independent of category; unsupported document types still store/search.
- [ ] Insurance/warranty/bill date proposals have source snippets; invalid/ambiguous dates aren't auto-approved.
- [ ] Confirmed record persisted in SQLite and app-private file storage.
- [ ] Upcoming/overdue dashboard accurate on device date; delete/edit reschedule safe.
- [ ] Ask returns verified data and opens its document, or explicitly says missing/ambiguous.
- [ ] Local reminder tested with permission granted; denial state tested.
- [ ] No network permission in merged manifest, no cloud fallback/telemetry SDK.
- [ ] Backups excluded and security limits documented.
- [ ] Tests pass; APK installs on target phone in airplane mode.
- [ ] GitHub PRs merged with required reviews/checks and no force pushes.
- [ ] Repo and APK contain no private household files or actual identifiers.
- [ ] APK checksum, release-mode build and signing-key type, compatible Android/RAM and known limits recorded.

## I. Ready-to-paste coding-agent instructions

Each person provides the SAME master plan and THIS task split to their AI agent and follows with exactly ONE role-specific instruction below. Don't launch four agents with the generic instruction "build all of LifeVault".

### Agent D1 prompt

> You are LifeVault Developer 1. Read both Markdown plans fully. Work solely on branch `feat/d1-capture-ocr` in your own clone/worktree and only in Dev 1 owned files. Implement real offline Android image capture/gallery and Tesseract4Android OCR with bundled `eng.traineddata`, returning the frozen `OfflineOcrService` contract. Do not edit contracts, UI, pubspec, shared manifest, Gradle root or DB. Verify on-device without internet; if dependency or manifest changes are required, send Dev 4 an integration request. Run scoped tests, inspect staged files for sensitive content, auto-commit, auto-push, open PR, check CI. Never bypass review or branch protection. Report the PR URL and actual test results.

### Agent D2 prompt

> You are LifeVault Developer 2. Read both Markdown plans fully. Work solely on branch `feat/d2-classify-extract` in your own clone/worktree and only in Dev 2 owned files. Implement pure-Dart category and document-type classification for all locked categories and cautious evidence-backed date candidate extraction specialized for insurance, warranties and bill due dates. Use the committed contracts. Never silently invent or verify deadlines; do not require OCR/Android/DB to run tests. Add rigorous synthetic text unit tests. Auto-commit, auto-push, open PR and report actual tests/PR URL. No shared-file edits or protection bypass.

### Agent D3 prompt

> You are LifeVault Developer 3. Read both Markdown plans fully. Work solely on branch `feat/d3-vault-reminders` in your own clone/worktree and only in Dev 3 owned files. Implement SQLite/local-file repository, duplicate detection, verified deadlines, safe delete/edit, deterministic grounded question answering, and scheduled Android local notifications. Use frozen contracts; tests use synthetic `VerifiedDocumentInput` and temp DB (not real household content). For pubspec/manifest changes, send Dev 4 an integration request and do not modify shared files. Auto-commit, auto-push, create PR and report actual tests. Respect protected-main reviews and no force push.

### Agent D4 prompt

> You are LifeVault Developer 4, integration lead and release owner. Read both Markdown plans fully. During the first 20 minutes bootstrap the repo, freeze DTOs/interfaces, set toolchain-compatible dependencies, CI, ownership and branch protection, and push the baseline before feature branches start. Work in Dev 4 owned files for screens, navigation, manifest/privacy setup and runtime service composition. Integrate **real** modules from D1-D3 and own final APK + test report. For each PR verify tests/permissions/changes, secure an independent review, then perform the merge yourself with GitHub CLI after safeguards pass. Never change others' feature code without coordination, never self-approve, never force push, never add INTERNET permission or remote services, and never include private documents in commits or APK. Freeze extras by 3:30 and finish a tested offline Lite APK.

## J. End-of-hackathon handover checklist

1. Dev 4 publishes APK with honest build type and SHA-256; if using GitHub Releases, upload the **release-mode** binary and release notes only, **no documents**. Inspect the built release merged manifest, because Flutter debug builds may add development-only INTERNET permission; release APK must not contain it.
2. Merge/tag final stable state: `v0.1-hackathon`; archive test output and build instructions in repo.
3. Each agent reports exactly: branch/PR, owned files changed, commands run + pass/fail, runtime/device test, blockers, known limitations and whether PR was merged.
4. Keep any experimental Qwen, PDF or language features in separate future branches; do not silently include unstable code in Lite.
5. User-visible security statement: **no LifeVault server, no app network communication, on-device storage and inference; encrypted vault and secure backup are not yet implemented**.

---

### External references for repo automation and platform behavior

- GitHub CLI `gh pr create`: https://cli.github.com/manual/gh_pr_create
- GitHub CLI `gh pr merge`: https://cli.github.com/manual/gh_pr_merge
- Branch protection/reviews/checks: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches
- Flutter native channels: https://docs.flutter.dev/platform-integration/platform-channels
- Tesseract4Android integration: https://github.com/adaptech-cz/Tesseract4Android/blob/master/README.md
- image_picker lost-data handling: https://pub.dev/packages/image_picker
- Local notification permissions/scheduling: https://pub.dev/packages/flutter_local_notifications
