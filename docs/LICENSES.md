# Open-Source & Model Licenses & Attribution (`LifeVault`)

LifeVault uses open-source libraries and model artifacts under the following terms:

1. **Flutter & Dart SDK Packages** (`flutter`, `path`, `crypto`, `intl`, `flutter_test`, `flutter_lints`)
   - License: BSD-3-Clause
   - Source: https://github.com/flutter/flutter

2. **Tesseract OCR & `tessdata_fast` (`eng.traineddata`)**
   - License: Apache License 2.0
   - Source: https://github.com/tesseract-ocr/tessdata_fast
   - Details & SHA-256 recorded by Developer 1 in `docs/MODEL_MANIFEST.md`.

3. **Tesseract4Android (`cz.adaptech.tesseract4android:tesseract4android`)**
   - License: Apache License 2.0
   - Source: https://github.com/adaptech-cz/Tesseract4Android

4. **`sqflite` & `sqflite_common_ffi`**
   - License: BSD-2-Clause
   - Source: https://github.com/tekartik/sqflite

5. **`image_picker` & `path_provider`**
   - License: BSD-3-Clause
   - Source: https://github.com/flutter/packages

6. **`flutter_local_notifications` & `timezone`**
   - License: BSD-3-Clause / BSD-2-Clause
   - Source: https://github.com/MaikuB/flutter_local_notifications

7. **`uuid`**
   - License: MIT
   - Source: https://github.com/Daegalus/dart-uuid

8. **Gemma 3n E4B IT / E2B IT (Optional User-Provisioned On-Device Vision Model)**
   - **License:** **Gemma Terms of Use** (**NOT** Apache 2.0).
   - **Terms & Redistribution:** Open weights governed by the Google Gemma Terms of Use (https://ai.google.dev/gemma/terms). Model weights (`.litertlm` / `.task`, ~4,235 MB for E4B) are **not** bundled in the repository or base APK; users may import a legitimately obtained local `.litertlm` / `.task` artifact on-device after accepting the Gemma Terms of Use.
