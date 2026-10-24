import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../core/contracts/contracts.dart';
import 'review_screen.dart';

/// Document detail view displaying original image, metadata, verified
/// deadlines, masked SHA-256 provenance, edit/recategorize action, and delete
/// confirmation (P0 spec).
class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({
    super.key,
    required this.controller,
    required this.documentId,
  });

  final LifeVaultController controller;
  final String documentId;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  bool _revealFullHash = false;

  Future<void> _openEdit(BuildContext context, DocumentRecord document) async {
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

    await widget.controller.deleteDocument(document.id);
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final document = widget.controller.findLoadedDocumentById(
          widget.documentId,
        );
        if (document == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Document Detail')),
            body: const Center(
              child: Text('Document was deleted or is no longer available.'),
            ),
          );
        }

        final deadlines = widget.controller.deadlinesForDocument(document.id);
        final imageFile = File(document.originalPath);
        final hasLocalFile = !kIsWeb && imageFile.existsSync();
        final shortHash = document.sha256.length > 12
            ? '${document.sha256.substring(0, 8)}••••'
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
                  color: LifeVaultColors.surfaceSecondary,
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
                                color: LifeVaultColors.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Local Vault Copy (${document.ocrStatus.wireName})',
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
                        'Document Overview & Provenance',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
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
                      Row(
                        children: <Widget>[
                          const SizedBox(
                            width: 140,
                            child: Text(
                              'SHA-256 Digest',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _revealFullHash ? document.sha256 : shortHash,
                            ),
                          ),
                          TextButton(
                            key: const Key('detail_toggle_hash_mask'),
                            onPressed: () {
                              setState(() {
                                _revealFullHash = !_revealFullHash;
                              });
                            },
                            child: Text(_revealFullHash ? 'Mask' : 'Reveal'),
                          ),
                        ],
                      ),
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
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Important Dates & Reminders',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _openEdit(context, document),
                            icon: const Icon(Icons.edit_calendar_outlined),
                            label: Text(
                              deadlines.isEmpty ? 'Add Date' : 'Edit Date',
                            ),
                          ),
                        ],
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
                            leading: const Icon(
                              Icons.event_available_outlined,
                              color: LifeVaultColors.primary,
                            ),
                            title: Text(
                              '${deadline.kind.displayName}: '
                              '${deadline.dateIso}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(evidenceText),
                            trailing: OutlinedButton(
                              onPressed: () {
                                widget.controller.scheduleReminderForDeadline(
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
