# LifeVault — Gemma 3n E4B Vision Migration & Feasibility Gate

Status: **Proposed change, contingent on real-device tests**  
Target: Android, Flutter, 6 GB RAM test phone, no LifeVault network/server connections  
Affected existing specification: `QWEN_INTEGRATION_PLAN.md` (v0.2-experimental)

## 1. What changes, and why

The current Tesseract OCR output is not meeting quality expectations. Test **Gemma 3n E4B IT** as an on-device *multimodal document-field extractor*, consuming a photographed document **as an image** plus a tightly scoped instruction. Gemma is **not a guaranteed character-accurate OCR replacement**. OCR-like transcription and structured recognition must be evaluated separately, particularly for identifiers and dates.

The supplied Qwen plan currently uses `Tesseract → Conservative Extraction → User Confirmation → SQLite → Qwen Action Guide`; the Qwen model is for post-verification action playbooks, **not for OCR**. Keep this separation during migration.

### New proposed data path

`Camera/Image → Image preprocessing → Gemma 3n E4B IT (image + prompt) → Candidate JSON parser → Validation → User reviews source image → Verified SQLite record → Dashboard/Reminder/Questions → deterministic action guide (optional Gemma wording later)`

Never let any model-proposed field create a deadline or reminder before user confirmation. The original image must remain available for visual comparison.

## 2. Model, runtime, licensing, and hardware

- **Model:** `Gemma 3n E4B IT` (*instruction-tuned, vision-capable*); do not mistakenly select text-only versions or Gemma 3 1B.
- **Model openness:** open weights under the **Gemma Terms of Use**, **NOT Apache 2.0**. Review license acceptance and redistribution obligations before bundling or distributing model files. See https://ai.google.dev/gemma/terms.
- **Runtime:** prefer the official **LiteRT-LM Kotlin Android API** and a Flutter MethodChannel; alternatively evaluate `flutter_gemma` if the exact downloaded model format, version, and vision support are verified. Do **not** add a second `llama.cpp` runtime merely for this model.
- **Model artifact:** exact runtime-specific `.litertlm` / compatible `.task` bundle; check format against runtime before downloading/copying. An AI Edge Gallery installation is not a shared system AI endpoint, and another app cannot assume it can access the Gallery's private model data.
- **Size & memory:** Google LiteRT-LM lists Gemma 3n E4B at ~4,235 MB for a benchmarked model artifact. Other official model variants differ in size. Google describes architectural memory reduction, but **6 GB physical RAM does not imply enough free memory**. Test actual app memory while processing images. Do not trust the older Qwen plan's `total RAM <500 MB` claim as a measured figure.
- **Fallback candidates:** Gemma 3n E2B vision if E4B is unstable; retain existing OCR/manual-entry path if neither passes. Manual entry must always work.
- **Distribution:** for hackathon feasibility, consider user-driven local model import from a legitimately obtained artifact instead of forcing a multi-gigabyte APK. Document that offline *first launch with AI* requires the model to already be provisioned. Final app must never download models or send document data to a server.

References: https://developers.google.com/edge/litert-lm/android ; https://developers.google.com/edge/litert-lm/overview ; https://github.com/google-ai-edge/gallery ; https://pub.dev/packages/flutter_gemma.

## 3. Mandatory pre-integration test: AI Edge Gallery

1. Open AI Edge Gallery → **Ask Image** or an equivalent image-capable screen. Select **Gemma 3n E4B IT** (verify model name, not just another model in Gallery).
2. Enable airplane mode and verify image inference still works.
3. Test at least ten **synthetic or redacted** document images: insurance, bills, appliance receipts/warranty cards, medical document. Include poor light, angled text, confusing multiple dates, and one with no expiration date.
4. Use the image-field extraction prompt below. Ask for exact field values, not narrative summaries.
5. Manually compare every proposed date, amount, ID and evidence quote to the original image. Time runs and record errors, skipped fields, guesses, crashes, and temperature.
6. Check Gallery's performance stats when available; their speed is not a guarantee for LifeVault because integrated app memory use differs.

**Gate to proceed:** On the target phone, image mode runs offline without crashes; clear documents generally return the correct *labeled* key date; unknown fields remain null; apparent document IDs/dates are not invented; performance is acceptable for an explicit 'Analyze' action. For high-stakes dates, **user review remains mandatory even when this gate passes**.

### Extraction prompt (image + text)

```text
You are an offline document-field extraction assistant. Inspect the ATTACHED DOCUMENT IMAGE, not a text-only description. Return ONLY valid JSON matching this schema. Do not guess or invent text, policy numbers, dates, amounts, or evidence. If unreadable, absent, or ambiguous, use null and state the ambiguity in warnings. Preserve exact transcription for date and identifier fields; do not reinterpret a date's role without a nearby label. Do not infer insurance coverage, legal validity, or medical advice.

{
  "category": "Medical|Finance|Appliances|Vehicles|Insurance|Home & Utilities|Identity & Personal|Education|Legal & Letters|Other|null",
  "document_type": "string|null",
  "title": "string|null",
  "asset_name": "string|null",
  "date_candidates": [
    {"label": "string", "raw_date": "string", "iso_date": "YYYY-MM-DD|null", "evidence_quote": "string|null"}
  ],
  "amount": "string|null",
  "reference_number": "string|null",
  "warnings": ["string"]
}

A model-generated evidence_quote is only a candidate and MUST be visually verified against the image by the user before it is trusted.
```

## 4. Code boundaries and integration contracts

Keep existing Flutter screens and database schema stable where possible.

```dart
abstract class DocumentExtractionService {
  Future<ExtractionDraft> extractImage(String localImagePath);
}

class ExtractionDraft {
  final String? category;
  final String? documentType;
  final String? title;
  final List<DateCandidate> dates;
  final List<String> warnings;
  final String sourceImagePath;
  // All fields explicitly UNVERIFIED until user saves Review screen.
}
```

`GemmaVisionExtractionService` must be optional and implement this contract; keep an `OcrExtractionService`/manual-entry fallback. Parse JSON defensively: reject malformed output, normalize dates, preserve raw text, reject invented categories, and report uncertainty. Do not use LLM self-rated confidence as proof. Associate each image with its page number when extracting from multipage documents.

### Runtime integration outline

- Android/Kotlin: load authorized model from user-selected local path copied to LifeVault app-private storage; initialize LiteRT-LM **off the UI thread**; send image input + extraction prompt; close or unload engine when appropriate.
- Flutter: show `Model missing`, `Loading model`, `Analyzing`, `Needs review`, `Model unavailable` states; no UI hangs; model-size/free-space check before import; display warnings.
- Do **not** attempt to invoke AI Edge Gallery as a general system service or read another app's private files.
- Process **one document/page at a time**; don't run Qwen and Gemma simultaneously on a 6 GB device.
- Use a bounded image resolution; keep original source unchanged and available for review.

## 5. Reconcile QWEN_INTEGRATION_PLAN.md

1. The attached plan concerns **action playbooks**, not document OCR. Do not overwrite it to pretend Qwen can read image inputs.
2. First, integrate vision extraction separately. Keep the deterministic fallback action guides.
3. **Defer Qwen** while benchmarking E4B; running two runtimes/models creates unnecessary RAM, disk, and integration burden.
4. If Gemma is successfully integrated, optionally reuse its text generation for playbook wording **after verification**, but never allow generated legal, financial, insurance, or medical claims to override document facts or verified rules.
5. The original plan calls the model `Qwen2.5-0.5B` yet labels paths and flow as `qwen-0.6b`: fix the version/name inconsistency before using artifacts.
6. Treat its 3.5-second LLM timeout and `<500 MB total RAM` statement as unvalidated assumptions; do not make them acceptance criteria for E4B.

## 6. Branch ownership / team of four

- **D1 (`feat/d1-capture-ocr`):** Own image capture/preprocessing and old OCR fallback. Integrate vision extractor only through agreed interfaces; own Kotlin model bridge **if the team assigns it explicitly**.
- **D2 (`feat/d2-classify-extract`):** Own output schema, JSON parsing, date normalization, category mapping, null/ambiguity handling, and unit tests. Publish stable Dart interfaces early.
- **D3 (`feat/d3-vault-reminders`):** Own verified persistence, reminders, answers and deterministic action playbooks. Do not bundle Qwen until device gate passes.
- **D4 (`feat/d4-ui-integration`):** Own Review screen, model status/progress, usability, integrated APK build, physical-device QA and privacy tests.

### Git rules

- Each developer/agent commits and pushes **only** its own feature branch; never push directly to `main`.
- Each agent raises a PR and includes automated tests, real-device evidence (where needed), memory observations and a concise summary.
- Do not edit another developer's owned files without coordination or a dedicated integration PR; agree interfaces before parallel changes.
- Do not commit any model binary, medical/insurance paper, user scan, logs containing sensitive content, Android signing key or real personal data.
- D4 merges PRs sequentially **after checks and agreed human approval**; rebase/merge latest `main` into feature branch before integration, resolve conflicts deliberately. Never force-push `main`.

## 7. Hard acceptance criteria

- Demonstrate airplane-mode model inference with a photographed document on the actual target phone.
- Verify no LifeVault `INTERNET` permission and no analytics/network fallback in the built APK.
- The workflow can still save a document and enter a deadline manually if E4B fails, is missing, or the phone runs out of memory.
- No model-proposed date can create a verified deadline or notification without user confirmation.
- All categories remain browsable; only supported types have automatic high-confidence candidate extraction for MVP.
- The existing vault, reminders and structured answers continue working after migration.
- Test app relaunch, low storage, bad input, incorrect model format and model unload under memory pressure.

## 8. Decision checkpoint

**Do not replace the existing OCR system wholesale yet.** First compare E4B vs the existing OCR on the same redacted images in Gallery. If E4B is stable and materially more accurate on key dates, proceed with integration. If not, investigate E2B or a dedicated open-source OCR alternative and keep manual entry.
