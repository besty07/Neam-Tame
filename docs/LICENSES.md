# Open-Source Models, Runtimes & Software Licenses (`LifeVault`)

This document provides the complete license inventory, attribution notices, model redistribution disclosures, and full license texts for all open-source software, native runtimes, and open-weight AI/OCR models used in **LifeVault** ([`besty07/Neam-Tame`](https://github.com/besty07/Neam-Tame)).

- **Repository License:** [Apache License 2.0](../LICENSE)
- **Attribution Notice File:** [`NOTICE`](../NOTICE)
- **Model Weights & Checksum Manifest:** [`docs/MODEL_MANIFEST.md`](MODEL_MANIFEST.md)

---

## 1. Open-Source & Open-Weight AI, Vision & OCR Models

LifeVault uses a hybrid offline architecture combining bundled OCR weights, on-device vision/text recognition, and optional locally provisioned open-weight multimodal/language models. **All inference runs 100% offline on-device with `android.permission.INTERNET` removed from the merged release APK.**

| Model / Weight Artifact | Version / Variant | License / Terms | Bundled in Git / Base APK? | LifeVault Integration Path | Upstream Source |
|---|---|---|---|---|---|
| **Tesseract `tessdata_fast` (`eng.traineddata`)** | Fast integer LSTM English (`v4.1.0` / compatible with Tesseract 5.3.x) | **Apache License 2.0** | **Yes** (`assets/tessdata/eng.traineddata`, `4,113,088 bytes`, SHA-256: `7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2`) | `LifeVaultOcrChannel.kt` (`MethodChannel("lifevault/ocr")`) | [tesseract-ocr/tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast) |
| **Google Gemma 3n Vision** | `Gemma 3n E4B IT` / `Gemma 3n E2B IT` (`.litertlm` / `.task`, int4) | **Google Gemma Terms of Use** (*NOT Apache 2.0*) | **No** (User-provisioned locally in `<filesDir>/gemma_models/`, `<externalFilesDir>/gemma_models/`, or `/sdcard/Download/`) | `LifeVaultGemmaChannel.kt` (`MethodChannel("lifevault/gemma_vision")`), `GemmaVisionExtractionService` | [ai.google.dev/gemma](https://ai.google.dev/gemma) / [google/gemma-3n](https://huggingface.co/collections/google/gemma-3n) |
| **Google Gemma 2 (Action Guide GGUF)** | `gemma-2b-it` / `gemma-2-2b-it` (`.gguf`) | **Google Gemma Terms of Use** (*NOT Apache 2.0*) | **No** (Excluded via `.gitignore`; optional local staging in `<filesDir>/models/` or `/sdcard/Download/`) | `LifeVaultLlmChannel.kt` (`MethodChannel("lifevault/llm")`) | [ai.google.dev/gemma](https://ai.google.dev/gemma) |
| **Alibaba Qwen Action Guide LLM** | `Qwen2.5-0.5B-Instruct` (`Q4_K_M` GGUF) / `Qwen3-0.6B` (`qwen-0.6b.gguf`) | **Apache License 2.0** | **No** (Excluded via `.gitignore`; optional local staging in `<filesDir>/models/qwen-0.6b.gguf` or `/sdcard/Download/qwen-0.6b.gguf`) | `LifeVaultLlmChannel.kt` (`MethodChannel("lifevault/llm")`), `QwenActionGuideService` | [QwenLM/Qwen2.5](https://github.com/QwenLM/Qwen2.5) / [Hugging Face](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF) |
| **Google ML Kit Text Recognition v2 (Latin)** | On-Device Latin Script Recognizer (`com.google.mlkit:text-recognition` via `0.17.1`) | **MIT License** (Flutter plugin) / **Google ML Kit Terms of Service** (Native SDK & bundled model) | **Yes** (Linked via Gradle in release APK; runs strictly offline on-device) | `OfflineOcrServiceImpl` (`lib/features/capture_ocr/`) & `LifeVaultGemmaChannel.kt` | [flutter-ml/google_ml_kit_flutter](https://github.com/flutter-ml/google_ml_kit_flutter) / [ML Kit Terms](https://developers.google.com/ml-kit/terms) |

### 1.1 Google Gemma 3n & Gemma 2 — Mandatory Attribution & Licensing Disclosure

> **Gemma is provided under and subject to the Gemma Terms of Use found at [ai.google.dev/gemma/terms](https://ai.google.dev/gemma/terms)**

- **License Classification:** Google Gemma models (`Gemma 3n E4B IT`, `Gemma 3n E2B IT`, `Gemma 2 2B IT`) are open-weight models governed by the **[Gemma Terms of Use](https://ai.google.dev/gemma/terms)** and the **[Gemma Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy)**. They are **not** licensed under Apache 2.0.
- **No Raw Model Redistribution in Git:** In compliance with Section 3.1 of the Gemma Terms of Use and repository hygiene rules, LifeVault does **not** commit or redistribute `.litertlm`, `.task`, or `.gguf` weight binaries in this repository (`*.litertlm`, `*.task`, `*.gguf`, and `*.bin` are excluded via `.gitignore`).
- **Local User Provisioning & Safety Boundaries:** Users who wish to enable optional on-device Gemma 3n vision extraction import a legitimately obtained `.litertlm` or `.task` bundle from local device storage via **Settings -> Gemma 3n E4B Vision**. All model outputs are treated strictly as `UNVERIFIED` proposals requiring explicit human visual confirmation before any deadline or reminder is created.

### 1.2 Tesseract `tessdata_fast` (`eng.traineddata`) — Bundled Apache 2.0 Model

- **Copyright:** Copyright (C) 2006–2024 Google Inc. and Tesseract OCR Contributors.
- **License:** Apache License, Version 2.0.
- **Artifact Details:** Bundled at `assets/tessdata/eng.traineddata` (`4,113,088 bytes`, SHA-256 `7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2`). Verified via SHA-256 checksum on first launch by `LifeVaultOcrChannel.kt` before copying to `<filesDir>/tessdata/eng.traineddata`.

### 1.3 Qwen (`Qwen2.5-0.5B-Instruct` / `Qwen3-0.6B`) — Apache 2.0 Open-Weight LLM

- **Copyright:** Copyright (C) 2024–2025 Alibaba Cloud / Qwen Team.
- **License:** Apache License, Version 2.0 (`https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct/blob/main/LICENSE`).
- **Usage in LifeVault:** Optional post-verification action-playbook generator (`docs/QWEN_INTEGRATION_PLAN.md`, `lib/features/action_guide/qwen_action_guide_service.dart`, `LifeVaultLlmChannel.kt`). Never used for OCR or unverified date extraction; automatically falls back to `DeterministicActionGuideService` when weights are not staged on-device.

### 1.4 Google ML Kit On-Device Text Recognition v2

- **Flutter Plugin (`google_mlkit_text_recognition` v0.17.1 & `google_mlkit_commons` v0.13.0):**
  - Copyright (c) 2021 flutter-ml Contributors.
  - Licensed under the **MIT License** (`https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/LICENSE`).
- **Native Android SDK (`com.google.mlkit:text-recognition`):**
  - Copyright Google LLC. Governed by the [Google APIs Terms of Service](https://developers.google.com/terms) and [ML Kit Terms of Service](https://developers.google.com/ml-kit/terms).
  - Operates 100% on-device with zero network permissions (`android.permission.INTERNET` is explicitly stripped via `tools:node="remove"` in `android/app/src/main/AndroidManifest.xml`).

---

## 2. Native Inference Runtimes, Engines & Android Platform Libraries

| Component / Artifact | Version | SPDX License | Copyright Holder | Repository / URL |
|---|---|---|---|---|
| **Tesseract4Android** (`cz.adaptech.tesseract4android:tesseract4android`) | `4.7.0` | `Apache-2.0` | Robert Pösel / Adaptech s.r.o. | [adaptech-cz/Tesseract4Android](https://github.com/adaptech-cz/Tesseract4Android) |
| **Tesseract OCR Engine** | `5.3.x` | `Apache-2.0` | Google Inc. & Tesseract Contributors | [tesseract-ocr/tesseract](https://github.com/tesseract-ocr/tesseract) |
| **Leptonica Image Processing Library** | `1.83+` | `BSD-2-Clause` (Leptonica) | Dan Bloomberg | [DanBloomberg/leptonica](https://github.com/DanBloomberg/leptonica) |
| **libjpeg-turbo / libpng / libtiff / zlib** (via Tesseract4Android NDK) | NDK bundled | `IJG` / `BSD-3-Clause` / `Zlib` / `libtiff` | Thomas G. Lane, Glenn Randers-Pehrson, Sam Leffler, Jean-loup Gailly, Mark Adler | [adaptech-cz/Tesseract4Android](https://github.com/adaptech-cz/Tesseract4Android) |
| **Google AI Edge LiteRT-LM & MediaPipe Tasks GenAI** (`com.google.mediapipe.tasks.genai.llminference`) | Dynamic runtime bridge | `Apache-2.0` | Google LLC | [google-ai-edge/litert-lm](https://github.com/google-ai-edge/litert-lm) / [google-ai-edge/mediapipe](https://github.com/google-ai-edge/mediapipe) |
| **llama.cpp / GGML** (GGUF format & native inference architecture) | GGUF v3 | `MIT` | Georgi Gerganov & ggml authors | [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) |
| **SQLite Database Engine** | `3.x` | `Public Domain` | D. Richard Hipp & Hwaci | [sqlite.org/copyright.html](https://www.sqlite.org/copyright.html) |
| **Kotlin Standard Library & Coroutines** (`org.jetbrains.kotlinx:kotlinx-coroutines-android`) | `1.7.3` | `Apache-2.0` | JetBrains s.r.o. & Contributors | [Kotlin/kotlinx.coroutines](https://github.com/Kotlin/kotlinx.coroutines) |
| **Android Core Library Desugaring** (`com.android.tools:desugar_jdk_libs`) | `2.0.4` | `GPL-2.0-with-classpath-exception` / `Apache-2.0` | Google LLC & Oracle / OpenJDK | [google/desugar_jdk_libs](https://github.com/google/desugar_jdk_libs) |
| **AndroidX & Android Gradle Plugin** | `8.4` / API 35 | `Apache-2.0` | The Android Open Source Project | [source.android.com](https://source.android.com/) |

---

## 3. Flutter & Dart Packages (`pubspec.yaml` & `pubspec.lock`)

### 3.1 Direct Dependencies (`pubspec.yaml`)

| Package | Constraint / Locked Version | SPDX License | Copyright / Maintainer | Source Repository |
|---|---|---|---|---|
| `flutter` | SDK (`>=3.3.0 <4.0.0`) | `BSD-3-Clause` | The Flutter Authors (Google LLC) | [flutter/flutter](https://github.com/flutter/flutter) |
| `crypto` | `^3.0.5` (`3.0.7`) | `BSD-3-Clause` | The Dart Project Authors | [dart-lang/core](https://github.com/dart-lang/core/tree/main/pkgs/crypto) |
| `flutter_local_notifications` | `^17.2.2` (`17.2.4`) | `BSD-3-Clause` | Michael Bui (`MaikuB`) | [MaikuB/flutter_local_notifications](https://github.com/MaikuB/flutter_local_notifications) |
| `google_mlkit_text_recognition` | `^0.17.1` (`0.17.1`) | `MIT` | flutter-ml Contributors | [flutter-ml/google_ml_kit_flutter](https://github.com/flutter-ml/google_ml_kit_flutter) |
| `image_picker` | `^1.1.2` (`1.2.4`) | `BSD-3-Clause` | The Flutter Authors | [flutter/packages](https://github.com/flutter/packages/tree/main/packages/image_picker/image_picker) |
| `intl` | `^0.19.0` (`0.19.0`) | `BSD-3-Clause` | The Dart Project Authors | [dart-lang/i18n](https://github.com/dart-lang/i18n/tree/main/pkgs/intl) |
| `path` | `^1.9.0` (`1.9.1`) | `BSD-3-Clause` | The Dart Project Authors | [dart-lang/core](https://github.com/dart-lang/core/tree/main/pkgs/path) |
| `path_provider` | `^2.1.4` (`2.1.6`) | `BSD-3-Clause` | The Flutter Authors | [flutter/packages](https://github.com/flutter/packages/tree/main/packages/path_provider/path_provider) |
| `sqflite` | `^2.3.3+1` (`2.4.5`) | `BSD-2-Clause` | Alexandre Roux Tekartik | [tekartik/sqflite](https://github.com/tekartik/sqflite) |
| `timezone` | `^0.9.4` (`0.9.4`) | `BSD-2-Clause` | Dana Hanna & Contributors | [srawlins/timezone](https://github.com/srawlins/timezone) |
| `uuid` | `^4.4.2` (`4.6.0`) | `MIT` | Yulian Kuncheff (`Daegalus`) | [Daegalus/dart-uuid](https://github.com/Daegalus/dart-uuid) |
| `flutter_test` (dev) | SDK | `BSD-3-Clause` | The Flutter Authors | [flutter/flutter](https://github.com/flutter/flutter) |
| `flutter_lints` (dev) | `^4.0.0` (`4.0.0`) | `BSD-3-Clause` | The Flutter Authors | [flutter/packages](https://github.com/flutter/packages/tree/main/packages/flutter_lints) |
| `sqflite_common_ffi` (dev) | `^2.3.3` (`2.4.5`) | `BSD-2-Clause` | Alexandre Roux Tekartik | [tekartik/sqflite](https://github.com/tekartik/sqflite/tree/master/sqflite_common_ffi) |

### 3.2 Transitive Flutter & Dart Dependencies (`pubspec.lock`)

| Package(s) | Locked Version(s) | SPDX License | Upstream Source |
|---|---|---|---|
| `args`, `async`, `boolean_selector`, `characters`, `clock`, `code_assets`, `collection`, `fake_async`, `ffi`, `file`, `fixnum`, `glob`, `hooks`, `http`, `http_parser`, `jni`, `jni_flutter`, `jni_util`, `leak_tracker`, `leak_tracker_flutter_testing`, `leak_tracker_testing`, `lints`, `logging`, `matcher`, `material_color_utilities`, `meta`, `mime`, `native_toolchain_c`, `objective_c`, `package_config`, `platform`, `pub_semver`, `record_use`, `source_span`, `stack_trace`, `stream_channel`, `string_scanner`, `term_glyph`, `test_api`, `typed_data`, `vector_math`, `vm_service`, `web`, `xdg_directories`, `yaml` | Dart SDK / `pub.dev` pinned | `BSD-3-Clause` | [github.com/dart-lang](https://github.com/dart-lang) / [github.com/google](https://github.com/google) |
| `cross_file`, `file_selector_linux`, `file_selector_macos`, `file_selector_platform_interface`, `file_selector_windows`, `flutter_plugin_android_lifecycle`, `image_picker_android`, `image_picker_for_web`, `image_picker_ios`, `image_picker_linux`, `image_picker_macos`, `image_picker_platform_interface`, `image_picker_windows`, `path_provider_android`, `path_provider_foundation`, `path_provider_linux`, `path_provider_platform_interface`, `path_provider_windows`, `plugin_platform_interface` | Flutter Packages pinned | `BSD-3-Clause` | [github.com/flutter/packages](https://github.com/flutter/packages) |
| `flutter_local_notifications_linux` (`4.0.1`), `flutter_local_notifications_platform_interface` (`7.2.0`) | `4.0.1` / `7.2.0` | `BSD-3-Clause` | [MaikuB/flutter_local_notifications](https://github.com/MaikuB/flutter_local_notifications) |
| `google_mlkit_commons` | `0.13.0` | `MIT` | [flutter-ml/google_ml_kit_flutter](https://github.com/flutter-ml/google_ml_kit_flutter) |
| `sqflite_android` (`2.4.5`), `sqflite_common` (`2.5.14`), `sqflite_darwin` (`2.4.4+1`), `sqflite_platform_interface` (`2.4.3`), `synchronized` (`3.5.0`) | Tekartik pinned | `BSD-2-Clause` | [tekartik/sqflite](https://github.com/tekartik/sqflite) / [tekartik/synchronized.dart](https://github.com/tekartik/synchronized.dart) |
| `sqlite3` (used by `sqflite_common_ffi` in unit tests) | `3.5.2` | `MIT` | [simolus3/sqlite3.dart](https://github.com/simolus3/sqlite3.dart) |
| `petitparser` (`7.0.2`), `xml` (`7.0.1`) | `7.0.2` / `7.0.1` | `MIT` | [petitparser/dart-petitparser](https://github.com/petitparser/dart-petitparser) / [renggli/dart-xml](https://github.com/renggli/dart-xml) |
| `dbus` | `0.7.15` | `MIT` / `MPL-2.0` | [canonical/dbus.dart](https://github.com/canonical/dbus.dart) |

---

## 4. Full License Texts & Mandatory Legal Notices

### 4.1 Apache License, Version 2.0

*(Applies to LifeVault source code, Tesseract OCR Engine, `tessdata_fast` / `eng.traineddata`, `Tesseract4Android`, `Qwen2.5-0.5B-Instruct` / `Qwen3-0.6B`, Google AI Edge `LiteRT-LM` / `MediaPipe`, `kotlinx-coroutines-android`, and AndroidX components.)*

```text
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License.
```

---

### 4.2 Google Gemma Terms of Use & Prohibited Use Policy Notice

*(Applies to optional user-provisioned `Gemma 3n E4B IT`, `Gemma 3n E2B IT`, and `Gemma 2 2B IT` model artifacts.)*

```text
Gemma is provided under and subject to the Gemma Terms of Use found at
ai.google.dev/gemma/terms

Summary of Obligations under the Gemma Terms of Use (Section 3.1):
1. Any distribution or making available of a Gemma Version or Model Derivative
   must provide a copy of the Gemma Terms of Use to third-party recipients and
   include the notice above in a NOTICE file.
2. Use of Gemma models must comply with the Gemma Prohibited Use Policy
   available at: https://ai.google.dev/gemma/prohibited_use_policy
3. LifeVault does not bundle or redistribute Gemma model weights in this
   repository or base APK; users who import a local Gemma `.litertlm`, `.task`,
   or `.gguf` file on their device do so subject to the Google Gemma Terms of Use.
```

---

### 4.3 MIT License

*(Applies to `uuid`, `google_mlkit_text_recognition`, `google_mlkit_commons`, `llama.cpp` / `ggml`, `sqlite3`, `petitparser`, `xml`.)*

```text
MIT License

Copyright (c) 2012-2024 Yulian Kuncheff (package:uuid)
Copyright (c) 2021 flutter-ml Contributors (package:google_mlkit_text_recognition, package:google_mlkit_commons)
Copyright (c) 2023-2024 Georgi Gerganov and the ggml authors (llama.cpp / GGML)
Copyright (c) 2020 Simon Binder (package:sqlite3)
Copyright (c) 2006-2024 Lukas Renggli (package:petitparser, package:xml)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

### 4.4 BSD 3-Clause License

*(Applies to the Flutter SDK, Dart SDK, `crypto`, `intl`, `path`, `image_picker`, `path_provider`, `flutter_lints`, `flutter_test`, and `flutter_local_notifications`.)*

```text
Copyright 2014 The Flutter Authors. All rights reserved.
Copyright 2012 The Dart Project Authors. All rights reserved.
Copyright (c) 2018, Michael Bui. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.
    * Neither the name of Google Inc. nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

---

### 4.5 BSD 2-Clause License & Leptonica License

*(Applies to `sqflite`, `sqflite_common`, `sqflite_common_ffi`, `synchronized`, `timezone`, and Leptonica.)*

```text
Copyright (c) 2017-2024, Alexandre Roux Tekartik. All rights reserved.
Copyright (c) 2014-2024, Dana Hanna. All rights reserved.
Copyright (C) 2001-2024, Leptonica (Dan Bloomberg). All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

---

### 4.6 Public Domain Dedications (SQLite & IANA Time Zone Database)

```text
1. SQLite Database Engine (https://www.sqlite.org/copyright.html)
   All of the code and documentation in SQLite has been dedicated to the
   public domain by the authors (D. Richard Hipp and Hwaci). Anyone is free
   to copy, modify, publish, use, compile, sell, or distribute the original
   SQLite code, either in source code form or as a compiled binary, for any
   purpose, commercial or non-commercial, and by any means.

2. IANA Time Zone Database (bundled in package:timezone)
   The tz database is in the public domain (https://www.iana.org/time-zones).
```
