import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/contracts/contracts.dart';

/// Review & verification screen (Section 4: key conversion screen).
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
      text: existing?.assetName ?? extraction.assetNameSuggestion ?? '',
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
    final hasLocalFile = imageFile.existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.draft.existingDocument != null
              ? 'Edit & Verify Document'
              : 'Review & Confirm',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildImagePreviewCard(imageFile, hasLocalFile),
          const SizedBox(height: 12),
          if (widget.draft.ocrErrorMessage != null) ...<Widget>[
            _buildAlertBanner(
              icon: Icons.warning_amber_rounded,
              color: Colors.orange.shade800,
              backgroundColor: Colors.orange.shade50,
              text: widget.draft.ocrErrorMessage!,
            ),
            const SizedBox(height: 12),
          ],
          if (_selectedCategory == DocumentCategory.medical) ...<Widget>[
            _buildAlertBanner(
              icon: Icons.privacy_tip_outlined,
              color: Colors.teal.shade900,
              backgroundColor: Colors.teal.shade50,
              text: 'Medical records stay strictly on-device. '
                  'Recognized dates are for organization only and are not '
                  'medical advice.',
            ),
            const SizedBox(height: 12),
          ],
          if (_validationError != null) ...<Widget>[
            _buildAlertBanner(
              icon: Icons.error_outline,
              color: Colors.red.shade900,
              backgroundColor: Colors.red.shade50,
              text: _validationError!,
            ),
            const SizedBox(height: 12),
          ],
          _buildMetadataSection(extraction),
          const SizedBox(height: 16),
          _buildCandidatesSection(candidates),
          const SizedBox(height: 16),
          _buildConfirmedDeadlineSection(),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildImagePreviewCard(File imageFile, bool hasLocalFile) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 180,
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
                          Icons.description_outlined,
                          size: 44,
                          color: Colors.blueGrey,
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (extraction.categoryEvidence != null &&
                extraction.categoryEvidence!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Suggested because: ${extraction.categoryEvidence}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('review_title_field'),
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Document Title *',
                hintText: 'e.g., Bike Insurance Policy',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DocumentCategory>(
              key: const Key('review_category_dropdown'),
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category (Where do I find it?)',
                border: OutlineInputBorder(),
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
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Document Type (What kind of document?)',
                border: OutlineInputBorder(),
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
                labelText: 'Asset / Subject Name (Optional)',
                hintText: 'e.g., Bike, Fridge, Home Electricity',
                border: OutlineInputBorder(),
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
              style: Theme.of(context).textTheme.titleMedium,
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

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    key: Key('date_candidate_$index'),
                    onTap: () => _selectCandidate(index, candidate),
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(
                      '${candidate.fieldKind.wireName.toUpperCase()}: '
                      '${candidate.isoDate ?? candidate.rawText}',
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DeadlineKind>(
              key: const Key('review_deadline_kind_dropdown'),
              value: _selectedDeadlineKind,
              decoration: const InputDecoration(
                labelText: 'Deadline Type',
                border: OutlineInputBorder(),
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
                      border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          key: const Key('confirm_and_save_button'),
          onPressed: _isSaving ? null : () => _handleSave(withDeadline: true),
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Confirm & Save'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('save_without_deadline_button'),
          onPressed: _isSaving ? null : () => _handleSave(withDeadline: false),
          icon: const Icon(Icons.bookmark_border),
          label: const Text('Save without deadline'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('retry_scan_button'),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry scan'),
        ),
      ],
    );
  }
}
