// lib/features/vault/services/question_service_impl.dart
// Owner: Developer 3 — Task D3.4
//
// Deterministic, grounded Q&A service.
// - Parses intent from plain text question (no LLM, no HTTP).
// - Queries ONLY verified records from VaultRepository.
// - Returns AnswerResult with document ID + evidence; never fabricates.
// - Supported intents: expiry, due_date, find_document, list_upcoming.
// - Status: answered | multiple_matches | unverified | not_found | unsupported_question.
// - Uses DateFieldKind (frozen contract name, not FieldKind).

import 'package:lifevault/core/contracts/contracts.dart';
import '../data/repositories/vault_repository_impl.dart';

/// Regex / keyword patterns for intent detection.
class _IntentPatterns {
  // Expiry intent: "when does X expire", "X expiry date", "when X policy ends"
  static final expiry = RegExp(
    r'\b(expire|expiry|expires|expired|valid\s+until|policy\s+end|warranty\s+end)\b',
    caseSensitive: false,
  );

  // Due date intent: "when is X due", "X bill due", "pay before", "payment due"
  static final due = RegExp(
    r'\b(due|bill\s+due|pay\s+before|payment\s+due|due\s+date)\b',
    caseSensitive: false,
  );

  // Upcoming: "what is upcoming", "upcoming deadlines", "next 30 days"
  static final upcoming = RegExp(
    r'\b(upcoming|next\s+\d+\s+days?|soon|deadlines?|reminders?)\b',
    caseSensitive: false,
  );

  // Find: "find X", "show X", "where is X", "search for X"
  static final find = RegExp(
    r'\b(find|show|where\s+is|where\s+are|search|look\s+for)\b',
    caseSensitive: false,
  );
}

/// Parsed question intent and the subject (keyword extracted from question).
class _ParsedQuestion {
  final _QuestionIntent intent;
  final String subject; // the meaningful keywords after removing intent verbs

  const _ParsedQuestion(this.intent, this.subject);
}

enum _QuestionIntent { expiry, due, upcoming, find, unsupported }

class QuestionServiceImpl implements QuestionService {
  final VaultRepositoryImpl _repo;

  /// For testing, inject a VaultRepositoryImpl with an in-memory DB.
  QuestionServiceImpl(this._repo);

  @override
  Future<AnswerResult> answer(String question) async {
    final parsed = _parseIntent(question);

    switch (parsed.intent) {
      case _QuestionIntent.expiry:
        return _answerExpiry(parsed.subject);
      case _QuestionIntent.due:
        return _answerDue(parsed.subject);
      case _QuestionIntent.upcoming:
        return _answerUpcoming();
      case _QuestionIntent.find:
        return _answerFind(parsed.subject);
      case _QuestionIntent.unsupported:
        return const AnswerResult(
          status: AnswerStatus.unsupportedQuestion,
          text: 'I can answer questions about expiry dates, bill due dates, '
              'and help you find documents. Try: "When does my bike insurance expire?" '
              'or "When is my electricity bill due?"',
          documentIds: [],
          deadlineIds: [],
        );
    }
  }

  // ─── Intent handlers ─────────────────────────────────────────────────────────

  Future<AnswerResult> _answerExpiry(String subject) async {
    final deadlines = await _repo.getDeadlines(verifiedOnly: true);
    final expiry = deadlines.where(
      (d) => d.kind == DeadlineKind.expiry,
    );
    final matched = await _matchDeadlinesToSubject(expiry.toList(), subject);
    return _buildDeadlineAnswer(matched, subject, 'expiry');
  }

  Future<AnswerResult> _answerDue(String subject) async {
    final deadlines = await _repo.getDeadlines(verifiedOnly: true);
    final due = deadlines.where(
      (d) => d.kind == DeadlineKind.billDue,
    );
    final matched = await _matchDeadlinesToSubject(due.toList(), subject);
    return _buildDeadlineAnswer(matched, subject, 'bill due date');
  }

  Future<AnswerResult> _answerUpcoming() async {
    final deadlines = await _repo.getUpcomingDeadlines(withinDays: 30);
    if (deadlines.isEmpty) {
      return const AnswerResult(
        status: AnswerStatus.notFound,
        text: 'No upcoming deadlines in the next 30 days.',
        documentIds: [],
        deadlineIds: [],
      );
    }

    final lines = <String>[];
    final docIds = <String>{};
    for (final dl in deadlines) {
      final doc = await _repo.findById(dl.documentId);
      if (doc != null) {
        final daysLeft = _daysUntil(dl.dateIso);
        lines.add(
          '• ${doc.title} — ${_formatKind(dl.kind)} on ${dl.dateIso}'
          '${daysLeft >= 0 ? " ($daysLeft days left)" : " (overdue)"}',
        );
        docIds.add(dl.documentId);
      }
    }

    return AnswerResult(
      status: AnswerStatus.answered,
      text: 'Upcoming deadlines:\n${lines.join('\n')}',
      documentIds: docIds.toList(),
      deadlineIds: deadlines.map((d) => d.id).toList(),
    );
  }

  Future<AnswerResult> _answerFind(String subject) async {
    if (subject.isEmpty) {
      return const AnswerResult(
        status: AnswerStatus.unsupportedQuestion,
        text: 'Please specify what you\'re looking for. '
            'Example: "Find my fridge warranty"',
        documentIds: [],
        deadlineIds: [],
      );
    }

    final docs = await _repo.search(text: subject);
    if (docs.isEmpty) {
      return AnswerResult(
        status: AnswerStatus.notFound,
        text: 'No documents found matching "$subject".',
        documentIds: const [],
        deadlineIds: const [],
      );
    }

    if (docs.length == 1) {
      final doc = docs.first;
      return AnswerResult(
        status: AnswerStatus.answered,
        text: 'Found: ${doc.title} '
            '(${doc.category.name}, ${doc.documentType.name})',
        documentIds: [doc.id],
        deadlineIds: const [],
      );
    }

    // Multiple matches
    final titles = docs.take(5).map((d) => '• ${d.title}').join('\n');
    return AnswerResult(
      status: AnswerStatus.multipleMatches,
      text: 'Found ${docs.length} documents matching "$subject":\n$titles'
          '${docs.length > 5 ? "\n...and ${docs.length - 5} more" : ""}',
      documentIds: docs.map((d) => d.id).toList(),
      deadlineIds: const [],
    );
  }

  // ─── Matching helpers ────────────────────────────────────────────────────────

  /// Match deadlines to a subject string by looking up their parent documents.
  Future<List<DeadlineRecord>> _matchDeadlinesToSubject(
    List<DeadlineRecord> deadlines,
    String subject,
  ) async {
    if (subject.isEmpty) return deadlines; // return all if no subject
    final keywords = _tokenize(subject);
    if (keywords.isEmpty) return deadlines;

    final matched = <DeadlineRecord>[];
    for (final dl in deadlines) {
      final doc = await _repo.findById(dl.documentId);
      if (doc != null && _docMatchesKeywords(doc, keywords)) {
        matched.add(dl);
      }
    }
    return matched;
  }

  bool _docMatchesKeywords(DocumentRecord doc, List<String> keywords) {
    if (keywords.isEmpty) return true;
    final haystack = [
      doc.title,
      doc.assetName ?? '',
      doc.category.name,
      doc.documentType.name,
    ].join(' ').toLowerCase();

    return keywords.every((kw) => haystack.contains(kw));
  }

  AnswerResult _buildDeadlineAnswer(
    List<DeadlineRecord> matched,
    String subject,
    String intentLabel,
  ) {
    if (matched.isEmpty) {
      return AnswerResult(
        status: AnswerStatus.notFound,
        text: subject.isEmpty
            ? 'No verified $intentLabel records found.'
            : 'No verified $intentLabel records found matching "$subject".',
        documentIds: const [],
        deadlineIds: const [],
      );
    }

    if (matched.length == 1) {
      final dl = matched.first;
      final daysLeft = _daysUntil(dl.dateIso);
      return AnswerResult(
        status: AnswerStatus.answered,
        text: daysLeft >= 0
            ? '$intentLabel: ${dl.dateIso} ($daysLeft days remaining).'
            : '$intentLabel: ${dl.dateIso} — this deadline has passed.',
        documentIds: [dl.documentId],
        deadlineIds: [dl.id],
        evidenceSnippet: null,
      );
    }

    // Multiple matches — present all, let user choose
    final lines = matched
        .map((dl) => '• ${dl.dateIso} (ID: ${dl.documentId})')
        .join('\n');
    return AnswerResult(
      status: AnswerStatus.multipleMatches,
      text: 'Found ${matched.length} matching $intentLabel records:\n$lines',
      documentIds: matched.map((d) => d.documentId).toList(),
      deadlineIds: matched.map((d) => d.id).toList(),
    );
  }

  // ─── Intent parser ───────────────────────────────────────────────────────────

  _ParsedQuestion _parseIntent(String question) {
    final q = question.trim().toLowerCase();

    if (_IntentPatterns.upcoming.hasMatch(q)) {
      return const _ParsedQuestion(_QuestionIntent.upcoming, '');
    }
    if (_IntentPatterns.expiry.hasMatch(q)) {
      return _ParsedQuestion(
        _QuestionIntent.expiry,
        _extractSubject(q, _IntentPatterns.expiry),
      );
    }
    if (_IntentPatterns.due.hasMatch(q)) {
      return _ParsedQuestion(
        _QuestionIntent.due,
        _extractSubject(q, _IntentPatterns.due),
      );
    }
    if (_IntentPatterns.find.hasMatch(q)) {
      return _ParsedQuestion(
        _QuestionIntent.find,
        _extractSubject(q, _IntentPatterns.find),
      );
    }

    return const _ParsedQuestion(_QuestionIntent.unsupported, '');
  }

  /// Removes stop words + intent keywords and returns the meaningful subject.
  String _extractSubject(String question, RegExp intentPattern) {
    final cleaned = question
        .replaceAll(intentPattern, '')
        .replaceAll(
          RegExp(
            r'\b(when|does|is|my|the|a|an|of|for|about|do|i|find|show|where|are)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned;
  }

  List<String> _tokenize(String text) => text
      .toLowerCase()
      .split(RegExp(r'[\s,]+'))
      .where((s) => s.length > 2)
      .toList();

  int _daysUntil(String isoDate) {
    final due = DateTime.parse(isoDate);
    final today = DateTime.now();
    return due.difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  String _formatKind(DeadlineKind kind) => switch (kind) {
        DeadlineKind.expiry => 'expires',
        DeadlineKind.billDue => 'due',
        DeadlineKind.manual => 'due',
      };
}
