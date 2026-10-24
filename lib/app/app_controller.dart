import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/contracts/contracts.dart';
import '../features/action_guide/action_guide.dart';
import '../features/vault/vault.dart';
import 'default_services.dart';

/// Sort options for the Document Library (`VaultScreen`).
enum VaultSortOrder {
  newest('Newest First'),
  oldest('Oldest First'),
  approachingDeadline('Approaching Deadline');

  const VaultSortOrder(this.label);
  final String label;
}

/// Filter options for the Reminders view (`RemindersScreen`).
enum ReminderFilter {
  all('All Deadlines'),
  overdue('Overdue'),
  dueSoon('Due within 30d'),
  later('Upcoming Later');

  const ReminderFilter(this.label);
  final String label;
}

/// Summary of a household member or asset and its linked documents/deadlines.
class HouseholdEntitySummary {
  const HouseholdEntitySummary({
    required this.name,
    required this.kind,
    required this.documentCount,
    required this.upcomingDeadlineCount,
    this.nearestDeadlineIso,
  });

  final String name;
  final String kind; // 'member' or 'asset'
  final int documentCount;
  final int upcomingDeadlineCount;
  final String? nearestDeadlineIso;
}

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
    this.initialAssetName,
  });

  final String imagePath;
  final String sha256;
  final OcrStatus ocrStatus;
  final ExtractionResult extractionResult;
  final DocumentRecord? existingDocument;
  final List<DeadlineRecord> existingDeadlines;
  final String? ocrErrorMessage;
  final String? initialAssetName;
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
  bool get isDueSoon => daysRemaining >= 0 && daysRemaining <= 14;
  bool get isWithinNext30Days => daysRemaining >= 0 && daysRemaining <= 30;
}

/// Lightweight `ChangeNotifier` state management for LifeVault v0.1 / v0.2.
class LifeVaultController extends ChangeNotifier {
  LifeVaultController({
    required this.ocrService,
    required this.extractionService,
    required this.vaultRepository,
    required this.questionService,
    required this.reminderService,
    required this.captureDelegate,
    ActionGuideService? actionGuideService,
    DateTime Function()? nowProvider,
    this.isPersistentStorage = false,
  }) : actionGuideService = actionGuideService ?? HybridActionGuideService() {
    _nowProvider = nowProvider ?? DateTime.now;
    if (reminderService is ReminderServiceImpl) {
      (reminderService as ReminderServiceImpl)
          .setNotificationTapHandler(handleNotificationPayload);
    }
  }

  static const int maxImageBytes = 12 * 1024 * 1024;

  final OfflineOcrService ocrService;
  final DocumentExtractionService extractionService;
  final VaultRepository vaultRepository;
  final QuestionService questionService;
  final ReminderService reminderService;
  final ImageCaptureDelegate captureDelegate;
  final ActionGuideService actionGuideService;
  final bool isPersistentStorage;
  late final DateTime Function() _nowProvider;

  int _activeTabIndex = 0;
  bool _isLoadingVault = false;
  bool _isProcessingScan = false;
  int _scanOperationToken = 0;

  List<DocumentRecord> _allDocuments = <DocumentRecord>[];
  List<DocumentRecord> _filteredDocuments = <DocumentRecord>[];
  List<DeadlineRecord> _verifiedDeadlines = <DeadlineRecord>[];

  final Map<String, ActionPlaybook> _playbooksByDocId =
      <String, ActionPlaybook>{};
  final Set<String> _loadingPlaybookDocIds = <String>{};
  String? _pendingPlaybookDeepLinkDocId;

  String _vaultSearchQuery = '';
  DocumentCategory? _selectedCategoryFilter;
  String? _selectedAssetFilter;
  VaultSortOrder _vaultSortOrder = VaultSortOrder.newest;
  bool _isVaultGridView = false;

  ReminderFilter _reminderFilter = ReminderFilter.all;
  List<int> _defaultReminderOffsets = const <int>[30, 7, 1];
  final Set<String> _completedDeadlineIds = <String>{};

  final List<String> _customMembers = <String>['Primary Household'];
  final List<String> _customAssets = <String>[];

  ThemeMode _themeMode = ThemeMode.light;
  String? _lastServiceCheckSummary;

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
  String? get selectedAssetFilter => _selectedAssetFilter;
  VaultSortOrder get vaultSortOrder => _vaultSortOrder;
  bool get isVaultGridView => _isVaultGridView;

  ReminderFilter get reminderFilter => _reminderFilter;
  List<int> get defaultReminderOffsets => _defaultReminderOffsets;
  Set<String> get completedDeadlineIds => _completedDeadlineIds;

  ThemeMode get themeMode => _themeMode;
  String? get lastServiceCheckSummary => _lastServiceCheckSummary;

  PickedImageFile? get selectedScanFile => _selectedScanFile;
  DocumentRecord? get duplicateExistingDoc => _duplicateExistingDoc;
  String? get scanErrorMessage => _scanErrorMessage;
  String? get statusBannerMessage => _statusBannerMessage;

  String get lastQuestion => _lastQuestion;
  AnswerResult? get lastAnswerResult => _lastAnswerResult;
  bool get isAnswering => _isAnswering;

  String? get pendingPlaybookDeepLinkDocId => _pendingPlaybookDeepLinkDocId;

  DateTime get todayDateOnly {
    final now = _nowProvider();
    return DateTime(now.year, now.month, now.day);
  }

  List<DocumentRecord> get needsReviewDocuments {
    return _allDocuments.where((doc) {
      return !doc.verificationStatus.isUserVerified;
    }).toList();
  }

  List<DocumentRecord> get recentDocuments {
    final sorted = List<DocumentRecord>.from(_allDocuments)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(5).toList();
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

  int get expiringSoonCount {
    return dashboardDeadlineItems.where((item) {
      final isExpiryKind = item.deadline.kind == DeadlineKind.expiry ||
          item.document.category == DocumentCategory.insurance ||
          item.document.documentType == DocumentType.insurancePolicy ||
          item.document.documentType == DocumentType.warranty;
      return isExpiryKind && item.isWithinNext30Days;
    }).length;
  }

  List<DashboardDeadlineItem> get filteredReminderItems {
    final all = dashboardDeadlineItems;
    switch (_reminderFilter) {
      case ReminderFilter.overdue:
        return all.where((item) => item.isOverdue).toList();
      case ReminderFilter.dueSoon:
        return all.where((item) => item.isWithinNext30Days).toList();
      case ReminderFilter.later:
        return all.where((item) => item.daysRemaining > 30).toList();
      case ReminderFilter.all:
        return all;
    }
  }

  List<HouseholdEntitySummary> get householdMembers {
    return _customMembers.map((memberName) {
      final lower = memberName.toLowerCase();
      final matchingDocs = _allDocuments.where((doc) {
        final asset = doc.assetName?.toLowerCase() ?? '';
        final title = doc.title.toLowerCase();
        return asset == lower ||
            title.contains(lower) ||
            (memberName == 'Primary Household' &&
                (doc.assetName == null || doc.assetName!.isEmpty));
      }).toList();
      final docIds = matchingDocs.map((d) => d.id).toSet();
      final deadlines = dashboardDeadlineItems
          .where((item) => docIds.contains(item.document.id))
          .toList();
      return HouseholdEntitySummary(
        name: memberName,
        kind: 'member',
        documentCount: matchingDocs.length,
        upcomingDeadlineCount: deadlines.length,
        nearestDeadlineIso:
            deadlines.isNotEmpty ? deadlines.first.deadline.dateIso : null,
      );
    }).toList();
  }

  List<HouseholdEntitySummary> get householdAssets {
    final assetNames = <String>{..._customAssets};
    for (final doc in _allDocuments) {
      final trimmed = doc.assetName?.trim() ?? '';
      if (trimmed.isNotEmpty && !_customMembers.contains(trimmed)) {
        assetNames.add(trimmed);
      }
    }
    return assetNames.map((assetName) {
      final lower = assetName.toLowerCase();
      final matchingDocs = _allDocuments.where((doc) {
        return (doc.assetName?.trim().toLowerCase() ?? '') == lower;
      }).toList();
      final docIds = matchingDocs.map((d) => d.id).toSet();
      final deadlines = dashboardDeadlineItems
          .where((item) => docIds.contains(item.document.id))
          .toList();
      return HouseholdEntitySummary(
        name: assetName,
        kind: 'asset',
        documentCount: matchingDocs.length,
        upcomingDeadlineCount: deadlines.length,
        nearestDeadlineIso:
            deadlines.isNotEmpty ? deadlines.first.deadline.dateIso : null,
      );
    }).toList();
  }

  void setActiveTab(int index) {
    if (_activeTabIndex == index) {
      return;
    }
    _activeTabIndex = index;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
  }

  void setVaultSortOrder(VaultSortOrder order) {
    if (_vaultSortOrder == order) {
      return;
    }
    _vaultSortOrder = order;
    _sortFilteredDocumentsInPlace();
    notifyListeners();
  }

  void toggleVaultGridView(bool isGrid) {
    if (_isVaultGridView == isGrid) {
      return;
    }
    _isVaultGridView = isGrid;
    notifyListeners();
  }

  void setReminderFilter(ReminderFilter filter) {
    if (_reminderFilter == filter) {
      return;
    }
    _reminderFilter = filter;
    notifyListeners();
  }

  void setDefaultReminderOffsets(List<int> offsets) {
    if (offsets.isEmpty) {
      return;
    }
    _defaultReminderOffsets = List<int>.unmodifiable(offsets);
    _statusBannerMessage =
        'Default reminder schedule updated to ${offsets.join(", ")} days before deadline.';
    notifyListeners();
  }

  void toggleDeadlineCompleted(String deadlineId) {
    if (_completedDeadlineIds.contains(deadlineId)) {
      _completedDeadlineIds.remove(deadlineId);
    } else {
      _completedDeadlineIds.add(deadlineId);
    }
    notifyListeners();
  }

  void addHouseholdMember(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _customMembers.contains(trimmed)) {
      return;
    }
    _customMembers.add(trimmed);
    _statusBannerMessage = 'Added household member "$trimmed".';
    notifyListeners();
  }

  void addHouseholdAsset(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _customAssets.contains(trimmed)) {
      return;
    }
    _customAssets.add(trimmed);
    _statusBannerMessage = 'Added household asset "$trimmed".';
    notifyListeners();
  }

  Future<void> filterVaultByAsset(String? assetName) async {
    _selectedAssetFilter = assetName;
    await _applyVaultFilter();
    _activeTabIndex = 2;
    notifyListeners();
  }

  Future<void> checkLocalServices() async {
    await refreshVault();
    final storageLabel = isPersistentStorage
        ? 'SQLite App-Private Storage Ready'
        : 'Local Session Vault Ready';
    _lastServiceCheckSummary =
        '$storageLabel • Offline OCR Engine (eng.traineddata) Configured • '
        '${_allDocuments.length} document(s), ${_verifiedDeadlines.length} verified deadline(s).';
    _statusBannerMessage = _lastServiceCheckSummary;
    notifyListeners();
  }

  void clearStatusBanner() {
    if (_statusBannerMessage == null) {
      return;
    }
    _statusBannerMessage = null;
    notifyListeners();
  }

  /// Handles notification tap payloads formatted as
  /// `{"documentId": "<id>", "action": "open_playbook"}` (Phase 4).
  void handleNotificationPayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        final action = decoded['action'] as String?;
        final docId = decoded['documentId'] as String?;
        if (docId != null &&
            docId.isNotEmpty &&
            (action == null || action == 'open_playbook')) {
          _pendingPlaybookDeepLinkDocId = docId;
          notifyListeners();
        }
      }
    } on Object {
      // Ignore malformed payloads.
    }
  }

  /// Consumes and clears the pending notification deep-link target document ID.
  String? consumePendingPlaybookDeepLink() {
    final target = _pendingPlaybookDeepLinkDocId;
    _pendingPlaybookDeepLinkDocId = null;
    return target;
  }

  /// Returns the cached [ActionPlaybook] for [documentId], if already loaded.
  ActionPlaybook? playbookForDocument(String documentId) {
    return _playbooksByDocId[documentId];
  }

  /// True while an [ActionPlaybook] is being generated for [documentId].
  bool isLoadingPlaybook(String documentId) {
    return _loadingPlaybookDocIds.contains(documentId);
  }

  /// Generates and caches an [ActionPlaybook] for [documentId] if not yet loaded.
  Future<ActionPlaybook?> ensurePlaybookLoaded(
    String documentId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _playbooksByDocId.containsKey(documentId)) {
      return _playbooksByDocId[documentId];
    }
    if (_loadingPlaybookDocIds.contains(documentId)) {
      return _playbooksByDocId[documentId];
    }

    final doc = findLoadedDocumentById(documentId);
    if (doc == null) {
      return null;
    }

    _loadingPlaybookDocIds.add(documentId);
    notifyListeners();

    try {
      final docDeadlines = deadlinesForDocument(documentId);
      final primaryDeadline =
          docDeadlines.isNotEmpty ? docDeadlines.first : null;
      final playbook = await actionGuideService.generatePlaybook(
        document: doc,
        deadline: primaryDeadline,
        evidenceSnippet: primaryDeadline?.evidenceSnippet,
      );
      _playbooksByDocId[documentId] = playbook;
      return playbook;
    } finally {
      _loadingPlaybookDocIds.remove(documentId);
      notifyListeners();
    }
  }

  /// Toggles the `isCompleted` state of [stepId] in [documentId]'s playbook.
  void togglePlaybookStep(String documentId, String stepId) {
    final existing = _playbooksByDocId[documentId];
    if (existing == null) {
      return;
    }
    final updatedSteps = existing.steps.map((step) {
      if (step.id == stepId) {
        return step.copyWith(isCompleted: !step.isCompleted);
      }
      return step;
    }).toList();
    _playbooksByDocId[documentId] = existing.copyWith(steps: updatedSteps);
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
    var results = await vaultRepository.search(
      text: query.isEmpty ? null : query,
      category: _selectedCategoryFilter,
    );
    if (_selectedAssetFilter != null &&
        _selectedAssetFilter!.trim().isNotEmpty) {
      final targetAsset = _selectedAssetFilter!.trim().toLowerCase();
      results = results.where((doc) {
        final docAsset = doc.assetName?.trim().toLowerCase() ?? '';
        if (targetAsset == 'primary household') {
          return docAsset.isEmpty || docAsset == targetAsset;
        }
        return docAsset == targetAsset ||
            doc.title.toLowerCase().contains(targetAsset);
      }).toList();
    }
    _filteredDocuments = List<DocumentRecord>.from(results);
    _sortFilteredDocumentsInPlace();
  }

  void _sortFilteredDocumentsInPlace() {
    switch (_vaultSortOrder) {
      case VaultSortOrder.newest:
        _filteredDocuments.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case VaultSortOrder.oldest:
        _filteredDocuments.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      case VaultSortOrder.approachingDeadline:
        _filteredDocuments.sort((a, b) {
          final aDeadlines = deadlinesForDocument(a.id);
          final bDeadlines = deadlinesForDocument(b.id);
          final aDate =
              aDeadlines.isNotEmpty ? aDeadlines.first.dateIso : '9999-12-31';
          final bDate =
              bDeadlines.isNotEmpty ? bDeadlines.first.dateIso : '9999-12-31';
          return aDate.compareTo(bDate);
        });
    }
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

  PendingReviewDraft createManualEntryDraft({String? initialAssetName}) {
    final picked = _selectedScanFile;
    return PendingReviewDraft(
      imagePath: picked?.path ?? 'manual_entry_local',
      sha256:
          picked?.sha256 ?? 'manual_${_nowProvider().millisecondsSinceEpoch}',
      ocrStatus: OcrStatus.manual,
      extractionResult: const ExtractionResult(),
      initialAssetName: initialAssetName,
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
    if (existingDocumentId != null) {
      _playbooksByDocId.remove(existingDocumentId);
      await reminderService.cancelForDocument(existingDocumentId);
    }

    final saved = await vaultRepository.saveVerified(input);
    await refreshVault();
    await ensurePlaybookLoaded(saved.id, forceRefresh: true);

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
    _playbooksByDocId.remove(documentId);
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

  Future<void> askQuestionAndNavigate(String question) async {
    _activeTabIndex = 3;
    notifyListeners();
    await askQuestion(question);
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
