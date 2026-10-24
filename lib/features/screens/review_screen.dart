import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../core/contracts/contracts.dart';

/// Review & verification screen (Section 4: key conversion screen).
///
/// Renders a responsive split-screen on desktop (`>= 900px`) with the original
/// document preview on the left and editable metadata + candidate dates on the
/// right, and stacks panels vertically on mobile.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.controller,
    required this.draft,
  });

  final LifeVaultController controller;
  final PendingReviewDraft draft;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _assetController;
  late final TextEditingController _dateIsoController;
  late final TextEditingController _snippetController;

  late DocumentCategory _selectedCategory;
  late DocumentType _selectedType;
  late DeadlineKind _selectedDeadlineKind;
  int? _selectedCandidateIndex;
  String? _validationError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.draft.existingDocument;
    final extraction = widget.draft.extractionResult;

    _selectedCategory = existing?.category ?? extraction.suggestedCategory;
    _selectedType = existing?.documentType ?? extraction.suggestedType;

    final initialTitle =
        existing?.title ?? _defaultTitleFor(_selectedCategory, _selectedType);
    _titleController = TextEditingController(text: initialTitle);
    _assetController = TextEditingController(
      text: existing?.assetName ??
          widget.draft.initialAssetName ??
          extraction.assetNameSuggestion ??
          '',
    );

    String initialDate = '';
    String initialSnippet = '';
    DeadlineKind initialKind = _defaultDeadlineKindFor(_selectedType);

    if (widget.draft.existingDeadlines.isNotEmpty) {
      final firstDeadline = widget.draft.existingDeadlines.first;
      initialDate = firstDeadline.dateIso;
      initialSnippet = firstDeadline.evidenceSnippet ?? '';
      initialKind = firstDeadline.kind;
    } else {
      final candidates = extraction.dateCandidates;
      for (var i = 0; i < candidates.length; i++) {
        final candidate = candidates[i];
        if (candidate.fieldKind.isDeadlineCandidate &&
            !candidate.ambiguous &&
            candidate.isoDate != null) {
          _selectedCandidateIndex = i;
          initialDate = candidate.isoDate!;
          initialSnippet = candidate.sourceSnippet;
          initialKind = candidate.fieldKind == DateFieldKind.due
              ? DeadlineKind.billDue
              : DeadlineKind.expiry;
          break;
        }
      }
    }

    _selectedDeadlineKind = initialKind;
    _dateIsoController = TextEditingController(text: initialDate);
    _snippetController = TextEditingController(text: initialSnippet);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _assetController.dispose();
    _dateIsoController.dispose();
    _snippetController.dispose();
    super.dispose();
  }

  String _defaultTitleFor(DocumentCategory category, DocumentType type) {
    if (category == DocumentCategory.other && type == DocumentType.other) {
      return '';
    }
    return '${category.displayName} ${type.displayName}';
  }

  DeadlineKind _defaultDeadlineKindFor(DocumentType type) {
    if (type == DocumentType.bill || type == DocumentType.invoiceReceipt) {
      return DeadlineKind.billDue;
    }
    if (type == DocumentType.insurancePolicy || type == DocumentType.warranty) {
      return DeadlineKind.expiry;
    }
    return DeadlineKind.manual;
  }

  void _selectCandidate(int index, DateCandidate candidate) {
    setState(() {
      _selectedCandidateIndex = index;
      _dateIsoController.text = candidate.isoDate ?? '';
      _snippetController.text = candidate.sourceSnippet;
      if (candidate.fieldKind == DateFieldKind.due) {
        _selectedDeadlineKind = DeadlineKind.billDue;
      } else if (candidate.fieldKind == DateFieldKind.expiry) {
        _selectedDeadlineKind = DeadlineKind.expiry;
      }
      _validationError = null;
    });
  }

  bool _isValidIsoDate(String value) {
    final trimmed = value.trim();
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!regex.hasMatch(trimmed)) {
      return false;
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) {
      return false;
    }
    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    return '$y-$m-$d' == trimmed;
  }

  Future<void> _pickDateFromCalendar() async {
    final now = widget.controller.todayDateOnly;
    final initial = DateTime.tryParse(_dateIsoController.text.trim()) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    setState(() {
      _dateIsoController.text = '$y-$m-$d';
      _validationError = null;
    });
  }

  Future<void> _handleSave({required bool withDeadline}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _validationError = 'Please enter a document title before saving.';
      });
      return;
    }

    final dateIso = _dateIsoController.text.trim();
    if (withDeadline && !_isValidIsoDate(dateIso)) {
      setState(() {
        _validationError =
            'Enter or confirm a valid date in YYYY-MM-DD format, or choose '
            '"Save without deadline".';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _validationError = null;
    });

    try {
      final candidates = widget.draft.extractionResult.dateCandidates;
      DateCandidate? chosenCandidate;
      if (_selectedCandidateIndex != null &&
          _selectedCandidateIndex! >= 0 &&
          _selectedCandidateIndex! < candidates.length) {
        chosenCandidate = candidates[_selectedCandidateIndex!];
      }

      final deadlines = <VerifiedDeadlineInput>[];
      if (withDeadline) {
        final snippetText = _snippetController.text.trim();
        deadlines.add(
          VerifiedDeadlineInput(
            kind: _selectedDeadlineKind,
            dateIso: dateIso,
            evidenceSnippet: snippetText.isEmpty ? null : snippetText,
            proposedRaw: chosenCandidate?.rawText,
            proposedIso: chosenCandidate?.isoDate,
            page: chosenCandidate?.page ?? 1,
            provenance: chosenCandidate != null
                ? EvidenceProvenance.userConfirmed
                : EvidenceProvenance.manual,
            reminderOffsetsDays: widget.controller.defaultReminderOffsets,
          ),
        );
      }

      final verificationStatus = withDeadline
          ? VerificationStatus.verified
          : VerificationStatus.verifiedNoDeadline;

      final input = VerifiedDocumentInput(
        originalTempPath: widget.draft.imagePath,
        title: title,
        category: _selectedCategory,
        documentType: _selectedType,
        assetName: _assetController.text.trim(),
        sha256: widget.draft.sha256,
        ocrStatus: widget.draft.ocrStatus,
        verificationStatus: verificationStatus,
        verifiedDeadlines: deadlines,
      );

      await widget.controller.saveReviewedDocument(
        input,
        existingDocumentId: widget.draft.existingDocument?.id,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _validationError = 'Could not save document: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final extraction = widget.draft.extractionResult;
    final candidates = extraction.dateCandidates;
    final imageFile = File(widget.draft.imagePath);
    final hasLocalFile = !kIsWeb && imageFile.existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.draft.existingDocument != null
              ? 'Edit & Verify Document'
              : 'Review & Confirm',
        ),
      ),
      bottomNavigationBar: _buildActionButtons(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideDesktop = constraints.maxWidth >= 900;

          if (isWideDesktop) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: constraints.maxWidth * 0.42,
                    child: ListView(
                      children: <Widget>[
                        _buildImagePreviewCard(
                          imageFile,
                          hasLocalFile,
                          previewHeight: 360,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _buildRightPanelChildren(
                          extraction,
                          candidates,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildImagePreviewCard(
                  imageFile,
                  hasLocalFile,
                  previewHeight: 120,
                ),
                const SizedBox(height: 12),
                ..._buildRightPanelChildren(extraction, candidates),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildRightPanelChildren(
    ExtractionResult extraction,
    List<DateCandidate> candidates,
  ) {
    return <Widget>[
      if (widget.draft.ocrErrorMessage != null) ...<Widget>[
        _buildAlertBanner(
          icon: Icons.warning_amber_rounded,
          color: LifeVaultColors.warning,
          backgroundColor: LifeVaultColors.warningBackground,
          text: widget.draft.ocrErrorMessage!,
        ),
        const SizedBox(height: 12),
      ],
      if (_selectedCategory == DocumentCategory.medical) ...<Widget>[
        _buildAlertBanner(
          icon: Icons.privacy_tip_outlined,
          color: LifeVaultColors.primary,
          backgroundColor: LifeVaultColors.primaryLight,
          text: 'Medical records stay strictly on-device. '
              'Recognized dates are for organization only and are not '
              'medical advice.',
        ),
        const SizedBox(height: 12),
      ],
      if (_validationError != null) ...<Widget>[
        _buildAlertBanner(
          icon: Icons.error_outline,
          color: LifeVaultColors.danger,
          backgroundColor: LifeVaultColors.dangerBackground,
          text: _validationError!,
        ),
        const SizedBox(height: 12),
      ],
      _buildMetadataSection(extraction),
      const SizedBox(height: 16),
      _buildCandidatesSection(candidates),
      const SizedBox(height: 16),
      _buildConfirmedDeadlineSection(),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildImagePreviewCard(
    File imageFile,
    bool hasLocalFile, {
    double previewHeight = 180,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: previewHeight,
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
                          Icons.description_outlined,
                          size: 44,
                          color: LifeVaultColors.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Source: ${widget.draft.imagePath}',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                const Icon(Icons.zoom_in, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pinch to zoom original photo and verify extracted fields',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Chip(
                  label: Text('OCR: ${widget.draft.ocrStatus.wireName}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(ExtractionResult extraction) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Document Classification & Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (extraction.categoryEvidence != null &&
                extraction.categoryEvidence!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Suggested because: ${extraction.categoryEvidence}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: LifeVaultColors.textSecondary,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('review_title_field'),
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Document Title *',
                hintText: 'e.g., Bike Insurance Policy',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DocumentCategory>(
              key: const Key('review_category_dropdown'),
              // ignore: deprecated_member_use
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category (Where do I find it?)',
              ),
              items: DocumentCategory.values.map((category) {
                return DropdownMenuItem<DocumentCategory>(
                  value: category,
                  child: Text(category.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DocumentType>(
              key: const Key('review_type_dropdown'),
              // ignore: deprecated_member_use
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Document Type (What kind of document?)',
              ),
              items: DocumentType.values.map((type) {
                return DropdownMenuItem<DocumentType>(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('review_asset_field'),
              controller: _assetController,
              decoration: const InputDecoration(
                labelText: 'Asset / Household Member (Optional)',
                hintText: 'e.g., Bike, Fridge, Home Electricity',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidatesSection(List<DateCandidate> candidates) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Recognized Date Candidates (Proposed / Unverified)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            if (candidates.isEmpty)
              const Text(
                'No automatic date candidates found. You can enter a deadline '
                'manually below or save without a deadline.',
              )
            else
              ...List<Widget>.generate(candidates.length, (index) {
                final candidate = candidates[index];
                final isSelected = _selectedCandidateIndex == index;
                final isDeadlineKind = candidate.fieldKind.isDeadlineCandidate;
                final statusLabel = candidate.ambiguous
                    ? 'AMBIGUOUS'
                    : (candidate.isDerived ? 'DERIVED PROPOSAL' : 'PROPOSED');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : LifeVaultColors.surfaceSecondary,
                    child: ListTile(
                      key: Key('date_candidate_$index'),
                      onTap: () => _selectCandidate(index, candidate),
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: LifeVaultColors.primary,
                      ),
                      title: Text(
                        '${candidate.fieldKind.wireName.toUpperCase()}: '
                        '${candidate.isoDate ?? candidate.rawText}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Snippet: "${candidate.sourceSnippet}"'),
                          Text(
                            'Status: $statusLabel • '
                            'Confidence: ${candidate.confidenceLevel.wireName}'
                            '${isDeadlineKind ? '' : ' (Non-deadline date)'}',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmedDeadlineSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Confirmed Deadline (Creates Local Reminder)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DeadlineKind>(
              key: const Key('review_deadline_kind_dropdown'),
              // ignore: deprecated_member_use
              value: _selectedDeadlineKind,
              decoration: const InputDecoration(
                labelText: 'Deadline Type',
              ),
              items: DeadlineKind.values.map((kind) {
                return DropdownMenuItem<DeadlineKind>(
                  value: kind,
                  child: Text(kind.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedDeadlineKind = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('review_date_iso_field'),
                    controller: _dateIsoController,
                    decoration: const InputDecoration(
                      labelText: 'Confirmed Date (YYYY-MM-DD)',
                      hintText: '2026-12-31',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  key: const Key('review_pick_date_button'),
                  onPressed: _pickDateFromCalendar,
                  icon: const Icon(Icons.calendar_month_outlined),
                  tooltip: 'Pick date from calendar',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('review_snippet_field'),
              controller: _snippetController,
              decoration: const InputDecoration(
                labelText: 'Supporting Evidence Snippet (Optional)',
                hintText: 'e.g., Policy Valid Upto 31/12/2026',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: LifeVaultColors.surface,
        border: Border(top: BorderSide(color: LifeVaultColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            TextButton.icon(
              key: const Key('retry_scan_button'),
              onPressed:
                  _isSaving ? null : () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry scan'),
            ),
            OutlinedButton.icon(
              key: const Key('save_without_deadline_button'),
              onPressed:
                  _isSaving ? null : () => _handleSave(withDeadline: false),
              icon: const Icon(Icons.bookmark_border, size: 18),
              label: const Text('Save without deadline'),
            ),
            FilledButton.icon(
              key: const Key('confirm_and_save_button'),
              onPressed:
                  _isSaving ? null : () => _handleSave(withDeadline: true),
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Confirm & Save'),
            ),
          ],
        ),
      ),
    );
  }
}
