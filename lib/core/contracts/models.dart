/// Frozen domain DTOs for LifeVault v0.1.
///
/// Owned by Developer 4 (Integration Lead). Do not redefine in feature modules.
library;

import 'enums.dart';

/// Persisted household document metadata record (`documents` table).
class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.documentType,
    required this.originalPath,
    required this.sha256,
    required this.ocrStatus,
    required this.verificationStatus,
    required this.createdAt,
    required this.updatedAt,
    this.assetName,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final DocumentCategory category;
  final DocumentType documentType;
  final String? assetName;
  final List<String> tags;
  final String originalPath;
  final String sha256;
  final OcrStatus ocrStatus;
  final VerificationStatus verificationStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentRecord copyWith({
    String? id,
    String? title,
    DocumentCategory? category,
    DocumentType? documentType,
    String? assetName,
    List<String>? tags,
    String? originalPath,
    String? sha256,
    OcrStatus? ocrStatus,
    VerificationStatus? verificationStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      documentType: documentType ?? this.documentType,
      assetName: assetName ?? this.assetName,
      tags: tags ?? this.tags,
      originalPath: originalPath ?? this.originalPath,
      sha256: sha256 ?? this.sha256,
      ocrStatus: ocrStatus ?? this.ocrStatus,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toSqlMap() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'category': category.wireName,
      'document_type': documentType.wireName,
      'asset_name': assetName,
      'original_path': originalPath,
      'sha256': sha256,
      'ocr_status': ocrStatus.wireName,
      'verification_status': verificationStatus.wireName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DocumentRecord.fromSqlMap(Map<String, Object?> map) {
    return DocumentRecord(
      id: map['id'] as String,
      title: map['title'] as String,
      category: DocumentCategory.fromWire(map['category'] as String?),
      documentType: DocumentType.fromWire(map['document_type'] as String?),
      assetName: map['asset_name'] as String?,
      originalPath: map['original_path'] as String,
      sha256: map['sha256'] as String,
      ocrStatus: OcrStatus.fromWire(map['ocr_status'] as String?),
      verificationStatus: VerificationStatus.fromWire(
        map['verification_status'] as String?,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// Output returned by [OfflineOcrService.recognizeImage].
class OcrOutput {
  const OcrOutput({
    required this.text,
    this.language = 'eng',
    this.page = 1,
    this.confidence,
    this.processingMs,
    this.errorCode,
    this.errorMessage,
  });

  final String text;
  final String language;
  final int page;
  final double? confidence;
  final int? processingMs;

  /// Optional structured error code (`MODEL_MISSING`, `DECODE_FAILED`,
  /// `OCR_FAILED`). Null when OCR succeeded.
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => errorCode == null;
}

/// Candidate date recognized by [DocumentExtractionService.extract].
class DateCandidate {
  const DateCandidate({
    required this.fieldKind,
    required this.rawText,
    required this.sourceSnippet,
    this.isoDate,
    this.page = 1,
    this.ambiguous = false,
    this.isDerived = false,
    this.confidenceLevel = ConfidenceLevel.medium,
  });

  final DateFieldKind fieldKind;
  final String rawText;

  /// Normalized ISO date (`YYYY-MM-DD`), or null if ambiguous/unparseable.
  final String? isoDate;
  final String sourceSnippet;
  final int page;
  final bool ambiguous;

  /// True when derived from purchase date + explicit warranty duration.
  final bool isDerived;
  final ConfidenceLevel confidenceLevel;

  DateCandidate copyWith({
    DateFieldKind? fieldKind,
    String? rawText,
    String? isoDate,
    String? sourceSnippet,
    int? page,
    bool? ambiguous,
    bool? isDerived,
    ConfidenceLevel? confidenceLevel,
  }) {
    return DateCandidate(
      fieldKind: fieldKind ?? this.fieldKind,
      rawText: rawText ?? this.rawText,
      isoDate: isoDate ?? this.isoDate,
      sourceSnippet: sourceSnippet ?? this.sourceSnippet,
      page: page ?? this.page,
      ambiguous: ambiguous ?? this.ambiguous,
      isDerived: isDerived ?? this.isDerived,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
    );
  }
}

/// Stateless classification and date extraction output from OCR text.
class ExtractionResult {
  const ExtractionResult({
    this.suggestedCategory = DocumentCategory.other,
    this.suggestedType = DocumentType.other,
    this.categoryEvidence,
    this.typeEvidence,
    this.dateCandidates = const <DateCandidate>[],
    this.assetNameSuggestion,
  });

  final DocumentCategory suggestedCategory;
  final DocumentType suggestedType;
  final String? categoryEvidence;
  final String? typeEvidence;
  final List<DateCandidate> dateCandidates;
  final String? assetNameSuggestion;
}

/// Provenance and snippet record for extracted or confirmed fields
/// (`evidence` table).
class EvidenceRecord {
  const EvidenceRecord({
    required this.id,
    required this.documentId,
    required this.fieldKind,
    required this.provenance,
    this.proposedRaw,
    this.proposedIso,
    this.confirmedIso,
    this.sourceSnippet,
    this.pageNumber = 1,
    this.isVerified = false,
  });

  final String id;
  final String documentId;
  final DateFieldKind fieldKind;
  final String? proposedRaw;
  final String? proposedIso;
  final String? confirmedIso;
  final String? sourceSnippet;
  final int pageNumber;
  final EvidenceProvenance provenance;
  final bool isVerified;

  Map<String, Object?> toSqlMap() {
    return <String, Object?>{
      'id': id,
      'document_id': documentId,
      'field_kind': fieldKind.wireName,
      'proposed_raw': proposedRaw,
      'proposed_iso': proposedIso,
      'confirmed_iso': confirmedIso,
      'source_snippet': sourceSnippet,
      'page_number': pageNumber,
      'provenance': provenance.wireName,
      'is_verified': isVerified ? 1 : 0,
    };
  }

  factory EvidenceRecord.fromSqlMap(Map<String, Object?> map) {
    return EvidenceRecord(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      fieldKind: DateFieldKind.fromWire(map['field_kind'] as String?),
      proposedRaw: map['proposed_raw'] as String?,
      proposedIso: map['proposed_iso'] as String?,
      confirmedIso: map['confirmed_iso'] as String?,
      sourceSnippet: map['source_snippet'] as String?,
      pageNumber: (map['page_number'] as int?) ?? 1,
      provenance: EvidenceProvenance.fromWire(map['provenance'] as String?),
      isVerified: ((map['is_verified'] as int?) ?? 0) == 1,
    );
  }
}

/// Confirmed deadline item submitted during user review.
class VerifiedDeadlineInput {
  const VerifiedDeadlineInput({
    required this.kind,
    required this.dateIso,
    this.evidenceSnippet,
    this.proposedRaw,
    this.proposedIso,
    this.page = 1,
    this.provenance = EvidenceProvenance.userConfirmed,
    this.reminderOffsetsDays = const <int>[30, 7, 1],
  });

  final DeadlineKind kind;

  /// Confirmed date in `YYYY-MM-DD` format.
  final String dateIso;
  final String? evidenceSnippet;
  final String? proposedRaw;
  final String? proposedIso;
  final int page;
  final EvidenceProvenance provenance;
  final List<int> reminderOffsetsDays;
}

/// User-confirmed document payload passed to [VaultRepository.saveVerified].
class VerifiedDocumentInput {
  const VerifiedDocumentInput({
    required this.originalTempPath,
    required this.title,
    required this.category,
    required this.documentType,
    this.assetName,
    this.tags = const <String>[],
    this.sha256,
    this.ocrStatus = OcrStatus.success,
    this.verificationStatus = VerificationStatus.verified,
    this.verifiedDeadlines = const <VerifiedDeadlineInput>[],
    this.evidenceRecords = const <EvidenceRecord>[],
  });

  /// Path to the captured/imported image prior to vault storage copy.
  final String originalTempPath;
  final String title;
  final DocumentCategory category;
  final DocumentType documentType;
  final String? assetName;
  final List<String> tags;
  final String? sha256;
  final OcrStatus ocrStatus;
  final VerificationStatus verificationStatus;
  final List<VerifiedDeadlineInput> verifiedDeadlines;
  final List<EvidenceRecord> evidenceRecords;

  /// Convenience alias for [originalTempPath].
  String get originalPath => originalTempPath;
}

/// Persisted deadline record (`deadlines` table).
class DeadlineRecord {
  const DeadlineRecord({
    required this.id,
    required this.documentId,
    required this.kind,
    required this.dateIso,
    this.evidenceId,
    this.evidenceSnippet,
    this.page = 1,
    this.isVerified = true,
    this.reminderOffsetsDays = const <int>[30, 7, 1],
    this.notificationIds = const <int>[],
    this.lastScheduledAt,
    this.updatedAt,
  });

  final String id;
  final String documentId;
  final DeadlineKind kind;

  /// Confirmed due/expiry date in `YYYY-MM-DD` format.
  final String dateIso;
  final String? evidenceId;
  final String? evidenceSnippet;
  final int? page;
  final bool isVerified;
  final List<int> reminderOffsetsDays;
  final List<int> notificationIds;
  final DateTime? lastScheduledAt;
  final DateTime? updatedAt;

  /// Alias matching SQLite column `due_date_iso`.
  String get dueDateIso => dateIso;

  DeadlineRecord copyWith({
    String? id,
    String? documentId,
    DeadlineKind? kind,
    String? dateIso,
    String? evidenceId,
    String? evidenceSnippet,
    int? page,
    bool? isVerified,
    List<int>? reminderOffsetsDays,
    List<int>? notificationIds,
    DateTime? lastScheduledAt,
    DateTime? updatedAt,
  }) {
    return DeadlineRecord(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      kind: kind ?? this.kind,
      dateIso: dateIso ?? this.dateIso,
      evidenceId: evidenceId ?? this.evidenceId,
      evidenceSnippet: evidenceSnippet ?? this.evidenceSnippet,
      page: page ?? this.page,
      isVerified: isVerified ?? this.isVerified,
      reminderOffsetsDays: reminderOffsetsDays ?? this.reminderOffsetsDays,
      notificationIds: notificationIds ?? this.notificationIds,
      lastScheduledAt: lastScheduledAt ?? this.lastScheduledAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Grounded answer returned by [QuestionService.answer].
class AnswerResult {
  const AnswerResult({
    required this.status,
    required this.text,
    this.documentIds = const <String>[],
    this.deadlineIds = const <String>[],
    this.evidenceSnippet,
    this.sourcePage,
  });

  final AnswerStatus status;
  final String text;
  final List<String> documentIds;
  final List<String> deadlineIds;
  final String? evidenceSnippet;
  final int? sourcePage;
}

/// Outcome of scheduling local deadline notifications via [ReminderService].
class ReminderScheduleResult {
  const ReminderScheduleResult({
    required this.scheduled,
    required this.permissionGranted,
    this.notificationIds = const <int>[],
    this.statusMessage,
    this.errorCode,
  });

  final bool scheduled;
  final bool permissionGranted;
  final List<int> notificationIds;
  final String? statusMessage;
  final String? errorCode;
}

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

  ActionStep copyWith({
    String? id,
    String? title,
    String? description,
    String? copyableText,
    bool? isCompleted,
  }) {
    return ActionStep(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      copyableText: copyableText ?? this.copyableText,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
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

  ActionPlaybook copyWith({
    String? documentId,
    String? summary,
    List<ActionStep>? steps,
    PlaybookSource? source,
  }) {
    return ActionPlaybook(
      documentId: documentId ?? this.documentId,
      summary: summary ?? this.summary,
      steps: steps ?? this.steps,
      source: source ?? this.source,
    );
  }
}
