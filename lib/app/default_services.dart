import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../core/contracts/contracts.dart';
import '../features/capture_ocr/capture_ocr.dart';
import '../features/vault/vault.dart';

/// Picked image metadata returned by [ImageCaptureDelegate].
class PickedImageFile {
  const PickedImageFile({
    required this.path,
    required this.byteLength,
    required this.sha256,
  });

  final String path;
  final int byteLength;
  final String sha256;
}

/// Abstraction over `image_picker` / `CaptureService` so `ScanScreen` works on
/// real Android hardware and remains deterministically testable in widget tests.
abstract interface class ImageCaptureDelegate {
  Future<PickedImageFile?> pickFromCamera();

  Future<PickedImageFile?> pickFromGallery();

  Future<PickedImageFile?> retrieveLostImage();
}

/// Production [ImageCaptureDelegate] backed by Developer 1's [CaptureService].
class CaptureServiceImageDelegate implements ImageCaptureDelegate {
  CaptureServiceImageDelegate({CaptureService? captureService})
      : _captureService = captureService ?? CaptureService();

  final CaptureService _captureService;

  @override
  Future<PickedImageFile?> pickFromCamera() async {
    if (kIsWeb) {
      return DeviceImageCaptureDelegate().pickFromCamera();
    }
    final result = await _captureService.captureFromCamera();
    if (result == null) {
      return null;
    }
    return PickedImageFile(
      path: result.filePath,
      byteLength: result.fileSizeBytes,
      sha256: result.sha256Hash,
    );
  }

  @override
  Future<PickedImageFile?> pickFromGallery() async {
    if (kIsWeb) {
      return DeviceImageCaptureDelegate().pickFromGallery();
    }
    final result = await _captureService.pickFromGallery();
    if (result == null) {
      return null;
    }
    return PickedImageFile(
      path: result.filePath,
      byteLength: result.fileSizeBytes,
      sha256: result.sha256Hash,
    );
  }

  @override
  Future<PickedImageFile?> retrieveLostImage() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }
    final result = await _captureService.retrieveLostData();
    if (result == null) {
      return null;
    }
    return PickedImageFile(
      path: result.filePath,
      byteLength: result.fileSizeBytes,
      sha256: result.sha256Hash,
    );
  }
}

/// Direct `image_picker` [ImageCaptureDelegate] retained for compatibility.
class DeviceImageCaptureDelegate implements ImageCaptureDelegate {
  DeviceImageCaptureDelegate({ImagePicker? picker}) {
    _picker = picker ?? ImagePicker();
  }

  late final ImagePicker _picker;

  @override
  Future<PickedImageFile?> pickFromCamera() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
    );
    return _toPickedImage(xFile);
  }

  @override
  Future<PickedImageFile?> pickFromGallery() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
    );
    return _toPickedImage(xFile);
  }

  @override
  Future<PickedImageFile?> retrieveLostImage() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) {
        return null;
      }
      return await _toPickedImage(response.file);
    } on Object {
      return null;
    }
  }

  Future<PickedImageFile?> _toPickedImage(XFile? xFile) async {
    if (xFile == null) {
      return null;
    }
    final bytes = await xFile.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    return PickedImageFile(
      path: xFile.path,
      byteLength: bytes.length,
      sha256: digest,
    );
  }
}

/// Platform-channel [OfflineOcrService] calling `lifevault/ocr` (Section 7.1).
class MethodChannelOfflineOcrService implements OfflineOcrService {
  const MethodChannelOfflineOcrService({
    this.channel = const MethodChannel('lifevault/ocr'),
  });

  final MethodChannel channel;

  @override
  Future<OcrOutput> recognizeImage(
    String localImagePath, {
    String language = 'eng',
  }) async {
    try {
      final response = await channel.invokeMapMethod<String, Object?>(
        'recognizeImage',
        <String, Object?>{'path': localImagePath, 'language': language},
      );
      if (response == null) {
        return const OcrOutput(
          text: '',
          errorCode: 'OCR_FAILED',
          errorMessage: 'Empty response from native OCR channel.',
        );
      }
      return OcrOutput(
        text: (response['text'] as String?) ?? '',
        language: (response['language'] as String?) ?? language,
        page: (response['page'] as int?) ?? 1,
        confidence: (response['confidence'] as num?)?.toDouble(),
        processingMs: response['processingMs'] as int?,
        errorCode: response['errorCode'] as String?,
        errorMessage: response['errorMessage'] as String?,
      );
    } on MissingPluginException {
      return const OcrOutput(
        text: '',
        errorCode: 'MODEL_MISSING',
        errorMessage: 'Offline OCR engine is not registered yet. '
            'You can still enter document details manually.',
      );
    } on PlatformException catch (error) {
      final code = error.code.isEmpty ? 'OCR_FAILED' : error.code;
      return OcrOutput(
        text: '',
        errorCode: code,
        errorMessage: error.message ?? 'Native OCR failed to process image.',
      );
    }
  }
}

/// Production [QuestionService] adapter delegating to Developer 3's
/// [QuestionServiceImpl] and normalizing suggested chip queries such as
/// `"fridge warranty"`.
class IntegratedQuestionService implements QuestionService {
  const IntegratedQuestionService(this._delegate);

  final QuestionServiceImpl _delegate;

  @override
  Future<AnswerResult> answer(String question) async {
    final primary = await _delegate.answer(question);
    if (primary.status != AnswerStatus.unsupportedQuestion) {
      return primary;
    }
    final normalized = question.trim().toLowerCase();
    if (normalized.contains('warranty') || normalized.contains('policy')) {
      return _delegate.answer('$question expiry');
    }
    if (normalized.contains('bill')) {
      return _delegate.answer('$question due');
    }
    return primary;
  }
}

/// Baseline fallback [DocumentExtractionService] for isolated tests.
class FallbackDocumentExtractionService implements DocumentExtractionService {
  const FallbackDocumentExtractionService();

  @override
  ExtractionResult extract(String ocrText) {
    return const ExtractionResult();
  }
}

/// Production adapter wrapping D3's [VaultRepositoryImpl] to seamlessly handle:
/// 1. Manual-entry documents without an image file (synthesizes a 1x1 local PNG)
/// 2. Editing/updating an existing document in-place without triggering a
///    self-duplicate SHA-256 exception or losing the private image file.
class ProductionVaultRepositoryAdapter implements VaultRepository {
  ProductionVaultRepositoryAdapter(this._inner);

  final VaultRepositoryImpl _inner;

  // Minimal valid 1x1 transparent PNG for manual-entry records without a photo.
  static final List<int> _placeholderPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  Future<DocumentRecord> saveVerified(VerifiedDocumentInput input) async {
    File? synthesizedTempFile;
    try {
      String effectiveSourcePath = input.originalTempPath;
      final sourceFile = File(effectiveSourcePath);

      if (!sourceFile.existsSync()) {
        final tempDir = Directory.systemTemp;
        final manualFile = File(
          p.join(
            tempDir.path,
            'lifevault_manual_${DateTime.now().microsecondsSinceEpoch}.png',
          ),
        );
        await manualFile.writeAsBytes(_placeholderPngBytes, flush: true);
        synthesizedTempFile = manualFile;
        effectiveSourcePath = manualFile.path;
      }

      // Check if a document with the same SHA-256 already exists (e.g. when
      // re-saving/editing an existing record).
      if (input.sha256 != null && input.sha256!.isNotEmpty) {
        final existing = await _inner.findDocumentBySha256(input.sha256!);
        if (existing != null &&
            existing.originalPath == input.originalTempPath) {
          final tempCopy = File(
            p.join(
              Directory.systemTemp.path,
              'lifevault_edit_${DateTime.now().microsecondsSinceEpoch}${p.extension(existing.originalPath)}',
            ),
          );
          await File(existing.originalPath).copy(tempCopy.path);
          synthesizedTempFile = tempCopy;
          effectiveSourcePath = tempCopy.path;
          await _inner.deleteDocument(existing.id);
        }
      }

      final normalizedInput = VerifiedDocumentInput(
        originalTempPath: effectiveSourcePath,
        title: input.title,
        category: input.category,
        documentType: input.documentType,
        assetName: input.assetName,
        tags: input.tags,
        sha256: input.sha256,
        ocrStatus: input.ocrStatus,
        verificationStatus: input.verificationStatus,
        verifiedDeadlines: input.verifiedDeadlines,
        evidenceRecords: input.evidenceRecords,
      );

      return await _inner.saveVerified(normalizedInput);
    } on DuplicateDocumentException {
      // If user explicitly chose to save another copy of a duplicate photo,
      // salt the hash suffix so D3's repository stores the second copy safely.
      final saltedInput = VerifiedDocumentInput(
        originalTempPath: input.originalTempPath,
        title: input.title,
        category: input.category,
        documentType: input.documentType,
        assetName: input.assetName,
        tags: input.tags,
        sha256:
            '${input.sha256 ?? 'dup'}_copy_${DateTime.now().millisecondsSinceEpoch}',
        ocrStatus: input.ocrStatus,
        verificationStatus: input.verificationStatus,
        verifiedDeadlines: input.verifiedDeadlines,
        evidenceRecords: input.evidenceRecords,
      );
      return await _inner.saveVerified(saltedInput);
    } finally {
      if (synthesizedTempFile != null && synthesizedTempFile.existsSync()) {
        try {
          synthesizedTempFile.deleteSync();
        } on Object {
          // Ignore temp cleanup failure.
        }
      }
    }
  }

  @override
  Future<List<DocumentRecord>> search({
    String? text,
    DocumentCategory? category,
  }) {
    return _inner.search(text: text, category: category);
  }

  @override
  Future<List<DeadlineRecord>> getDeadlines({bool verifiedOnly = true}) {
    return _inner.getDeadlines(verifiedOnly: verifiedOnly);
  }

  @override
  Future<void> deleteDocument(String documentId) {
    return _inner.deleteDocument(documentId);
  }
}

/// In-memory [VaultRepository] used when persistent SQLite service is not
/// explicitly injected (e.g., isolated widget tests).
class InMemoryVaultRepository implements VaultRepository {
  InMemoryVaultRepository({
    List<DocumentRecord>? initialDocuments,
    List<DeadlineRecord>? initialDeadlines,
  }) {
    if (initialDocuments != null) {
      _documents.addAll(initialDocuments);
    }
    if (initialDeadlines != null) {
      _deadlines.addAll(initialDeadlines);
    }
  }

  final List<DocumentRecord> _documents = <DocumentRecord>[];
  final List<DeadlineRecord> _deadlines = <DeadlineRecord>[];
  int _idCounter = 1;

  @override
  Future<DocumentRecord> saveVerified(VerifiedDocumentInput input) async {
    final now = DateTime.now();
    final existingIndex = _documents.indexWhere(
      (doc) => doc.originalPath == input.originalTempPath,
    );
    String docId;
    DateTime createdAt;
    if (existingIndex >= 0) {
      docId = _documents[existingIndex].id;
      createdAt = _documents[existingIndex].createdAt;
    } else {
      docId = 'doc_${_idCounter++}';
      createdAt = now;
    }

    String? normalizedAsset;
    final trimmedAsset = input.assetName?.trim() ?? '';
    if (trimmedAsset.isNotEmpty) {
      normalizedAsset = trimmedAsset;
    }

    final record = DocumentRecord(
      id: docId,
      title: input.title.trim(),
      category: input.category,
      documentType: input.documentType,
      assetName: normalizedAsset,
      tags: input.tags,
      originalPath: input.originalTempPath,
      sha256: input.sha256 ?? 'sha256_$docId',
      ocrStatus: input.ocrStatus,
      verificationStatus: input.verificationStatus,
      createdAt: createdAt,
      updatedAt: now,
    );

    if (existingIndex >= 0) {
      _documents[existingIndex] = record;
      _deadlines.removeWhere((d) => d.documentId == docId);
    } else {
      _documents.add(record);
    }

    for (final deadlineInput in input.verifiedDeadlines) {
      _deadlines.add(
        DeadlineRecord(
          id: 'dl_${_idCounter++}',
          documentId: docId,
          kind: deadlineInput.kind,
          dateIso: deadlineInput.dateIso,
          evidenceSnippet: deadlineInput.evidenceSnippet,
          page: deadlineInput.page,
          isVerified: true,
          reminderOffsetsDays: deadlineInput.reminderOffsetsDays,
          updatedAt: now,
        ),
      );
    }

    return record;
  }

  @override
  Future<List<DocumentRecord>> search({
    String? text,
    DocumentCategory? category,
  }) async {
    final normalizedQuery = text?.trim().toLowerCase() ?? '';
    return _documents.where((doc) {
      if (category != null && doc.category != category) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final haystack = <String>[
        doc.title,
        doc.category.displayName,
        doc.category.wireName,
        doc.documentType.displayName,
        doc.documentType.wireName,
        if (doc.assetName != null) doc.assetName!,
        ...doc.tags,
      ].join(' ').toLowerCase();
      return haystack.contains(normalizedQuery);
    }).toList();
  }

  @override
  Future<List<DeadlineRecord>> getDeadlines({bool verifiedOnly = true}) async {
    final filtered = _deadlines.where((d) {
      return !verifiedOnly || d.isVerified;
    }).toList();
    filtered.sort((a, b) => a.dateIso.compareTo(b.dateIso));
    return filtered;
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    _documents.removeWhere((doc) => doc.id == documentId);
    _deadlines.removeWhere((d) => d.documentId == documentId);
  }
}

/// Deterministic [QuestionService] backed by [VaultRepository] verified data.
class GroundedVaultQuestionService implements QuestionService {
  const GroundedVaultQuestionService(this._repository);

  final VaultRepository _repository;

  @override
  Future<AnswerResult> answer(String question) async {
    final normalized = question.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const AnswerResult(
        status: AnswerStatus.unsupportedQuestion,
        text: 'Enter a question about an expiry date, bill due date, '
            'or saved household document.',
      );
    }

    final isUpcomingQuery = normalized.contains('upcoming') ||
        normalized.contains('due soon') ||
        normalized.contains('next deadline') ||
        normalized.contains('deadlines');
    final isExpiryQuery = normalized.contains('expir') ||
        normalized.contains('warranty') ||
        normalized.contains('valid') ||
        normalized.contains('policy');
    final isDueQuery = normalized.contains('due') ||
        normalized.contains('bill') ||
        normalized.contains('pay');
    final isFindQuery = normalized.contains('find') ||
        normalized.contains('where') ||
        normalized.contains('show') ||
        normalized.contains('latest') ||
        normalized.contains('do i have');

    if (!isUpcomingQuery && !isExpiryQuery && !isDueQuery && !isFindQuery) {
      return const AnswerResult(
        status: AnswerStatus.unsupportedQuestion,
        text: 'LifeVault only answers grounded questions about expiry dates, '
            'bill due dates, upcoming deadlines, or finding saved documents.',
      );
    }

    final allDocs = await _repository.search();
    final verifiedDeadlines = await _repository.getDeadlines(
      verifiedOnly: true,
    );

    if (isUpcomingQuery) {
      if (verifiedDeadlines.isEmpty) {
        return const AnswerResult(
          status: AnswerStatus.notFound,
          text: 'No verified upcoming deadlines found in your vault.',
        );
      }
      final first = verifiedDeadlines.first;
      final doc = allDocs.where((d) => d.id == first.documentId).firstOrNull;
      final docTitle = doc?.title ?? 'Document';
      final upcomingDocIds =
          verifiedDeadlines.map((d) => d.documentId).toSet().toList();
      return AnswerResult(
        status: AnswerStatus.answered,
        text: '$docTitle (${first.kind.displayName}) is due on '
            '${first.dateIso}.',
        documentIds: upcomingDocIds,
        deadlineIds: verifiedDeadlines.map((d) => d.id).toList(),
        evidenceSnippet: first.evidenceSnippet,
        sourcePage: first.page,
      );
    }

    final stopWords = <String>{
      'when',
      'does',
      'my',
      'the',
      'is',
      'what',
      'expire',
      'expires',
      'expiry',
      'due',
      'date',
      'bill',
      'warranty',
      'insurance',
      'policy',
      'find',
      'where',
      'show',
      'latest',
      'still',
      'under',
      'for',
      'of',
      'on',
    };
    final tokens = normalized
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2 && !stopWords.contains(t))
        .toList();

    final matchingDocs = allDocs.where((doc) {
      if (tokens.isEmpty) {
        if (isExpiryQuery) {
          return doc.category == DocumentCategory.insurance ||
              doc.documentType == DocumentType.insurancePolicy ||
              doc.documentType == DocumentType.warranty;
        }
        if (isDueQuery) {
          return doc.documentType == DocumentType.bill;
        }
        return false;
      }
      final searchable = <String>[
        doc.title,
        doc.category.displayName,
        doc.category.wireName,
        doc.documentType.displayName,
        doc.documentType.wireName,
        if (doc.assetName != null) doc.assetName!,
        ...doc.tags,
      ].join(' ').toLowerCase();
      return tokens.any(searchable.contains);
    }).toList();

    if (matchingDocs.isEmpty) {
      return const AnswerResult(
        status: AnswerStatus.notFound,
        text: 'No matching verified record found in your local vault.',
      );
    }

    if (matchingDocs.length > 1) {
      return AnswerResult(
        status: AnswerStatus.multipleMatches,
        text: 'Found ${matchingDocs.length} matching records. '
            'Select a document below to view its verified date and source.',
        documentIds: matchingDocs.map((d) => d.id).toList(),
      );
    }

    final matchedDoc = matchingDocs.single;
    if (!matchedDoc.verificationStatus.isUserVerified) {
      return AnswerResult(
        status: AnswerStatus.unverified,
        text: '"${matchedDoc.title}" is saved, but its dates have not been '
            'verified by you yet. Please review and confirm the document.',
        documentIds: <String>[matchedDoc.id],
      );
    }

    final docDeadlines =
        verifiedDeadlines.where((d) => d.documentId == matchedDoc.id).toList();

    if (isFindQuery && !isExpiryQuery && !isDueQuery) {
      String deadlineNote = 'No deadline attached.';
      String? snippet;
      int? page = 1;
      if (docDeadlines.isNotEmpty) {
        deadlineNote = 'Verified date: ${docDeadlines.first.dateIso}.';
        snippet = docDeadlines.first.evidenceSnippet;
        page = docDeadlines.first.page;
      }
      return AnswerResult(
        status: AnswerStatus.answered,
        text: 'Found "${matchedDoc.title}" under '
            '${matchedDoc.category.displayName}. $deadlineNote',
        documentIds: <String>[matchedDoc.id],
        deadlineIds: docDeadlines.map((d) => d.id).toList(),
        evidenceSnippet: snippet,
        sourcePage: page,
      );
    }

    if (docDeadlines.isEmpty) {
      return AnswerResult(
        status: AnswerStatus.unverified,
        text: '"${matchedDoc.title}" does not have a confirmed deadline date '
            'recorded.',
        documentIds: <String>[matchedDoc.id],
      );
    }

    final deadline = docDeadlines.first;
    return AnswerResult(
      status: AnswerStatus.answered,
      text: '${matchedDoc.title} (${deadline.kind.displayName}): '
          '${deadline.dateIso}.',
      documentIds: <String>[matchedDoc.id],
      deadlineIds: <String>[deadline.id],
      evidenceSnippet: deadline.evidenceSnippet,
      sourcePage: deadline.page,
    );
  }
}

/// Fallback local [ReminderService] for isolated widget tests.
class NoOpReminderService implements ReminderService {
  const NoOpReminderService();

  @override
  Future<ReminderScheduleResult> schedule(DeadlineRecord deadline) async {
    if (!deadline.isVerified) {
      return const ReminderScheduleResult(
        scheduled: false,
        permissionGranted: false,
        statusMessage: 'Unverified deadlines cannot schedule notifications.',
        errorCode: 'UNVERIFIED_DEADLINE',
      );
    }
    return const ReminderScheduleResult(
      scheduled: true,
      permissionGranted: true,
      notificationIds: <int>[1001],
      statusMessage: 'Reminder recorded on local deadline dashboard.',
    );
  }

  @override
  Future<void> cancelForDocument(String documentId) async {}
}
