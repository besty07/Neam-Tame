# LifeVault v0.1 — Model Manifest

**Owner:** Developer 1 (Capture & OCR)
**Date:** 2026-10-24
**Project:** LifeVault v0.1 (Offline Personal Document & Deadline Vault)

---

## 1. Primary Bundled OCR Engine & Weights

| Attribute | Specification |
|:---|:---|
| **Engine / Wrapper** | Tesseract4Android (`cz.adaptech.tesseract4android:tesseract4android:4.7.0`) |
| **Core OCR Engine** | Tesseract 5.3.x (compiled via NDK with Leptonica 1.83+) |
| **Model Weight File** | `eng.traineddata` (Tesseract fast English integer model) |
| **Source Repository** | [tesseract-ocr/tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast) |
| **Direct Download URL** | `https://github.com/tesseract-ocr/tessdata_fast/raw/main/eng.traineddata` |
| **License** | Apache License 2.0 |
| **Packaging Status** | **Packaged in APK** under `assets/tessdata/eng.traineddata` |
| **Packaged Size** | 4,113,088 bytes (~4.11 MB) |
| **SHA-256 Checksum** | `7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2` |
| **Device Storage Path** | `<app_private_files_dir>/tessdata/eng.traineddata` |

---

## 2. Model Initialization & Verification Flow

1. **Asset Copy on First Launch**:
   - `LifeVaultOcrChannel` checks if `<filesDir>/tessdata/eng.traineddata` exists.
   - If missing or file length does not match 4,113,088 bytes, it copies the bundled asset from Flutter `AssetManager` directly to app-private internal storage.
2. **Zero Network Requirement**:
   - Model is fully bundled inside the APK. No external HTTP/HTTPS download or network access is ever attempted.
   - Operates in complete airplane mode.
3. **Execution Safety**:
   - `TessBaseAPI` initialization takes place in a background worker thread (`Dispatchers.IO`).
   - Bitmaps are scaled toward max dimension ~2000–2400 px to prevent Out-Of-Memory (OOM) errors.
   - Native handles are recycled (`tessBaseApi.recycle()`) after execution to prevent native memory leaks.

---

## 3. Structured Error Codes

If OCR cannot proceed, the native channel returns a structured error code:
* `MODEL_MISSING`: Traineddata file missing or corrupted in app storage.
* `DECODE_FAILED`: Image file cannot be decoded into a valid bitmap or image size exceeds memory limits.
* `OCR_FAILED`: Native Tesseract initialization or recognition failed unexpectedly.

---

## 4. Excluded Models (P2 Hackathon Scope)

* **Generative LLMs (e.g. Qwen3-0.6B / llama.cpp)**: Excluded from LifeVault Lite v0.1 APK per Section 2 of Master Implementation Plan.
* **Cloud OCR SDKs**: Google Cloud Vision, Firebase ML Kit, or AWS Textract are strictly prohibited and not bundled.
