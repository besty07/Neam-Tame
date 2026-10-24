import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/contracts/contracts.dart';
import '../features/vault/vault.dart';
import 'default_services.dart';

/// Draft state passed into `ReviewScreen` from `ScanScreen` or from an
/// existing `DocumentRecord` edit action.
class PendingReviewDraft {
  const PendingReviewDraft({
    required this.imagePath,
    required this.sha256,
    required this.ocrStatus,
    required this.extractionResult,
    this.existingDocument,
    this.existingDeadlines = const <DeadlineRecord>[],
    this.ocrErrorMessage,
  });

  final String imagePath;
  final String sha256;
  final OcrStatus ocrStatus;
  final ExtractionResult extractionResult;
  final DocumentRecord? existingDocument;
  final List<DeadlineRecord> existingDeadlines;
  final String? ocrErrorMessage;
}

/// View-model item pairing a verified [DeadlineRecord] with its parent
/// [DocumentRecord] and computed days remaining relative to local date.
class DashboardDeadlineItem {
  const DashboardDeadlineItem({
    required this.deadline,
    required this.document,
    required this.daysRemaining,
  });

  final DeadlineRecord deadline;
  final DocumentRecord document;
  final int daysRemaining;

  bool get isOverdue => daysRemaining < 0;
  bool get isWithinNext30Days => daysRemaining >= 0 && daysRemaining <= 30;
}

/// Lightweight `ChangeNotifier` state management for LifeVault v0.1 (D4.3).
class LifeVaultController extends ChangeNotifier {
  LifeVaultController({
    required this.ocrService,
    required this.extractionService,
    required this.vaultRepository,
    required this.questionService,
    required this.reminderService,
    required this.captureDelegate,
    DateTime Function()? nowProvider,
  }) {
    _nowProvider = nowProvider ?? DateTime.now;
  }

  static const int maxImageBytes = 12 * 1024 * 1024;

  // Minimal valid 1x1 PNG used when a manual entry is saved without a photo.
  static const List<int> _manualPlaceholderPng = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ];

  final OfflineOcrService ocrService;
  final DocumentExtractionService extractionService;
  final VaultRepository vaultRepository;
  final QuestionService questionService;
  final ReminderService reminderService;
  final ImageCaptureDelegate captureDelegate;
  late final DateTime Function() _nowProvider;

  int _activeTabIndex = 0;
  bool _isLoadingVault = false;
  bool _isProcessingScan = false;
  int _scanOperationToken = 0;

  List<DocumentRecord> _allDocuments = <DocumentRecord>[];
  List<DocumentRecord> _filteredDocuments = <DocumentRecord>[];
  List<DeadlineRecord> _verifiedDeadlines = <DeadlineRecord>[];

  String _vaultSearchQuery = '';
  DocumentCategory? _selectedCategoryFilter;

  PickedImageFile? _selectedScanFile;
  DocumentRecord? _duplicateExistingDoc;
  String? _scanErrorMessage;
  String? _statusBannerMessage;

  String _lastQuestion = '';
  AnswerResult? _lastAnswerResult;
  bool _isAnswering = false;

  int get activeTabIndex => _activeTabIndex;
  bool get isLoadingVault => _isLoadingVault;
  bool get isProcessingScan => _isProcessingScan;

  List<DocumentRecord> get allDocuments => _allDocuments;
  List<DocumentRecord> get filteredDocuments => _filteredDocuments;
  List<DeadlineRecord> get verifiedDeadlines => _verifiedDeadlines;

  String get vaultSearchQuery => _vaultSearchQuery;
  DocumentCategory? get selectedCategoryFilter => _selectedCategoryFilter;

  PickedImageFile? get selectedScanFile => _selectedScanFile;
  DocumentRecord? get duplicateExistingDoc => _duplicateExistingDoc;
  String? get scanErrorMessage => _scanErrorMessage;
  String? get statusBannerMessage => _statusBannerMessage;

  String get lastQuestion => _lastQuestion;
  AnswerResult? get lastAnswerResult => _lastAnswerResult;
  bool get isAnswering => _isAnswering;

  DateTime get todayDateOnly {
    final now = _nowProvider();
    return DateTime(now.year, now.month, now.day);
  }

  List<DocumentRecord> get needsReviewDocuments {
    return _allDocuments.where((doc) {
      return !doc.verificationStatus.isUserVerified;
    }).toList();
  }

  List<DashboardDeadlineItem> get dashboardDeadlineItems {
    final docById = <String, DocumentRecord>{
      for (final doc in _allDocuments) doc.id: doc,
    };
    final today = todayDateOnly;
    final items = <DashboardDeadlineItem>[];

    for (final deadline in _verifiedDeadlines) {
      if (!deadline.isVerified) {
        continue;
      }
      final doc = docById[deadline.documentId];
      if (doc == null) {
        continue;
      }
      final parsed = DateTime.tryParse(deadline.dateIso);
      if (parsed == null) {
        continue;
      }
      final dueDate = DateTime(parsed.year, parsed.month, parsed.day);
      final diffDays = dueDate.difference(today).inDays;
      items.add(
        DashboardDeadlineItem(
          deadline: deadline,
          document: doc,
          daysRemaining: diffDays,
        ),
      );
    }

    items.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return items;
  }

  List<DashboardDeadlineItem> get overdueItems {
    return dashboardDeadlineItems.where((item) => item.isOverdue).toList();
  }

  List<DashboardDeadlineItem> get upcomingItems {
    return dashboardDeadlineItems.where((item) => !item.isOverdue).toList();
  }

  int get next30DaysCount {
    return dashboardDeadlineItems
        .where((item) => item.isWithinNext30Days)
        .length;
  }

  void setActiveTab(int index) {
    if (_activeTabIndex == index) {
      return;
    }
    _activeTabIndex = index;
    notifyListeners();
  }

  void clearStatusBanner() {
    if (_statusBannerMessage == null) {
      return;
    }
    _statusBannerMessage = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    await refreshVault();
    final lostFile = await captureDelegate.retrieveLostImage();
    if (lostFile != null) {
      await _handlePickedImage(lostFile);
      _activeTabIndex = 1;
      notifyListeners();
    }
  }

  Future<void> refreshVault() async {
    _isLoadingVault = true;
    notifyListeners();
    try {
      _allDocuments = await vaultRepository.search();
      _verifiedDeadlines = await vaultRepository.getDeadlines(
        verifiedOnly: true,
      );
      await _applyVaultFilter();
    } finally {
      _isLoadingVault = false;
      notifyListeners();
    }
  }

  Future<void> setVaultSearchQuery(String query) async {
    _vaultSearchQuery = query;
    await _applyVaultFilter();
    notifyListeners();
  }

  Future<void> setCategoryFilter(DocumentCategory? category) async {
    _selectedCategoryFilter = category;
    await _applyVaultFilter();
    notifyListeners();
  }

  Future<void> _applyVaultFilter() async {
    final query = _vaultSearchQuery.trim();
    _filteredDocuments = await vaultRepository.search(
      text: query.isEmpty ? null : query,
      category: _selectedCategoryFilter,
    );
  }

  Future<void> pickFromCamera() async {
    _scanErrorMessage = null;
    notifyListeners();
    try {
      final picked = await captureDelegate.pickFromCamera();
      if (picked == null) {
        return;
      }
      await _handlePickedImage(picked);
    } on Object catch (error) {
      _scanErrorMessage = 'Camera capture unavailable ($error). '
          'You can choose from gallery or enter details manually.';
      notifyListeners();
    }
  }

  Future<void> pickFromGallery() async {
    _scanErrorMessage = null;
    notifyListeners();
    try {
      final picked = await captureDelegate.pickFromGallery();
      if (picked == null) {
        return;
      }
      await _handlePickedImage(picked);
    } on Object catch (error) {
      _scanErrorMessage = 'Gallery selection failed ($error). '
          'You can retry or enter details manually.';
      notifyListeners();
    }
  }

  Future<void> _handlePickedImage(PickedImageFile picked) async {
    if (picked.byteLength <= 0) {
      _selectedScanFile = null;
      _duplicateExistingDoc = null;
      _scanErrorMessage =
          'Selected image file is empty or unreadable. Please try another '
          'photo or continue with manual entry.';
      notifyListeners();
      return;
    }
    if (picked.byteLength > maxImageBytes) {
      _selectedScanFile = null;
      _duplicateExistingDoc = null;
      _scanErrorMessage =
          'Image exceeds the 12 MB limit. Please capture or choose a smaller '
          'photo.';
      notifyListeners();
      return;
    }

    _selectedScanFile = picked;
    _scanErrorMessage = null;
    _duplicateExistingDoc = await vaultRepository.findDocumentBySha256(
      picked.sha256,
    );
    notifyListeners();
  }

  void clearSelectedScanFile() {
    _scanOperationToken++;
    _isProcessingScan = false;
    _selectedScanFile = null;
    _duplicateExistingDoc = null;
    _scanErrorMessage = null;
    notifyListeners();
  }

  void cancelScanProcessing() {
    if (!_isProcessingScan) {
      return;
    }
    _scanOperationToken++;
    _isProcessingScan = false;
    _scanErrorMessage = 'Scan processing cancelled.';
    notifyListeners();
  }

  Future<PendingReviewDraft?> processSelectedImage() async {
    final file = _selectedScanFile;
    if (file == null) {
      _scanErrorMessage = 'Select or capture a photo first.';
      notifyListeners();
      return null;
    }

    final currentToken = ++_scanOperationToken;
    _isProcessingScan = true;
    _scanErrorMessage = null;
    notifyListeners();

    try {
      final ocrOutput = await ocrService.recognizeImage(file.path);
      if (currentToken != _scanOperationToken) {
        return null;
      }

      if (!ocrOutput.isSuccess || ocrOutput.text.trim().isEmpty) {
        final fallbackNotice = ocrOutput.errorMessage ??
            'No printed text recognized. Enter fields manually in Review.';
        _isProcessingScan = false;
        notifyListeners();
        return PendingReviewDraft(
          imagePath: file.path,
          sha256: file.sha256,
          ocrStatus: OcrStatus.failed,
          extractionResult: const ExtractionResult(),
          ocrErrorMessage: fallbackNotice,
        );
      }

      final extraction = extractionService.extract(ocrOutput.text);
      _isProcessingScan = false;
      notifyListeners();
      return PendingReviewDraft(
        imagePath: file.path,
        sha256: file.sha256,
        ocrStatus: OcrStatus.success,
        extractionResult: extraction,
      );
    } on Object catch (error) {
      if (currentToken != _scanOperationToken) {
        return null;
      }
      _isProcessingScan = false;
      notifyListeners();
      return PendingReviewDraft(
        imagePath: file.path,
        sha256: file.sha256,
        ocrStatus: OcrStatus.failed,
        extractionResult: const ExtractionResult(),
        ocrErrorMessage:
            'OCR error ($error). You can enter title, category, and date '
            'manually.',
      );
    }
  }

  PendingReviewDraft createManualEntryDraft() {
    final picked = _selectedScanFile;
    final stamp = _nowProvider().microsecondsSinceEpoch;
    return PendingReviewDraft(
      imagePath: picked?.path ?? 'manual_entry_$stamp.png',
      sha256: picked?.sha256 ?? 'manual_sha256_$stamp',
      ocrStatus: OcrStatus.manual,
      extractionResult: const ExtractionResult(),
    );
  }

  PendingReviewDraft createEditDraft(DocumentRecord document) {
    final docDeadlines =
        _verifiedDeadlines.where((d) => d.documentId == document.id).toList();
    return PendingReviewDraft(
      imagePath: document.originalPath,
      sha256: document.sha256,
      ocrStatus: document.ocrStatus,
      extractionResult: ExtractionResult(
        suggestedCategory: document.category,
        suggestedType: document.documentType,
        assetNameSuggestion: document.assetName,
      ),
      existingDocument: document,
      existingDeadlines: docDeadlines,
    );
  }

  Future<DocumentRecord> saveReviewedDocument(
    VerifiedDocumentInput input, {
    String? existingDocumentId,
  }) async {
    File? tempStagedFile;
    String effectiveTempPath = input.originalTempPath;

    try {
      final originalFile = File(input.originalTempPath);
      if (existingDocumentId != null) {
        await reminderService.cancelForDocument(existingDocumentId);
        if (originalFile.existsSync()) {
          final stagedPath =
              '${Directory.systemTemp.path}/lv_edit_$existingDocumentId.jpg';
          tempStagedFile = await originalFile.copy(stagedPath);
          effectiveTempPath = tempStagedFile.path;
        }
        await vaultRepository.deleteDocument(existingDocumentId);
      }

      if (vaultRepository is VaultRepositoryImpl &&
          !File(effectiveTempPath).existsSync()) {
        final stamp = _nowProvider().microsecondsSinceEpoch;
        final fallbackPath =
            '${Directory.systemTemp.path}/lv_manual_$stamp.png';
        tempStagedFile = File(fallbackPath);
        await tempStagedFile.writeAsBytes(_manualPlaceholderPng, flush: true);
        effectiveTempPath = tempStagedFile.path;
      }

      String? effectiveSha256 = input.sha256;
      if (vaultRepository is VaultRepositoryImpl &&
          effectiveSha256 != null &&
          existingDocumentId == null) {
        final duplicate = await vaultRepository.findDocumentBySha256(
          effectiveSha256,
        );
        if (duplicate != null) {
          final stamp = _nowProvider().microsecondsSinceEpoch;
          effectiveSha256 = '${effectiveSha256}_copy_$stamp';
        }
      }

      final normalizedInput = VerifiedDocumentInput(
        originalTempPath: effectiveTempPath,
        title: input.title,
        category: input.category,
        documentType: input.documentType,
        assetName: input.assetName,
        tags: input.tags,
        sha256: effectiveSha256,
        ocrStatus: input.ocrStatus,
        verificationStatus: input.verificationStatus,
        verifiedDeadlines: input.verifiedDeadlines,
        evidenceRecords: input.evidenceRecords,
      );

      final saved = await vaultRepository.saveVerified(normalizedInput);
      await refreshVault();

      final savedDeadlines = _verifiedDeadlines
          .where((d) => d.documentId == saved.id && d.isVerified)
          .toList();

      if (savedDeadlines.isNotEmpty) {
        final scheduleResult = await reminderService.schedule(
          savedDeadlines.first,
        );
        if (!scheduleResult.permissionGranted) {
          _statusBannerMessage = scheduleResult.statusMessage ??
              'Saved to vault. Android notification permission is denied, so '
                  'check the Home dashboard for deadline alerts.';
        } else {
          _statusBannerMessage = scheduleResult.statusMessage ??
              'Document and verified deadline reminder saved locally.';
        }
      } else {
        _statusBannerMessage = 'Document saved locally without a deadline.';
      }

      _selectedScanFile = null;
      _duplicateExistingDoc = null;
      _scanErrorMessage = null;
      notifyListeners();
      return saved;
    } finally {
      if (tempStagedFile != null && tempStagedFile.existsSync()) {
        try {
          tempStagedFile.deleteSync();
        } on Object {
          // Ignore temporary file cleanup errors.
        }
      }
    }
  }

  Future<ReminderScheduleResult> scheduleReminderForDeadline(
    DeadlineRecord deadline,
  ) async {
    final result = await reminderService.schedule(deadline);
    if (!result.permissionGranted) {
      _statusBannerMessage = result.statusMessage ??
          'Notification permission denied by Android. Deadline remains '
              'tracked on Home dashboard.';
    } else {
      _statusBannerMessage = result.statusMessage ??
          'Local notification scheduled for ${deadline.dateIso}.';
    }
    notifyListeners();
    return result;
  }

  Future<void> deleteDocument(String documentId) async {
    await reminderService.cancelForDocument(documentId);
    await vaultRepository.deleteDocument(documentId);
    _statusBannerMessage = 'Document and associated reminders removed.';
    await refreshVault();
  }

  Future<void> askQuestion(String question) async {
    _lastQuestion = question.trim();
    _isAnswering = true;
    notifyListeners();
    try {
      _lastAnswerResult = await questionService.answer(_lastQuestion);
    } finally {
      _isAnswering = false;
      notifyListeners();
    }
  }

  DocumentRecord? findLoadedDocumentById(String id) {
    for (final doc in _allDocuments) {
      if (doc.id == id) {
        return doc;
      }
    }
    return null;
  }

  List<DeadlineRecord> deadlinesForDocument(String documentId) {
    return _verifiedDeadlines.where((d) => d.documentId == documentId).toList();
  }
}
