/// Frozen domain enums for LifeVault v0.1 / v0.2.
///
/// Owned by Developer 4 (Integration Lead). Do not redefine in feature modules.
library;

/// Household document categories (Where do I find it?).
enum DocumentCategory {
  medical('medical', 'Medical'),
  finance('finance', 'Finance'),
  appliances('appliances', 'Appliances'),
  vehicles('vehicles', 'Vehicles'),
  insurance('insurance', 'Insurance'),
  homeUtilities('home_utilities', 'Home & Utilities'),
  identityPersonal('identity_personal', 'Identity & Personal'),
  education('education', 'Education'),
  legalLetters('legal_letters', 'Legal & Letters'),
  other('other', 'Other');

  const DocumentCategory(this.wireName, this.displayName);

  /// Canonical snake_case identifier stored in SQLite (`category`).
  final String wireName;

  /// Human-readable label for UI display.
  final String displayName;

  // Snake-case static aliases for compatibility with Master Plan tables.
  // ignore: constant_identifier_names
  static const DocumentCategory home_utilities = homeUtilities;
  // ignore: constant_identifier_names
  static const DocumentCategory identity_personal = identityPersonal;
  // ignore: constant_identifier_names
  static const DocumentCategory legal_letters = legalLetters;

  static DocumentCategory fromWire(String? raw) {
    if (raw == null || raw.isEmpty) {
      return DocumentCategory.other;
    }
    final normalized = raw.trim().toLowerCase();
    for (final value in DocumentCategory.values) {
      if (value.wireName == normalized ||
          value.name.toLowerCase() == normalized ||
          value.displayName.toLowerCase() == normalized) {
        return value;
      }
    }
    return DocumentCategory.other;
  }
}

/// Document structural type (What kind of document is it?), independent of
/// [DocumentCategory].
enum DocumentType {
  insurancePolicy('insurance_policy', 'Insurance Policy'),
  warranty('warranty', 'Warranty'),
  bill('bill', 'Bill'),
  invoiceReceipt('invoice_receipt', 'Invoice / Receipt'),
  medicalRecord('medical_record', 'Medical Record'),
  prescription('prescription', 'Prescription'),
  registration('registration', 'Registration'),
  certificate('certificate', 'Certificate'),
  letter('letter', 'Letter'),
  other('other', 'Other');

  const DocumentType(this.wireName, this.displayName);

  /// Canonical snake_case identifier stored in SQLite (`document_type`).
  final String wireName;

  /// Human-readable label for UI display.
  final String displayName;

  // Snake-case static aliases for compatibility with Master Plan tables.
  // ignore: constant_identifier_names
  static const DocumentType insurance_policy = insurancePolicy;
  // ignore: constant_identifier_names
  static const DocumentType invoice_receipt = invoiceReceipt;
  // ignore: constant_identifier_names
  static const DocumentType medical_record = medicalRecord;

  static DocumentType fromWire(String? raw) {
    if (raw == null || raw.isEmpty) {
      return DocumentType.other;
    }
    final normalized = raw.trim().toLowerCase();
    for (final value in DocumentType.values) {
      if (value.wireName == normalized ||
          value.name.toLowerCase() == normalized ||
          value.displayName.toLowerCase() == normalized) {
        return value;
      }
    }
    return DocumentType.other;
  }
}

/// Kind of date field recognized in a document.
///
/// Only [expiry] and [due] should generate candidate deadlines.
enum DateFieldKind {
  expiry('expiry'),
  due('due'),
  start('start'),
  purchase('purchase'),
  issue('issue'),
  unknown('unknown');

  const DateFieldKind(this.wireName);

  final String wireName;

  // Alias for Section 5 `coverage_start`.
  // ignore: constant_identifier_names
  static const DateFieldKind coverage_start = start;
  static const DateFieldKind coverageStart = start;

  bool get isDeadlineCandidate =>
      this == DateFieldKind.expiry || this == DateFieldKind.due;

  static DateFieldKind fromWire(String? raw) {
    if (raw == null || raw.isEmpty) {
      return DateFieldKind.unknown;
    }
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'coverage_start' || normalized == 'coveragestart') {
      return DateFieldKind.start;
    }
    for (final value in DateFieldKind.values) {
      if (value.wireName == normalized ||
          value.name.toLowerCase() == normalized) {
        return value;
      }
    }
    return DateFieldKind.unknown;
  }
}

/// Heuristic confidence level for extracted date candidates.
enum ConfidenceLevel {
  high('high'),
  medium('medium'),
  low('low');

  const ConfidenceLevel(this.wireName);

  final String wireName;

  static ConfidenceLevel fromWire(String? raw) {
    if (raw == null || raw.isEmpty) {
      return ConfidenceLevel.low;
    }
    final normalized = raw.trim().toLowerCase();
    for (final value in ConfidenceLevel.values) {
      if (value.wireName == normalized ||
          value.name.toLowerCase() == normalized) {
        return value;
      }
    }
    return ConfidenceLevel.low;
  }
}

/// Kind of confirmed deadline stored in SQLite (`deadlines.kind`).
enum DeadlineKind {
  expiry('expiry', 'Expiry'),
  billDue('bill_due', 'Bill Due'),
  manual('manual', 'Manual Deadline');

  const DeadlineKind(this.wireName, this.displayName);

  final String wireName;
  final String displayName;

  // ignore: constant_identifier_names
  static const DeadlineKind bill_due = billDue;

  static DeadlineKind fromWire(String? raw) {
    if (raw == null || raw.isEmpty) {
      return DeadlineKind.manual;
    }
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'due' ||
        normalized == 'bill_due' ||
        normalized == 'billdue') {
      return DeadlineKind.billDue;
    }
    for (final value in DeadlineKind.values) {
      if (value.wireName == normalized ||
          value.name.toLowerCase() == normalized) {
        return value;
      }
    }
    return DeadlineKind.manual;
  }
}

/// Status of OCR processing for a [DocumentRecord].
enum OcrStatus {
  pending('pending'),
  success('success'),
  failed('failed'),
  manual('manual');

  const OcrStatus(this.wireName);

  final String wireName;

  static OcrStatus fromWire(String? raw) {
    if (raw == null || raw.isEmpty) {
      return OcrStatus.pending;
    }
    final normalized = raw.trim().toLowerCase();
    for (final value in OcrStatus.values) {
      if (value.wireName == normalized ||
          value.name.toLowerCase() == normalized) {
        return value;
      }
    }
    return OcrStatus.pending;
  }
}

/// User verification state of a [DocumentRecord].
enum VerificationStatus {
  needsReview('needs_review'),
  verified('verified'),
  verifiedNoDeadline('verified_no_deadline'),
  unverified('unverified'),
  proposed('proposed'),
  ambiguous('ambiguous'),
  missing('missing');

  const VerificationStatus(this.wireName);

  final String wireName;

  // ignore: constant_identifier_names
  static const VerificationStatus needs_review = needsReview;
  // ignore: constant_identifier_names
  static const VerificationStatus verified_no_deadline = verifiedNoDeadline;

  bool get isUserVerified =>
      this == VerificationStatus.verified ||
      this == VerificationStatus.verifiedNoDeadline;

  static VerificationStatus fromWire(String? raw) {
    if (raw == null || raw.isEmpty) {
      return VerificationStatus.needsReview;
    }
    final normalized = raw.trim().toLowerCase();
    for (final value in VerificationStatus.values) {
      if (value.wireName == normalized ||
          value.name.toLowerCase() == normalized) {
        return value;
      }
    }
    return VerificationStatus.needsReview;
  }
}

/// Provenance of an evidence field (`evidence.provenance`).
enum EvidenceProvenance {
  ocrProposed('ocr_proposed'),
  userConfirmed('user_confirmed'),
  manual('manual');

  const EvidenceProvenance(this.wireName);

  final String wireName;

  // ignore: constant_identifier_names
  static const EvidenceProvenance ocr_proposed = ocrProposed;
  // ignore: constant_identifier_names
  static const EvidenceProvenance user_confirmed = userConfirmed;

  static EvidenceProvenance fromWire(String? raw) {
    if (raw == null || raw.isEmpty) {
      return EvidenceProvenance.manual;
    }
    final normalized = raw.trim().toLowerCase();
    for (final value in EvidenceProvenance.values) {
      if (value.wireName == normalized ||
          value.name.toLowerCase() == normalized) {
        return value;
      }
    }
    return EvidenceProvenance.manual;
  }
}

/// Outcome status for grounded deterministic Q&A (`Ask LifeVault`).
enum AnswerStatus {
  answered('answered'),
  multipleMatches('multiple_matches'),
  unverified('unverified'),
  notFound('not_found'),
  unsupportedQuestion('unsupported_question');

  const AnswerStatus(this.wireName);

  final String wireName;

  // ignore: constant_identifier_names
  static const AnswerStatus multiple_matches = multipleMatches;
  // ignore: constant_identifier_names
  static const AnswerStatus not_found = notFound;
  // ignore: constant_identifier_names
  static const AnswerStatus unsupported_question = unsupportedQuestion;

  static AnswerStatus fromWire(String? raw) {
    if (raw == null || raw.isEmpty) {
      return AnswerStatus.unsupportedQuestion;
    }
    final normalized = raw.trim().toLowerCase();
    for (final value in AnswerStatus.values) {
      if (value.wireName == normalized ||
          value.name.toLowerCase() == normalized) {
        return value;
      }
    }
    return AnswerStatus.unsupportedQuestion;
  }
}

/// Engine source that produced an [ActionPlaybook].
enum PlaybookSource {
  gemma('gemma', 'Gemma 3n On-Device'),
  qwen('qwen', 'Qwen2.5-0.5B On-Device'),
  deterministicFallback('deterministic_fallback', 'Verified Offline Playbook');

  const PlaybookSource(this.wireName, this.displayName);

  final String wireName;
  final String displayName;
}

/// Runtime state of the optional Gemma 3n E4B IT on-device vision extractor
/// (`LifeVault_GEMMA3N_VISION_MIGRATION.md` Section 4).
enum VisionModelState {
  modelMissing('model_missing', 'Model missing'),
  loadingModel('loading_model', 'Loading model'),
  ready('ready', 'Gemma 3n E4B ready'),
  analyzing('analyzing', 'Analyzing'),
  needsReview('needs_review', 'Needs review'),
  modelUnavailable('model_unavailable', 'Model unavailable');

  const VisionModelState(this.wireName, this.displayName);

  final String wireName;
  final String displayName;

  static VisionModelState fromWire(String? raw) {
    if (raw == null || raw.isEmpty) {
      return VisionModelState.modelMissing;
    }
    final normalized = raw.trim().toLowerCase();
    for (final value in VisionModelState.values) {
      if (value.wireName == normalized ||
          value.name.toLowerCase() == normalized) {
        return value;
      }
    }
    return VisionModelState.modelMissing;
  }
}
