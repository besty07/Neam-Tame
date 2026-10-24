import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/contracts/contracts.dart';
import 'document_detail_screen.dart';
import 'review_screen.dart';

/// Deterministic "Ask LifeVault" screen grounded strictly in verified local
/// records (Section 4).
class AskScreen extends StatefulWidget {
  const AskScreen({
    super.key,
    required this.controller,
  });

  final LifeVaultController controller;

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  late final TextEditingController _questionController;

  static const List<String> _suggestedQueries = <String>[
    'bike insurance expiry',
    'fridge warranty',
    'electricity bill due',
  ];

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(
      text: widget.controller.lastQuestion,
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _submitQuestion([String? overrideQuery]) async {
    final query = overrideQuery ?? _questionController.text;
    if (overrideQuery != null) {
      _questionController.text = overrideQuery;
    }
    await widget.controller.askQuestion(query);
  }

  Future<void> _openDocument(BuildContext context, String documentId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => DocumentDetailScreen(
          controller: widget.controller,
          documentId: documentId,
        ),
      ),
    );
  }

  Future<void> _reviewDocument(
    BuildContext context,
    DocumentRecord document,
  ) async {
    final draft = widget.controller.createEditDraft(document);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ReviewScreen(
          controller: widget.controller,
          draft: draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.controller.lastAnswerResult;
    final isAnswering = widget.controller.isAnswering;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Ask LifeVault (Verified Local Records Only)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ask about insurance expiry dates, warranty endings, '
                  'bill due dates, or where a document is stored. Answers '
                  'always cite your verified records.',
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('ask_question_field'),
                  controller: _questionController,
                  onSubmitted: (_) => _submitQuestion(),
                  decoration: const InputDecoration(
                    hintText: 'e.g., When does my bike insurance expire?',
                    prefixIcon: Icon(Icons.help_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('ask_submit_button'),
                  onPressed: isAnswering ? null : () => _submitQuestion(),
                  icon: const Icon(Icons.search),
                  label: const Text('Get Grounded Answer'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestedQueries.map((chipText) {
                    return ActionChip(
                      key: Key('ask_chip_$chipText'),
                      label: Text(chipText),
                      onPressed: isAnswering
                          ? null
                          : () => _submitQuestion(chipText),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (isAnswering)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (answer != null)
          _buildAnswerCard(context, answer),
      ],
    );
  }

  Widget _buildAnswerCard(BuildContext context, AnswerResult answer) {
    final statusLabel = answer.status.wireName.toUpperCase();
    final isUnsupportedOrMissing =
        answer.status == AnswerStatus.notFound ||
        answer.status == AnswerStatus.unsupportedQuestion;

    return Card(
      key: const Key('ask_answer_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.verified_user_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Grounded Response',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  key: const Key('ask_answer_status_chip'),
                  label: Text(statusLabel),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              answer.text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (answer.evidenceSnippet != null &&
                answer.evidenceSnippet!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Evidence Snippet (Page ${answer.sourcePage ?? 1}): '
                  '"${answer.evidenceSnippet}"',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            if (answer.documentIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                'Source Documents (${answer.documentIds.length})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...answer.documentIds.map((docId) {
                final doc = widget.controller.findLoadedDocumentById(docId);
                final title = doc?.title ?? 'Document $docId';
                String subtitle = 'Document ID: $docId';
                if (doc != null) {
                  subtitle =
                      '${doc.category.displayName} • '
                      '${doc.documentType.displayName}';
                }
                Widget trailingButton = OutlinedButton(
                  onPressed: () => _openDocument(context, docId),
                  child: const Text('Open'),
                );
                if (answer.status == AnswerStatus.unverified && doc != null) {
                  trailingButton = OutlinedButton(
                    onPressed: () => _reviewDocument(context, doc),
                    child: const Text('Verify'),
                  );
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    key: Key('ask_source_doc_$docId'),
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(title),
                    subtitle: Text(subtitle),
                    trailing: trailingButton,
                  ),
                );
              }),
            ],
            if (isUnsupportedOrMissing) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('ask_open_vault_button'),
                onPressed: () => widget.controller.setActiveTab(2),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Browse & Search Vault'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
