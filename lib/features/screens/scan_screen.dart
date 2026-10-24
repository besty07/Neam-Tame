import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/default_services.dart';
import '../../app/theme.dart';
import '../../core/contracts/contracts.dart';
import 'document_detail_screen.dart';
import 'review_screen.dart';

/// Offline Scan screen supporting camera capture, gallery import, duplicate
/// SHA-256 detection, optional Gemma 3n E4B Vision extraction, cancellable OCR
/// processing, and manual entry fallback.
class ScanScreen extends StatelessWidget {
  const ScanScreen({
    super.key,
    required this.controller,
  });

  final LifeVaultController controller;

  Future<void> _processAndOpenReview(BuildContext context) async {
    final draft = await controller.processSelectedImage();
    if (draft == null || !context.mounted) {
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ReviewScreen(
          controller: controller,
          draft: draft,
        ),
      ),
    );
    if (saved == true && context.mounted) {
      controller.setActiveTab(0);
    }
  }

  Future<void> _openManualReview(BuildContext context) async {
    final draft = controller.createManualEntryDraft();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ReviewScreen(
          controller: controller,
          draft: draft,
        ),
      ),
    );
    if (saved == true && context.mounted) {
      controller.setActiveTab(0);
    }
  }

  Future<void> _openDuplicateDoc(
    BuildContext context,
    DocumentRecord duplicate,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => DocumentDetailScreen(
          controller: controller,
          documentId: duplicate.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFile = controller.selectedScanFile;
    final duplicateDoc = controller.duplicateExistingDoc;
    final errorMessage = controller.scanErrorMessage;
    final isProcessing = controller.isProcessingScan;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Add a Document',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                    Chip(
                      key: const Key('scan_vision_model_badge'),
                      avatar: Icon(
                        controller.visionModelStatus.available
                            ? Icons.auto_awesome_outlined
                            : Icons.document_scanner_outlined,
                        size: 16,
                      ),
                      label: Text(controller.visionModelState.displayName),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'All OCR, Gemma 3n Vision candidate extraction, and date '
                  'parsing happen offline on your Android device. Nothing is uploaded.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: LifeVaultColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('scan_take_photo_button'),
                        onPressed:
                            isProcessing ? null : controller.pickFromCamera,
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Take Photo'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('scan_choose_gallery_button'),
                        onPressed:
                            isProcessing ? null : controller.pickFromGallery,
                        icon:
                            const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Choose from Gallery'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  key: const Key('scan_manual_entry_button'),
                  onPressed:
                      isProcessing ? null : () => _openManualReview(context),
                  icon: const Icon(Icons.edit_note_outlined, size: 18),
                  label: const Text('Enter Details Manually (OCR Fallback)'),
                ),
              ],
            ),
          ),
        ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          Card(
            color: LifeVaultColors.dangerBackground,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline,
                    color: LifeVaultColors.danger,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: LifeVaultColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (duplicateDoc != null) ...<Widget>[
          const SizedBox(height: 10),
          _buildDuplicateBanner(context, duplicateDoc),
        ],
        if (isProcessing) ...<Widget>[
          const SizedBox(height: 10),
          _buildProcessingStateCard(context),
        ] else if (selectedFile != null) ...<Widget>[
          const SizedBox(height: 10),
          _buildSelectedPreviewCard(context, selectedFile),
        ],
      ],
    );
  }

  Widget _buildDuplicateBanner(
    BuildContext context,
    DocumentRecord duplicate,
  ) {
    return Card(
      color: LifeVaultColors.warningBackground,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.copy_all_outlined, color: LifeVaultColors.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Duplicate Photo Detected (Matching SHA-256)',
                    style: TextStyle(
                      color: LifeVaultColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'This image matches "${duplicate.title}" '
              '(${duplicate.category.displayName}). You can open the existing '
              'record or continue to save another labeled copy.',
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              key: const Key('scan_open_duplicate_button'),
              onPressed: () => _openDuplicateDoc(context, duplicate),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Existing Document'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingStateCard(BuildContext context) {
    return Card(
      key: const Key('scan_processing_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              controller.visionModelState == VisionModelState.analyzing
                  ? 'Analyzing Document Image with Gemma 3n E4B...'
                  : 'Running Offline OCR & Date Extraction...',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              controller.visionModelState == VisionModelState.analyzing
                  ? 'Extracting candidate fields locally on-device.'
                  : 'Recognizing printed English text locally using Tesseract.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('scan_cancel_button'),
              onPressed: controller.cancelScanProcessing,
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPreviewCard(
    BuildContext context,
    PickedImageFile pickedFile,
  ) {
    final file = File(pickedFile.path);
    final exists = !kIsWeb && file.existsSync();
    final kb = (pickedFile.byteLength / 1024).toStringAsFixed(1);
    final shortSha = pickedFile.sha256.length > 12
        ? pickedFile.sha256.substring(0, 12)
        : pickedFile.sha256;

    return Card(
      key: const Key('scan_preview_card'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 84,
            color: LifeVaultColors.surfaceSecondary,
            child: exists
                ? Image.file(file, fit: BoxFit.contain)
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.image_outlined,
                          size: 28,
                          color: LifeVaultColors.primary,
                        ),
                        const SizedBox(height: 4),
                        Text('Selected: ${pickedFile.path}'),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'File size: $kb KB • SHA-256: $shortSha...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('scan_process_button'),
                  onPressed: () => _processAndOpenReview(context),
                  icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                  label: const Text('Process Document'),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  key: const Key('scan_retake_button'),
                  onPressed: controller.clearSelectedScanFile,
                  icon: const Icon(Icons.replay_outlined, size: 18),
                  label: const Text('Retake / Choose Another'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
