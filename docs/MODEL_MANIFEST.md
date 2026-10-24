# LifeVault — Model & AI/OCR Artifact Manifest

**Date:** 2026-10-24  
**Project:** LifeVault (Offline Personal Document & Deadline Vault)  
**Companion License Reference:** [`docs/LICENSES.md`](LICENSES.md) & [`NOTICE`](../NOTICE)

---

## 1. Summary of Models & Runtimes in LifeVault

LifeVault is architected to operate **100% offline on-device** with zero network permissions (`android.permission.INTERNET` removed from the merged release manifest). It supports the following four model families across its OCR, structured document extraction, and action-playbook pipelines:

| # | Model Artifact | Purpose in LifeVault | License / Terms | Packaged in Git / Base APK? | Native Channel / Service |
|---|---|---|---|---|---|
| 1 | **Tesseract `eng.traineddata` (`tessdata_fast`)** | Bundled offline English OCR engine | **Apache License 2.0** | **Yes** (`assets/tessdata/eng.traineddata`) | `MethodChannel("lifevault/ocr")` (`LifeVaultOcrChannel.kt`) |
| 2 | **Google ML Kit Text Recognition v2 (Latin)** | High-accuracy on-device Latin script & layout block OCR | **MIT** (Dart plugin) / **ML Kit Terms** (Android SDK) | **Yes** (Linked via Gradle; runs 100% offline) | `OfflineOcrServiceImpl` & `LifeVaultGemmaChannel.kt` |
| 3 | **Google Gemma 3n (`E4B IT` / `E2B IT`)** | Optional multimodal document-field extractor (`.litertlm` / `.task`) | **Google Gemma Terms of Use** (*NOT Apache 2.0*) | **No** (User-provisioned locally on-device) | `MethodChannel("lifevault/gemma_vision")` (`LifeVaultGemmaChannel.kt`) |
| 4 | **Qwen2.5-0.5B-Instruct / Qwen3-0.6B (`qwen-0.6b.gguf`) & Gemma 2 (`gemma-2b-it.gguf`)** | Optional post-verification offline Action Playbook generator (`.gguf`) | **Apache License 2.0** (Qwen) / **Gemma Terms of Use** (Gemma) | **No** (Excluded via `.gitignore`; staged locally on-device) | `MethodChannel("lifevault/llm")` (`LifeVaultLlmChannel.kt`) |

---

## 2. Primary Bundled OCR Engine & Weights (`eng.traineddata`)

| Attribute | Specification |
|:---|:---|
| **Engine / Wrapper** | Tesseract4Android (`cz.adaptech.tesseract4android:tesseract4android:4.7.0`) |
| **Core OCR Engine** | Tesseract 5.3.x (compiled via NDK with Leptonica 1.83+) |
| **Model Weight File** | `eng.traineddata` (Tesseract fast English integer LSTM model) |
| **Source Repository** | [tesseract-ocr/tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast) |
| **Direct Download URL** | `https://github.com/tesseract-ocr/tessdata_fast/raw/main/eng.traineddata` |
| **License** | Apache License 2.0 |
| **Packaging Status** | **Packaged in Git & APK** under `assets/tessdata/eng.traineddata` |
| **Packaged Size** | `4,113,088 bytes` (~4.11 MB) |
| **SHA-256 Checksum** | `7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2` |
| **Device Storage Path** | `<app_private_files_dir>/tessdata/eng.traineddata` |

### Initialization & Verification Flow
1. **Asset Copy & SHA-256 Integrity Check on First Launch**:
   - `LifeVaultOcrChannel` checks if `<filesDir>/tessdata/eng.traineddata` exists with size `4,113,088 bytes` and SHA-256 `7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2`.
   - If missing or mismatched, it copies the bundled asset from Flutter `AssetManager` into a temporary file, verifies its SHA-256 digest, and atomically renames it into app-private storage.
2. **Execution Safety**:
   - `TessBaseAPI` initialization and recognition run strictly on `Dispatchers.IO`.
   - Bitmaps are downsampled toward max dimension `2400 px` with EXIF rotation correction to prevent Out-Of-Memory (OOM) errors, and native handles (`tessBaseApi.recycle()`, `bitmap.recycle()`) are freed in `finally` blocks.

---

## 3. On-Device Google ML Kit Text Recognition (`google_mlkit_text_recognition`)

| Attribute | Specification |
|:---|:---|
| **Flutter Package** | `google_mlkit_text_recognition: ^0.17.1` (`google_mlkit_commons: ^0.13.0`) |
| **Native Android SDK** | `com.google.mlkit:text-recognition` (`TextRecognizerOptions.DEFAULT_OPTIONS`) |
| **Script / Model** | Latin script on-device recognition model |
| **License** | MIT License (`flutter-ml` wrapper) / Google ML Kit Terms of Service |
| **Network Requirement** | **Zero** — runs 100% offline in airplane mode |
| **Integration Points** | `OfflineOcrServiceImpl` (`lib/features/capture_ocr/offline_ocr_service_impl.dart`) and layout block extraction inside `LifeVaultGemmaChannel.kt` |

---

## 4. Optional On-Device Multimodal Extractor: Google Gemma 3n (`E4B IT` / `E2B IT`)

| Attribute | Specification |
|:---|:---|
| **Target Model** | `Gemma 3n E4B IT` (fallback: `Gemma 3n E2B IT`), instruction-tuned vision-capable |
| **Supported Formats** | `.litertlm` / `.task` (`gemma-3n-E4B-it-int4.litertlm` or `.task`, ~4,235 MB for E4B) |
| **Runtime Bridge** | `LifeVaultGemmaChannel.kt` (`MethodChannel("lifevault/gemma_vision")`) invoking MediaPipe Tasks GenAI / LiteRT-LM (`com.google.mediapipe.tasks.genai.llminference.LlmInference`) with on-device vision candidate fallback |
| **License** | **Google Gemma Terms of Use** (`https://ai.google.dev/gemma/terms`) — **NOT Apache 2.0** |
| **Prohibited Use Policy** | `https://ai.google.dev/gemma/prohibited_use_policy` |
| **Required Notice** | `Gemma is provided under and subject to the Gemma Terms of Use found at ai.google.dev/gemma/terms` (included in root [`NOTICE`](../NOTICE)) |
| **Packaging Status** | **Not bundled in Git or base APK** (`.gitignore` excludes `*.litertlm`, `*.task`) |
| **Device Provisioning Paths** | `<filesDir>/gemma_models/`, `<externalFilesDir>/gemma_models/`, or `/sdcard/Download/` (imported via Settings UI with 128 MB disk headroom and >=600 MB free RAM checks) |
| **Safety & Verification Rule** | Every extracted field and `evidence_quote` is marked `UNVERIFIED` until explicitly confirmed by the user on the Review screen. When Gemma is active, Qwen is automatically paused so two LLMs never run concurrently on a 6 GB RAM device. |

---

## 5. Optional On-Device Action Guide LLMs: Qwen2.5-0.5B / Qwen3-0.6B & Gemma 2 GGUF

| Attribute | Specification |
|:---|:---|
| **Target Models** | `Qwen2.5-0.5B-Instruct` (`Q4_K_M` GGUF, ~380 MB) / `Qwen3-0.6B` (`qwen-0.6b.gguf`, `qwen-0.5b.gguf`) or `Gemma 2 2B IT` (`gemma-2b-it.gguf`, `gemma-2-2b-it.gguf`) |
| **Source Repositories** | [QwenLM/Qwen2.5](https://github.com/QwenLM/Qwen2.5) / [Qwen/Qwen2.5-0.5B-Instruct-GGUF](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF) / [ai.google.dev/gemma](https://ai.google.dev/gemma) |
| **Licenses** | **Apache License 2.0** (Qwen models) / **Google Gemma Terms of Use** (Gemma models) |
| **Runtime Architecture** | `LifeVaultLlmChannel.kt` (`MethodChannel("lifevault/llm")`) validating GGUF magic header (`0x47475546`) with `HybridActionGuideService` and `DeterministicActionGuideService` fallback |
| **Packaging Status** | **Not bundled in Git** (`assets/models/*.gguf` and `assets/models/*.bin` excluded in `.gitignore`) |
| **Device Provisioning Paths** | `<filesDir>/models/`, `<dataDir>/app_flutter/models/`, or `/sdcard/Download/` |
| **Safety & Grounding Rule** | Invoked **only after** user verification of a document record to generate practical renewal/preparation checklists; never alters or invents dates. |

---

## 6. Structured Error & Fallback Codes

- **OCR Channel (`lifevault/ocr`)**:
  - `MODEL_MISSING`: `eng.traineddata` missing or failed SHA-256 verification.
  - `DECODE_FAILED`: Image file unreadable, missing, or exceeded bitmap memory limits.
  - `OCR_FAILED`: Native OCR initialization or recognition failed; UI allows manual entry fallback.
- **Gemma Vision Channel (`lifevault/gemma_vision`)**:
  - `model_missing`: No `.litertlm` or `.task` file provisioned; automatically falls back to offline OCR + manual review.
  - `model_unavailable`: Insufficient free RAM (`<600 MB`), low storage, or unsupported extension; unloads model and falls back cleanly.
- **Action Guide LLM Channel (`lifevault/llm`)**:
  - `MODEL_NOT_STAGED`: No valid `.gguf` file staged on-device; `HybridActionGuideService` returns `DeterministicActionGuideService` playbook immediately.
