/// Frozen service interfaces for LifeVault v0.1.
///
/// Owned by Developer 4 (Integration Lead). Feature modules implement these
/// contracts in their respective folders.
library;

import 'enums.dart';
import 'models.dart';

/// Developer 1 contract: On-device offline OCR service.
abstract interface class OfflineOcrService {
  Future<OcrOutput> recognizeImage(
    String localImagePath, {
    String language = 'eng',
  });
}

/// Developer 2 contract: Stateless pure-Dart category/type and date extractor.
abstract interface class DocumentExtractionService {
  ExtractionResult extract(String ocrText);
}

/// Developer 3 contract: Local SQLite and private file vault repository.
abstract interface class VaultRepository {
  Future<DocumentRecord> saveVerified(VerifiedDocumentInput input);

  Future<List<DocumentRecord>> search({
    String? text,
    DocumentCategory? category,
  });

  Future<List<DeadlineRecord>> getDeadlines({bool verifiedOnly = true});

  Future<void> deleteDocument(String documentId);
}

/// Convenience lookup helpers on [VaultRepository] so implementations only
/// need to implement the four core methods from Section 6.
extension VaultRepositoryLookupExtension on VaultRepository {
  Future<DocumentRecord?> findDocumentById(String documentId) async {
    final all = await search();
    for (final doc in all) {
      if (doc.id == documentId) {
        return doc;
      }
    }
    return null;
  }

  Future<DocumentRecord?> findDocumentBySha256(String sha256) async {
    final all = await search();
    for (final doc in all) {
      if (doc.sha256 == sha256) {
        return doc;
      }
    }
    return null;
  }
}

/// Developer 3 contract: Deterministic grounded Q&A service over verified data.
abstract interface class QuestionService {
  Future<AnswerResult> answer(String question);
}

/// Developer 3 contract: Android local notification reminder scheduler.
abstract interface class ReminderService {
  Future<ReminderScheduleResult> schedule(DeadlineRecord deadline);

  Future<void> cancelForDocument(String documentId);
}

/// On-device Action Guide generator (Qwen-0.6B primary + deterministic fallback).
abstract interface class ActionGuideService {
  Future<ActionPlaybook> generatePlaybook({
    required DocumentRecord document,
    DeadlineRecord? deadline,
    String? evidenceSnippet,
  });
}
