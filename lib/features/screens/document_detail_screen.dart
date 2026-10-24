import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/contracts/contracts.dart';
import 'review_screen.dart';

/// Document detail view displaying original image, metadata, verified
/// deadlines, edit/recategorize action, and delete confirmation (Section 4).
class DocumentDetailScreen extends StatelessWidget {
  const DocumentDetailScreen({
    super.key,
    required this.controller,
    required this.documentId,
  });

  final LifeVaultController controller;
  final String documentId;

  Future<void> _openEdit(BuildContext context, DocumentRecord document) async {
    final draft = controller.createEditDraft(document);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ReviewScreen(
          controller: controller,
          draft: draft,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DocumentRecord document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Document?'),
          content: Text(
            'Delete "${document.title}" from your local vault? '
            'This removes its copied image file and cancels its local '
            'reminders.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirm_delete_document_button'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await controller.deleteDocument(document.id);
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final document = controller.findLoadedDocumentById(documentId);
        if (document == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Document Detail')),
            body: const Center(
              child: Text('Document was deleted or is no longer available.'),
            ),
          );
        }

        final deadlines = controller.deadlinesForDocument(document.id);
        final imageFile = File(document.originalPath);
        final hasLocalFile = imageFile.existsSync();
        final shortHash = document.sha256.length > 12
            ? document.sha256.substring(0, 12)
            : document.sha256;

        return Scaffold(
          appBar: AppBar(
            title: Text(document.title),
            actions: <Widget>[
              IconButton(
                key: const Key('detail_edit_button'),
                onPressed: () => _openEdit(context, document),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit / Recategorize',
              ),
              IconButton(
                key: const Key('detail_delete_button'),
                onPressed: () => _confirmDelete(context, document),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete document',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  height: 240,
                  color: Colors.grey.shade100,
                  child: hasLocalFile
                      ? InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Image.file(imageFile, fit: BoxFit.contain),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.insert_drive_file_outlined,
                                size: 48,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Local Path: ${document.originalPath}',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Metadata & Provenance',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Title', document.title),
                      _buildInfoRow('Category', document.category.displayName),
                      _buildInfoRow(
                        'Document Type',
                        document.documentType.displayName,
                      ),
                      if (document.assetName != null &&
                          document.assetName!.isNotEmpty)
                        _buildInfoRow('Asset / Subject', document.assetName!),
                      _buildInfoRow(
                        'Verification Status',
                        document.verificationStatus.wireName,
                      ),
                      _buildInfoRow('OCR Status', document.ocrStatus.wireName),
                      _buildInfoRow('SHA-256 Prefix', shortHash),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Verified Deadlines',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (deadlines.isEmpty)
                        const Text('No confirmed deadlines recorded.')
                      else
                        ...deadlines.map((deadline) {
                          final pageNum = deadline.page ?? 1;
                          String evidenceText =
                              'Confirmed manually (p.$pageNum)';
                          if (deadline.evidenceSnippet != null &&
                              deadline.evidenceSnippet!.isNotEmpty) {
                            evidenceText = 'Evidence (p.$pageNum): '
                                '"${deadline.evidenceSnippet}"';
                          }
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.event_available_outlined),
                            title: Text(
                              '${deadline.kind.displayName}: '
                              '${deadline.dateIso}',
                            ),
                            subtitle: Text(evidenceText),
                            trailing: OutlinedButton(
                              onPressed: () {
                                controller.scheduleReminderForDeadline(
                                  deadline,
                                );
                              },
                              child: const Text('Remind me'),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
