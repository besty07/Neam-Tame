/// On-device Gemma 3n E4B Vision extraction service, defensive candidate JSON
/// parser, OCR extraction adapter, and hybrid fallback orchestrator.
///
/// Implements `LifeVault_GEMMA3N_VISION_MIGRATION.md` Sections 1–5.
/// Zero network calls. All outputs remain UNVERIFIED until confirmed on the
/// Review screen.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/contracts/contracts.dart';

/// Exact multimodal extraction prompt defined in
/// `LifeVault_GEMMA3N_VISION_MIGRATION.md` Section 3.
const String kGemmaVisionExtractionPrompt = '''
You are an offline document field extractor for LifeVault.
Examine the image and return ONLY valid JSON matching the schema below.
Do not invent fields that are not visible in the image.
If a value is missing, illegible, or ambiguous, use null and explain in warnings.

Allowed categories:
identity, vehicle, medical, insurance, warranty, home, finance, tax, education, other

Allowed date labels:
expiry, due, purchase, issue, start, unknown

Required JSON schema:
{
  "category": "vehicle|identity|medical|insurance|warranty|home|finance|tax|education|other|null",
  "document_type": "short string or null",
  "title": "short descriptive title or null",
  "asset_name": "vehicle, person, property, policy, or appliance name if visible, else null",
  "amount": "visible amount with currency or null",
  "reference_number": "visible policy/bill/id/invoice/serial number or null",
  "date_candidates": [
    {
      "label": "expiry|due|purchase|issue|start|unknown",
      "raw_date": "exact date text visible in the image",
      "iso_date": "YYYY-MM-DD if unambiguous, else null",
      "evidence_quote": "short visible text surrounding the date",
      "ambiguous": false
    }
  ],
  "warnings": [
    "explain illegible text, multiple competing dates, or ambiguous DD/MM vs MM/DD dates"
  ]
}''';

/// Status snapshot returned by the native `lifevault/gemma_vision` channel.
class VisionModelStatus {
  const VisionModelStatus({
    required this.state,
    required this.available,
    this.modelName,
    this.modelPath,
    this.modelSizeBytes,
    this.freeDiskBytes,
    this.availableRamMb,
    this.message,
  });

  final VisionModelState state;
  final bool available;
  final String? modelName;
  final String? modelPath;
  final int? modelSizeBytes;
  final int? freeDiskBytes;
  final int? availableRamMb;
  final String? message;

  factory VisionModelStatus.fromMap(Map<Object?, Object?> map) {
    final rawState = map['state']?.toString();
    final available = map['available'] == true;
    return VisionModelStatus(
      state: VisionModelState.fromWire(rawState),
      available: available,
      modelName: map['modelName']?.toString(),
      modelPath: map['modelPath']?.toString(),
      modelSizeBytes: (map['modelSizeBytes'] as num?)?.toInt(),
      freeDiskBytes: (map['freeDiskBytes'] as num?)?.toInt(),
      availableRamMb: (map['availableRamMb'] as num?)?.toInt(),
      message: map['message']?.toString(),
    );
  }
}

/// Defensive parser for Gemma 3n E4B candidate JSON output
/// (`LifeVault_GEMMA3N_VISION_MIGRATION.md` Section 3).
///
/// Rules enforced:
/// 1. Rejects malformed JSON without crashing.
/// 2. Rejects categories outside the 10 LifeVault categories.
/// 3. Validates `iso_date` format and real calendar validity.
/// 4. Never reinterprets an `issue` or `purchase` date as an expiry/due
///    deadline without a label.
/// 5. Preserves `raw_date` and `evidence_quote` for user inspection.
/// 6. Never trusts LLM self-rated confidence as proof.
class GemmaCandidateJsonParser {
  const GemmaCandidateJsonParser._();

  static const Set<String> _allowedCategories = <String>{
    'identity',
    'vehicle',
    'medical',
    'insurance',
    'warranty',
    'home',
    'finance',
    'tax',
    'education',
    'other',
  };

  static const Set<String> _allowedDateLabels = <String>{
    'expiry',
    'due',
    'purchase',
    'issue',
    'start',
    'unknown',
  };

  static final RegExp _isoDatePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Parses raw model output into an unverified [ExtractionDraft].
  static ExtractionDraft parse(
    String rawOutput, {
    required String sourceImagePath,
    int page = 1,
  }) {
    final cleaned = _stripMarkdownFences(rawOutput);
    if (cleaned.isEmpty) {
      return ExtractionDraft(
        sourceImagePath: sourceImagePath,
        page: page,
        usedGemmaVision: true,
        warnings: const <String>[
          'Gemma 3n returned an empty response. Please review the image and enter fields manually.',
        ],
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(cleaned);
    } on FormatException {
      return ExtractionDraft(
        sourceImagePath: sourceImagePath,
        page: page,
        usedGemmaVision: true,
        warnings: const <String>[
          'Gemma 3n output was not valid JSON. Please review the image and verify fields manually.',
        ],
      );
    }

    if (decoded is! Map) {
      return ExtractionDraft(
        sourceImagePath: sourceImagePath,
        page: page,
        usedGemmaVision: true,
        warnings: const <String>[
          'Gemma 3n output root was not a JSON object. Please verify fields manually.',
        ],
      );
    }

    final warnings = <String>[];
    final rawWarnings = decoded['warnings'];
    if (rawWarnings is List) {
      for (final item in rawWarnings) {
        final text = _cleanNullableString(item);
        if (text != null) {
          warnings.add(text);
        }
      }
    }

    // 1. Validate category strictly against the 10 LifeVault categories.
    String? validatedCategory;
    final rawCategory = _cleanNullableString(decoded['category']);
    if (rawCategory != null) {
      final normalizedCategory = rawCategory.toLowerCase();
      if (_allowedCategories.contains(normalizedCategory)) {
        validatedCategory = normalizedCategory;
      } else {
        validatedCategory = DocumentCategory.other.wireName;
        warnings.add(
          'Unrecognized category "$rawCategory" proposed by model; defaulted to Other for manual review.',
        );
      }
    }

    // 2. Clean optional scalar fields.
    final rawDocType = _cleanNullableString(decoded['document_type']);
    final normalizedDocType = _normalizeDocumentTypeWire(rawDocType);
    final title = _cleanNullableString(decoded['title']);
    final assetName = _cleanNullableString(decoded['asset_name']);
    final amount = _cleanNullableString(decoded['amount']);
    final referenceNumber = _cleanNullableString(decoded['reference_number']);

    // 3. Parse and validate date candidates without promoting issue/purchase.
    final dates = <DateCandidate>[];
    final rawDates = decoded['date_candidates'];
    if (rawDates is List) {
      for (final entry in rawDates) {
        if (entry is! Map) {
          warnings.add('Ignored malformed date candidate entry.');
          continue;
        }
        final rawLabel = _cleanNullableString(entry['label'])?.toLowerCase();
        final DateFieldKind fieldKind;
        if (rawLabel == null || !_allowedDateLabels.contains(rawLabel)) {
          fieldKind = DateFieldKind.unknown;
          if (rawLabel != null) {
            warnings.add(
              'Unrecognized date label "$rawLabel" treated as unknown; verify role against document photo.',
            );
          }
        } else {
          // Strict role mapping: issue/purchase/start are NEVER promoted to
          // expiry or due.
          fieldKind = DateFieldKind.fromWire(rawLabel);
        }

        final rawDateText = _cleanNullableString(entry['raw_date']) ?? '';
        final evidenceQuote =
            _cleanNullableString(entry['evidence_quote']) ?? rawDateText;
        final reportedAmbiguous = entry['ambiguous'] == true;
        final rawIso = _cleanNullableString(entry['iso_date']);

        String? validIso;
        var isAmbiguous = reportedAmbiguous;
        if (rawIso != null) {
          if (_isValidCalendarIsoDate(rawIso)) {
            validIso = rawIso;
          } else {
            isAmbiguous = true;
            warnings.add(
              'Invalid ISO date "$rawIso" for "${rawDateText.isEmpty ? fieldKind.wireName : rawDateText}" was rejected; please confirm the date manually.',
            );
          }
        } else {
          isAmbiguous = true;
        }

        if (reportedAmbiguous) {
          validIso = null;
          if (rawDateText.isNotEmpty) {
            warnings.add(
              'Ambiguous date "$rawDateText" requires manual verification against the document image.',
            );
          }
        }

        if (rawDateText.isEmpty && validIso == null) {
          continue;
        }

        dates.add(
          DateCandidate(
            fieldKind: fieldKind,
            rawText: rawDateText.isNotEmpty ? rawDateText : (validIso ?? ''),
            isoDate: validIso,
            sourceSnippet: evidenceQuote,
            page: page,
            ambiguous: isAmbiguous,
            isDerived: false,
            // Never trust LLM self-rated confidence as proof.
            confidenceLevel: isAmbiguous || validIso == null
                ? ConfidenceLevel.low
                : ConfidenceLevel.medium,
          ),
        );
      }
    }

    return ExtractionDraft(
      sourceImagePath: sourceImagePath,
      category: validatedCategory,
      documentType: normalizedDocType ?? rawDocType,
      title: title,
      assetName: assetName,
      dates: dates,
      amount: amount,
      referenceNumber: referenceNumber,
      warnings: warnings,
      page: page,
      usedGemmaVision: true,
    );
  }

  static String _stripMarkdownFences(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline != -1) {
        text = text.substring(firstNewline + 1);
      } else {
        text = text.substring(3);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
    }
    return text.trim();
  }

  static String? _cleanNullableString(Object? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.toString().trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }
    return trimmed;
  }

  /// Maps free-form document_type strings (e.g., `pollution_certificate`)
  /// onto canonical [DocumentType] wire names when possible.
  static String? _normalizeDocumentTypeWire(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final direct = DocumentType.fromWire(raw);
    if (direct != DocumentType.other || raw.toLowerCase() == 'other') {
      return direct.wireName;
    }
    final lower = raw.toLowerCase();
    if (lower.contains('certificate') || lower.contains('puc')) {
      return DocumentType.certificate.wireName;
    }
    if (lower.contains('policy') || lower.contains('insurance')) {
      return DocumentType.insurancePolicy.wireName;
    }
    if (lower.contains('warranty') || lower.contains('guarantee')) {
      return DocumentType.warranty.wireName;
    }
    if (lower.contains('invoice') || lower.contains('receipt')) {
      return DocumentType.invoiceReceipt.wireName;
    }
    if (lower.contains('bill') || lower.contains('statement')) {
      return DocumentType.bill.wireName;
    }
    if (lower.contains('prescription') || lower.contains('rx')) {
      return DocumentType.prescription.wireName;
    }
    if (lower.contains('medical') ||
        lower.contains('lab') ||
        lower.contains('report')) {
      return DocumentType.medicalRecord.wireName;
    }
    if (lower.contains('registration') ||
        lower.contains('rc') ||
        lower.contains('license') ||
        lower.contains('passport')) {
      return DocumentType.registration.wireName;
    }
    if (lower.contains('letter') || lower.contains('notice')) {
      return DocumentType.letter.wireName;
    }
    return raw;
  }

  static bool _isValidCalendarIsoDate(String value) {
    final match = _isoDatePattern.firstMatch(value);
    if (match == null) {
      return false;
    }
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) {
      return false;
    }
    if (year < 1900 || year > 2100 || month < 1 || month > 12 || day < 1) {
      return false;
    }
    final maxDays = _daysInMonth(year, month);
    return day <= maxDays;
  }

  static int _daysInMonth(int year, int month) {
    switch (month) {
      case 1:
      case 3:
      case 5:
      case 7:
      case 8:
      case 10:
      case 12:
        return 31;
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      case 2:
        final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
        return isLeap ? 29 : 28;
      default:
        return 0;
    }
  }
}

/// Signature for injecting a custom native channel runner in unit tests.
typedef GemmaMethodRunner = Future<Map<Object?, Object?>?> Function(
  String method,
  Map<String, Object?> arguments,
);

/// Optional on-device Gemma 3n E4B IT multimodal extractor over
/// `MethodChannel('lifevault/gemma_vision')`.
class GemmaVisionExtractionService implements VisionDocumentExtractionService {
  GemmaVisionExtractionService({
    MethodChannel? channel,
    GemmaMethodRunner? methodRunner,
    this.timeout = const Duration(seconds: 25),
    this.maxDimensionPx = 1280,
  })  : _channel = channel ?? const MethodChannel(channelName),
        _methodRunner = methodRunner;

  static const String channelName = 'lifevault/gemma_vision';

  final MethodChannel _channel;
  final GemmaMethodRunner? _methodRunner;
  final Duration timeout;
  final int maxDimensionPx;

  Future<Map<Object?, Object?>?> _invoke(
    String method, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    if (_methodRunner != null) {
      return _methodRunner(method, arguments);
    }
    return _channel.invokeMapMethod<Object?, Object?>(method, arguments);
  }

  /// Queries the native runtime for model provisioning and memory status.
  Future<VisionModelStatus> getModelStatus() async {
    try {
      final response = await _invoke('getModelStatus').timeout(
        const Duration(seconds: 5),
      );
      if (response == null) {
        return const VisionModelStatus(
          state: VisionModelState.modelMissing,
          available: false,
          message:
              'Gemma 3n E4B model not imported. Using offline OCR + manual review fallback.',
        );
      }
      return VisionModelStatus.fromMap(response);
    } on MissingPluginException {
      return const VisionModelStatus(
        state: VisionModelState.modelUnavailable,
        available: false,
        message: 'Native Gemma Vision channel not registered on this platform.',
      );
    } on PlatformException catch (error) {
      return VisionModelStatus(
        state: VisionModelState.modelUnavailable,
        available: false,
        message: error.message ?? 'Gemma Vision status check failed.',
      );
    } on TimeoutException {
      return const VisionModelStatus(
        state: VisionModelState.modelUnavailable,
        available: false,
        message: 'Gemma Vision status check timed out.',
      );
    }
  }

  /// Imports a user-selected `.litertlm` or `.task` model file from local
  /// storage into LifeVault's private model directory after checking free disk
  /// space.
  Future<VisionModelStatus> importLocalModel(String sourcePath) async {
    try {
      final response = await _invoke(
        'importLocalModel',
        <String, Object?>{'sourcePath': sourcePath},
      ).timeout(const Duration(minutes: 2));
      if (response == null) {
        return const VisionModelStatus(
          state: VisionModelState.modelUnavailable,
          available: false,
          message: 'Model import returned no status.',
        );
      }
      return VisionModelStatus.fromMap(response);
    } on MissingPluginException {
      return const VisionModelStatus(
        state: VisionModelState.modelUnavailable,
        available: false,
        message: 'Model import is only supported on Android devices.',
      );
    } on PlatformException catch (error) {
      return VisionModelStatus(
        state: VisionModelState.modelUnavailable,
        available: false,
        message: error.message ?? 'Failed to import local Gemma model.',
      );
    }
  }

  /// Unloads any active Gemma 3n session to free RAM under memory pressure.
  Future<void> unloadModel() async {
    try {
      await _invoke('unloadModel').timeout(const Duration(seconds: 5));
    } catch (_) {
      // Safe no-op if already unloaded or unavailable.
    }
  }

  @override
  Future<ExtractionDraft> extractImage(
    String localImagePath, {
    int page = 1,
  }) async {
    try {
      final response = await _invoke(
        'extractDocumentFields',
        <String, Object?>{
          'imagePath': localImagePath,
          'prompt': kGemmaVisionExtractionPrompt,
          'maxDimensionPx': maxDimensionPx,
          'page': page,
        },
      ).timeout(timeout);

      if (response == null) {
        return ExtractionDraft(
          sourceImagePath: localImagePath,
          page: page,
          usedGemmaVision: false,
          warnings: const <String>[
            'Gemma 3n returned no response; falling back to OCR/manual review.',
          ],
        );
      }

      final status = response['status']?.toString() ?? 'error';
      if (status != 'ok') {
        final message = response['message']?.toString() ??
            'Gemma 3n model unavailable on this device.';
        return ExtractionDraft(
          sourceImagePath: localImagePath,
          page: page,
          usedGemmaVision: false,
          warnings: <String>[message],
        );
      }

      final rawJson = response['rawJson']?.toString() ?? '';
      return GemmaCandidateJsonParser.parse(
        rawJson,
        sourceImagePath: localImagePath,
        page: page,
      );
    } on TimeoutException {
      return ExtractionDraft(
        sourceImagePath: localImagePath,
        page: page,
        usedGemmaVision: false,
        warnings: const <String>[
          'Gemma 3n inference timed out; switched to offline OCR/manual entry.',
        ],
      );
    } on MissingPluginException {
      return ExtractionDraft(
        sourceImagePath: localImagePath,
        page: page,
        usedGemmaVision: false,
        warnings: const <String>[
          'Gemma 3n runtime not available on this platform; using offline OCR fallback.',
        ],
      );
    } on PlatformException catch (error) {
      return ExtractionDraft(
        sourceImagePath: localImagePath,
        page: page,
        usedGemmaVision: false,
        warnings: <String>[
          error.message ??
              'Gemma 3n inference failed; using offline OCR fallback.',
        ],
      );
    }
  }
}

/// Adapter that wraps the deterministic [OfflineOcrService] +
/// [DocumentExtractionService] pipeline behind
/// [VisionDocumentExtractionService].
///
/// Retained as the always-available fallback when the 4 GB Gemma 3n E4B model
/// is not provisioned or cannot run on the device.
class OcrExtractionService implements VisionDocumentExtractionService {
  OcrExtractionService({
    required OfflineOcrService ocrService,
    required DocumentExtractionService extractionService,
  })  : _ocrService = ocrService,
        _extractionService = extractionService;

  final OfflineOcrService _ocrService;
  final DocumentExtractionService _extractionService;

  OcrOutput? _lastOcrOutput;

  /// Most recent [OcrOutput] produced during [extractImage].
  OcrOutput? get lastOcrOutput => _lastOcrOutput;

  @override
  Future<ExtractionDraft> extractImage(
    String localImagePath, {
    int page = 1,
  }) async {
    OcrOutput ocrOutput;
    try {
      ocrOutput = await _ocrService.recognizeImage(localImagePath);
    } catch (error) {
      ocrOutput = OcrOutput(
        text: '',
        page: page,
        errorCode: 'OCR_EXCEPTION',
        errorMessage: error.toString(),
      );
    }
    _lastOcrOutput = ocrOutput;

    final warnings = <String>[];
    if (!ocrOutput.isSuccess) {
      warnings.add(
        ocrOutput.errorMessage ??
            'Offline OCR could not read text from this image; please enter details manually.',
      );
    } else if (ocrOutput.text.trim().isEmpty) {
      warnings.add(
        'No readable text detected in the image; please verify and enter fields manually.',
      );
    }

    final extraction = _extractionService.extract(ocrOutput.text);
    for (final candidate in extraction.dateCandidates) {
      if (candidate.ambiguous) {
        warnings.add(
          'Ambiguous date "${candidate.rawText}" detected; please confirm the exact day and month against the document image.',
        );
      }
    }

    return ExtractionDraft(
      sourceImagePath: localImagePath,
      category: extraction.suggestedCategory.wireName,
      documentType: extraction.suggestedType.wireName,
      assetName: extraction.assetNameSuggestion,
      dates: extraction.dateCandidates,
      warnings: warnings,
      page: page,
      usedGemmaVision: false,
    );
  }
}

/// Hybrid extraction orchestrator (`LifeVault_GEMMA3N_VISION_MIGRATION.md`
/// Section 4 & Section 8).
///
/// Attempts [GemmaVisionExtractionService] when a local Gemma 3n E4B model is
/// provisioned and ready; seamlessly falls back to [OcrExtractionService] when
/// the model is missing, unavailable, or fails mid-inference.
class HybridVisionExtractionService implements VisionDocumentExtractionService {
  HybridVisionExtractionService({
    required this.gemmaService,
    required this.ocrFallbackService,
  });

  final GemmaVisionExtractionService gemmaService;
  final OcrExtractionService ocrFallbackService;

  VisionModelStatus _lastModelStatus = const VisionModelStatus(
    state: VisionModelState.modelMissing,
    available: false,
  );

  VisionModelStatus get lastModelStatus => _lastModelStatus;

  OcrOutput? get lastOcrOutput => ocrFallbackService.lastOcrOutput;

  Future<VisionModelStatus> refreshModelStatus() async {
    _lastModelStatus = await gemmaService.getModelStatus();
    return _lastModelStatus;
  }

  @override
  Future<ExtractionDraft> extractImage(
    String localImagePath, {
    int page = 1,
  }) async {
    final status = await refreshModelStatus();
    if (status.available && status.state == VisionModelState.ready) {
      final gemmaDraft = await gemmaService.extractImage(
        localImagePath,
        page: page,
      );
      if (gemmaDraft.usedGemmaVision) {
        return gemmaDraft;
      }
      // Gemma runtime failed mid-inference; fall back to OCR and preserve the
      // fallback warning.
      final ocrDraft = await ocrFallbackService.extractImage(
        localImagePath,
        page: page,
      );
      return ExtractionDraft(
        sourceImagePath: ocrDraft.sourceImagePath,
        category: ocrDraft.category,
        documentType: ocrDraft.documentType,
        title: ocrDraft.title,
        assetName: ocrDraft.assetName,
        dates: ocrDraft.dates,
        amount: ocrDraft.amount,
        referenceNumber: ocrDraft.referenceNumber,
        warnings: <String>[
          ...gemmaDraft.warnings,
          ...ocrDraft.warnings,
        ],
        page: ocrDraft.page,
        usedGemmaVision: false,
      );
    }

    return ocrFallbackService.extractImage(
      localImagePath,
      page: page,
    );
  }
}
