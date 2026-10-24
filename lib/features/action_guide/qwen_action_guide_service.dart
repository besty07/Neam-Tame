import 'package:flutter/services.dart';

import '../../core/contracts/contracts.dart';
import 'deterministic_action_guide_service.dart';

/// Signature for custom or mocked LLM prompt execution in tests.
typedef LlmPromptRunner = Future<Map<String, Object?>?> Function(
  Map<String, Object?> arguments,
);

/// On-device Qwen-0.6B (`qwen2.5-0.5b-instruct-q4_k_m.gguf`) Action Guide
/// generator communicating via `MethodChannel('lifevault/llm')` (Phase 2).
class QwenActionGuideService implements ActionGuideService {
  QwenActionGuideService({
    MethodChannel? channel,
    LlmPromptRunner? promptRunner,
  })  : _channel = channel ?? const MethodChannel(channelName),
        _promptRunner = promptRunner;

  static const String channelName = 'lifevault/llm';
  static const double defaultTemperature = 0.2;
  static const double defaultTopP = 0.9;
  static const int defaultMaxTokens = 256;

  /// Grounded system prompt from Section 4 of `QWEN_INTEGRATION_PLAN.md`.
  static const String systemPrompt = '''
You are LifeVault Offline Action Assistant.
Given a verified document and deadline, provide 3 to 4 actionable, practical steps the user must take before this deadline.
Rules:
1. Be concise, realistic, and bulleted.
2. Never invent, extrapolate, or alter any dates.
3. Suggest practical real-world steps (e.g. checking NCB, keeping RC ready, checking meter numbers).
4. Do not include markdown headers or greetings.''';

  static final RegExp _isoDatePattern = RegExp(r'\b\d{4}-\d{2}-\d{2}\b');

  final MethodChannel _channel;
  final LlmPromptRunner? _promptRunner;

  /// Builds the exact prompt input template from Section 4 of `QWEN_INTEGRATION_PLAN.md`.
  static String buildUserPrompt({
    required DocumentRecord document,
    DeadlineRecord? deadline,
    String? evidenceSnippet,
  }) {
    final asset =
        (document.assetName != null && document.assetName!.trim().isNotEmpty)
            ? document.assetName!.trim()
            : 'N/A';
    final dueDateIso =
        (deadline != null && deadline.isVerified) ? deadline.dateIso : 'N/A';
    final snippet =
        (evidenceSnippet ?? deadline?.evidenceSnippet ?? 'N/A').trim();

    return 'Document: ${document.title}\n'
        'Category: ${document.category.displayName}\n'
        'Asset: $asset\n'
        'Due Date: $dueDateIso\n'
        'Evidence Snippet: ${snippet.isEmpty ? 'N/A' : snippet}';
  }

  @override
  Future<ActionPlaybook> generatePlaybook({
    required DocumentRecord document,
    DeadlineRecord? deadline,
    String? evidenceSnippet,
  }) async {
    final effectiveSnippet = evidenceSnippet ?? deadline?.evidenceSnippet;
    final userPrompt = buildUserPrompt(
      document: document,
      deadline: deadline,
      evidenceSnippet: effectiveSnippet,
    );

    final args = <String, Object?>{
      'systemPrompt': systemPrompt,
      'userPrompt': userPrompt,
      'temperature': defaultTemperature,
      'topP': defaultTopP,
      'maxTokens': defaultMaxTokens,
      'documentId': document.id,
      'title': document.title,
      'category': document.category.wireName,
      'documentType': document.documentType.wireName,
      'assetName': document.assetName,
      'dueDateIso': deadline?.dateIso,
      'evidenceSnippet': effectiveSnippet,
    };

    final Map<String, Object?>? response;
    if (_promptRunner != null) {
      response = await _promptRunner(args);
    } else {
      response = await _channel.invokeMapMethod<String, Object?>(
        'generateActionPlaybook',
        args,
      );
    }

    if (response == null) {
      throw StateError('Null response from lifevault/llm channel.');
    }

    final errorCode = response['errorCode'] as String?;
    if (errorCode != null && errorCode.isNotEmpty) {
      final errorMessage =
          response['errorMessage'] as String? ?? 'Qwen inference error';
      throw StateError('$errorCode: $errorMessage');
    }

    final rawOutput = (response['text'] as String? ?? '').trim();
    if (rawOutput.isEmpty) {
      throw StateError('Empty text returned from Qwen inference.');
    }

    final copyableId =
        DeterministicActionGuideService.extractCopyableIdentifier(
      document: document,
      evidenceSnippet: effectiveSnippet,
    );

    final steps = parseGroundedSteps(
      rawOutput: rawOutput,
      documentId: document.id,
      verifiedDateIso: deadline?.dateIso,
      copyableIdentifier: copyableId,
    );

    if (steps.length < 2) {
      throw StateError(
        'Insufficient grounded steps parsed from Qwen output (${steps.length}).',
      );
    }

    final summary = (response['summary'] as String?)?.trim().isNotEmpty == true
        ? (response['summary'] as String).trim()
        : 'Contextual action plan generated offline by Qwen-0.6B for '
            '${document.title}.';

    return ActionPlaybook(
      documentId: document.id,
      summary: summary,
      steps: steps,
      source: PlaybookSource.qwen,
    );
  }

  /// Parses bulleted or numbered LLM output into grounded [ActionStep]s,
  /// enforcing Rule 2 ("Never invent, extrapolate, or alter any dates").
  static List<ActionStep> parseGroundedSteps({
    required String rawOutput,
    required String documentId,
    String? verifiedDateIso,
    String? copyableIdentifier,
  }) {
    final lines = rawOutput
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final parsedSteps = <ActionStep>[];
    for (final line in lines) {
      // Skip markdown headers or conversational greetings per Rule 4.
      if (line.startsWith('#')) {
        continue;
      }

      final cleaned =
          line.replaceFirst(RegExp(r'^(?:[-*•]|\d+[.)])\s*'), '').trim();
      if (cleaned.length < 6) {
        continue;
      }

      // Grounding safeguard (Rule 2): reject or scrub any invented ISO dates
      // that do not match the document's verified deadline date.
      final sanitized = _sanitizeUnverifiedDates(cleaned, verifiedDateIso);

      String title;
      String description;

      final boldMatch =
          RegExp(r'^\*\*([^*]+)\*\*\s*[:\-–]?\s*(.+)$').firstMatch(sanitized);
      final colonIndex = sanitized.indexOf(':');

      if (boldMatch != null) {
        title = boldMatch.group(1)!.trim();
        description = boldMatch.group(2)!.trim();
      } else if (colonIndex > 2 && colonIndex <= 48) {
        title = sanitized.substring(0, colonIndex).trim();
        description = sanitized.substring(colonIndex + 1).trim();
      } else {
        final words = sanitized.split(RegExp(r'\s+'));
        title = words.take(5).join(' ');
        description = sanitized;
      }

      final stepIndex = parsedSteps.length + 1;
      parsedSteps.add(
        ActionStep(
          id: '${documentId}_qwen_$stepIndex',
          title: title,
          description: description,
          copyableText: stepIndex == 1 ? copyableIdentifier : null,
        ),
      );

      if (parsedSteps.length >= 4) {
        break;
      }
    }

    return parsedSteps;
  }

  static String _sanitizeUnverifiedDates(
    String text,
    String? verifiedDateIso,
  ) {
    return text.replaceAllMapped(_isoDatePattern, (match) {
      final foundDate = match.group(0)!;
      if (verifiedDateIso != null && foundDate == verifiedDateIso) {
        return foundDate;
      }
      return verifiedDateIso ?? 'the verified deadline';
    });
  }
}

/// Hybrid Action Guide wrapper (Phase 2.4 of `QWEN_INTEGRATION_PLAN.md`):
/// Attempts [primary] (`QwenActionGuideService`) with a strict timeout
/// (default 3.5 seconds) and falls back instantly to [fallback]
/// (`DeterministicActionGuideService`) if Qwen is uninitialized, slow, or fails.
class HybridActionGuideService implements ActionGuideService {
  HybridActionGuideService({
    ActionGuideService? primary,
    ActionGuideService? fallback,
    this.timeout = const Duration(milliseconds: 3500),
  })  : _primary = primary ?? QwenActionGuideService(),
        _fallback = fallback ?? const DeterministicActionGuideService();

  final ActionGuideService _primary;
  final ActionGuideService _fallback;
  final Duration timeout;

  @override
  Future<ActionPlaybook> generatePlaybook({
    required DocumentRecord document,
    DeadlineRecord? deadline,
    String? evidenceSnippet,
  }) async {
    try {
      final result = await _primary
          .generatePlaybook(
            document: document,
            deadline: deadline,
            evidenceSnippet: evidenceSnippet,
          )
          .timeout(timeout);
      if (result.steps.isNotEmpty) {
        return result;
      }
    } on Object {
      // Fall through to deterministic offline playbook.
    }

    return _fallback.generatePlaybook(
      document: document,
      deadline: deadline,
      evidenceSnippet: evidenceSnippet,
    );
  }
}
