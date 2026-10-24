# Qwen 0.6B On-Device Action Guide Integration Plan

**Target Model:** `Qwen2.5-0.5B-Instruct` (Quantized `Q4_K_M` GGUF, ~380 MB)  
**Primary Goal:** Transform static deadline notifications into actionable, grounded renewal and task playbooks, running 100% offline on-device without cloud dependencies.  
**Version:** v0.2-experimental  

---

## 1. System Architecture

The Qwen action generation engine runs directly on the device using an embedded native `llama.cpp` runtime. It connects to the existing LifeVault pipeline as an enhancement layer after document verification:

```
[Camera / Gallery]
        │
        ▼
[Offline OCR (Tesseract)]
        │
        ▼
[Conservative Extraction]
        │
        ▼
[User Review & Confirmation] ──▶ [SQLite Vault Storage]
                                          │
                                          ▼
                         [Qwen Action Guide Engine]
                         ┌────────────────┴────────────────┐
                         ▼                                 ▼
             [Primary: Qwen-0.6B LLM]          [Fallback: Local Playbook]
             (Custom, contextual steps)         (Instant, guaranteed safe)
                         │                                 │
                         └────────────────┬────────────────┘
                                          ▼
                               [ActionPlaybook Model]
                                          │
                        ┌─────────────────┴─────────────────┐
                        ▼                                   ▼
             [Document Detail View]              [Notification Tap Intent]
             (Checklist + Copy ID)               (Direct action deep-link)
```

---

## 2. Technical Prerequisites & Artifact Placement

### A. Model Assets
1. **File:** `qwen2.5-0.5b-instruct-q4_k_m.gguf` (~380 MB)
2. **Directory:** `assets/models/qwen-0.6b.gguf`
3. **Git Rule:** Model weights are ignored by `.gitignore` to prevent repository bloat:
   ```gitignore
   assets/models/*.gguf
   assets/models/*.bin
   ```
4. **Device Staging:**
   - On release builds: Streamed from APK assets into internal storage (`/data/user/0/com.lifevault.app/app_flutter/models/`).
   - On debug builds / rapid iteration: Pushed directly via ADB:
     ```bash
     adb push qwen-0.6b.gguf /sdcard/Download/qwen-0.6b.gguf
     ```

### B. Native Inference Runtime
- **Engine:** `llama.cpp` compiled for Android `arm64-v8a` with ARM NEON SIMD optimizations.
- **Package:** `llama_cpp_dart` or custom Kotlin JNI Channel (`LifeVaultLlmChannel.kt`).
- **Memory Footprint:**
  - Weights: ~380 MB
  - Context Window (1024 tokens): ~90 MB
  - Total RAM: < 500 MB (Safe for standard 6 GB Android phones).

---

## 3. Data Models (`lib/core/contracts/models.dart`)

```dart
/// A discrete actionable task for the user before a deadline.
class ActionStep {
  const ActionStep({
    required this.id,
    required this.title,
    required this.description,
    this.copyableText,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final String description;
  final String? copyableText;
  final bool isCompleted;
}

/// Complete actionable playbook for a verified document.
class ActionPlaybook {
  const ActionPlaybook({
    required this.documentId,
    required this.summary,
    required this.steps,
    required this.source,
  });

  final String documentId;
  final String summary;
  final List<ActionStep> steps;
  final PlaybookSource source; // qwen | deterministicFallback
}

enum PlaybookSource { qwen, deterministicFallback }
```

---

## 4. Prompt Engineering & Grounding Safeguards

To prevent hallucination of dates and ensure legal/insurance accuracy, the prompt is strictly constrained:

### System Prompt:
```text
You are LifeVault Offline Action Assistant.
Given a verified document and deadline, provide 3 to 4 actionable, practical steps the user must take before this deadline.
Rules:
1. Be concise, realistic, and bulleted.
2. Never invent, extrapolate, or alter any dates.
3. Suggest practical real-world steps (e.g. checking NCB, keeping RC ready, checking meter numbers).
4. Do not include markdown headers or greetings.
```

### Prompt Input Template:
```text
Document: {title}
Category: {category}
Asset: {assetName}
Due Date: {dueDateIso}
Evidence Snippet: {evidenceSnippet}
```

---

## 5. Implementation Phases

### Phase 1: Engine Abstraction & Safe Fallback
1. Define `ActionGuideService` interface in `lib/core/contracts/services.dart`.
2. Implement `DeterministicActionGuideService` containing proven offline playbooks:
   - **Insurance**: Vehicle inspection warning, NCB retention, required renewal documents.
   - **Utilities**: Consumer ID copy, grace period vs. disconnection cutoff.
   - **Appliances/Warranty**: Paper invoice requirement, serial number verification.
   - **Medical**: Prescription validity, doctor follow-up scheduling.

### Phase 2: Qwen Model Bridge
1. Add `assets/models/` path to `pubspec.yaml`.
2. Integrate native inference binding (`llama_cpp_dart` or Android JNI `LifeVaultLlmChannel`).
3. Implement `QwenActionGuideService` with low temperature (`0.2`) and top-p (`0.9`).
4. Wrap in `HybridActionGuideService`: attempts Qwen with a 3.5s timeout; falls back instantly to the deterministic playbook if Qwen is uninitialized or slow.

### Phase 3: UI Integration (`DocumentDetailScreen`)
1. Create `ActionPlaybookCard` widget in `lib/features/screens/widgets/action_playbook_card.dart`.
2. Add interactive checkboxes so users can check off completed preparation tasks.
3. Add one-tap "Copy" button for identifiers (Policy number, meter ID, chassis number).

### Phase 4: Local Notification Deep Link
1. Update `ReminderServiceImpl` notification payload to encode `{ 'documentId': docId, 'action': 'open_playbook' }`.
2. Update `AppShellScreen` to handle notification payload and open the Action Playbook directly upon notification tap.

### Phase 5: Verification & Quality Assurance
1. **RAM Audit**: Profile memory in Android Studio Profiler (confirm app stays below 1.2 GB peak RAM during generation).
2. **Airplane Mode Validation**: Run with Wi-Fi and mobile data disabled; verify 100% offline generation.
3. **Automated Unit Tests**: Add unit tests for `ActionGuideService`, playbook parsing, and fallback triggers.
