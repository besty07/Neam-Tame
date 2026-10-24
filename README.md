# LifeVault v0.1 (Lite)

> **Photograph it once. Find it instantly. Never miss an important date.**

LifeVault transforms captured household documents (insurance policies, appliance warranties, utility bills, medical papers, vehicle records, and letters) into **private, organized, locally searchable records**, with **user-confirmed dates** and **local deadline reminders**.

---

## Release Artifact (`v0.1-hackathon`)

- **APK Artifact:** `LifeVault-Lite-v0.1-release-mode.apk` (attached to GitHub Release [`v0.1-hackathon`](https://github.com/besty07/Neam-Tame/releases/tag/v0.1-hackathon))
- **Size:** `84,471,067 bytes` (`80.56 MB`)
- **SHA-256:** `25c598b87e8b04690e1f545c075980dd91a859821c465e1cce9d79f50a158d98`
- **Signing Disclosure:** Built in Flutter `--release` mode and signed with the Android development/debug keystore for hackathon evaluation (`NOT a production signing identity`).
- **Verification Report:** See [`docs/TEST_REPORT.md`](docs/TEST_REPORT.md) for the full 102-test CI summary, merged manifest zero-internet audit, and 2-minute airplane-mode demo script.

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

---

## Open-Source Models, Runtimes & Software Licenses

LifeVault is licensed under the **[Apache License 2.0](LICENSE)** (see [`NOTICE`](NOTICE) for required third-party and model attributions). Full dependency tables, SHA-256 checksums, and verbatim license texts are documented in [`docs/LICENSES.md`](docs/LICENSES.md) and [`docs/MODEL_MANIFEST.md`](docs/MODEL_MANIFEST.md).

| Component / Model | Role in LifeVault | License / Terms | Distribution Status |
|---|---|---|---|
| **Tesseract `tessdata_fast` (`eng.traineddata`)** | Bundled offline English OCR model (`4,113,088 bytes`, SHA-256 `7d4322bd...170b2`) | [Apache License 2.0](https://github.com/tesseract-ocr/tessdata_fast) | Bundled in `assets/tessdata/eng.traineddata` |
| **Tesseract OCR 5.3.x & `Tesseract4Android` 4.7.0** | Native Android JNI OCR engine & Leptonica 1.83+ bridge | [Apache License 2.0](https://github.com/adaptech-cz/Tesseract4Android) / [BSD-2-Clause](http://www.leptonica.org/) | Linked via Gradle |
| **Google ML Kit Text Recognition v2 (`google_mlkit_text_recognition`)** | On-device Latin script & layout block text recognition | [MIT License](https://github.com/flutter-ml/google_ml_kit_flutter) (Flutter plugin) / [ML Kit Terms](https://developers.google.com/ml-kit/terms) | Linked via Gradle (100% offline, zero network permissions) |
| **Google Gemma 3n (`E4B IT` / `E2B IT`) & Gemma 2 (`2B IT`)** | Optional on-device multimodal document-field extractor (`.litertlm` / `.task`) & action guide (`.gguf`) | **[Google Gemma Terms of Use](https://ai.google.dev/gemma/terms)** (*NOT Apache 2.0*) | **Not bundled in Git/APK**; user-provisioned locally on-device |
| **Alibaba Qwen (`Qwen2.5-0.5B-Instruct` / `Qwen3-0.6B`)** | Optional post-verification on-device Action Playbook generator (`.gguf`) | [Apache License 2.0](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF) | **Not bundled in Git**; optional local `.gguf` staging |
| **Google AI Edge `LiteRT-LM` / `MediaPipe` & `llama.cpp`** | On-device multimodal & GGUF inference runtime bridges | [Apache License 2.0](https://github.com/google-ai-edge/litert-lm) / [MIT License](https://github.com/ggml-org/llama.cpp) | Native Kotlin platform bridges (`LifeVaultGemmaChannel`, `LifeVaultLlmChannel`) |
| **Flutter & Dart SDK, `sqflite`, `flutter_local_notifications`, `image_picker`, `path_provider`, `timezone`, `uuid`, `crypto`, `intl`** | App UI framework, local SQLite storage, local notifications, and utilities | `BSD-3-Clause` / `BSD-2-Clause` / `MIT` / `Public Domain` (SQLite) | See [`docs/LICENSES.md`](docs/LICENSES.md) |

> **Gemma Attribution Notice:** *Gemma is provided under and subject to the Gemma Terms of Use found at [ai.google.dev/gemma/terms](https://ai.google.dev/gemma/terms).*
