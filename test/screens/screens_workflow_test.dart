import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifevault/app/boot.dart';
import 'package:lifevault/app/default_services.dart';
import 'package:lifevault/core/contracts/contracts.dart';

class _TestCaptureDelegate implements ImageCaptureDelegate {
  _TestCaptureDelegate({this.nextCameraFile, this.nextGalleryFile});

  PickedImageFile? nextCameraFile;
  PickedImageFile? nextGalleryFile;

  @override
  Future<PickedImageFile?> pickFromCamera() async => nextCameraFile;

  @override
  Future<PickedImageFile?> pickFromGallery() async => nextGalleryFile;

  @override
  Future<PickedImageFile?> retrieveLostImage() async => null;
}

class _TestOcrService implements OfflineOcrService {
  _TestOcrService(this.output);

  final OcrOutput output;

  @override
  Future<OcrOutput> recognizeImage(
    String localImagePath, {
    String language = 'eng',
  }) async {
    return output;
  }
}

class _TestExtractionService implements DocumentExtractionService {
  _TestExtractionService(this.result);

  final ExtractionResult result;

  @override
  ExtractionResult extract(String ocrText) => result;
}

class _TestReminderService implements ReminderService {
  _TestReminderService({this.permissionGranted = true});

  final bool permissionGranted;
  final List<DeadlineRecord> scheduledDeadlines = <DeadlineRecord>[];
  final List<String> cancelledDocumentIds = <String>[];

  @override
  Future<ReminderScheduleResult> schedule(DeadlineRecord deadline) async {
    scheduledDeadlines.add(deadline);
    if (!permissionGranted) {
      return const ReminderScheduleResult(
        scheduled: false,
        permissionGranted: false,
        statusMessage:
            'Android notification permission denied. Using Home dashboard.',
      );
    }
    return const ReminderScheduleResult(
      scheduled: true,
      permissionGranted: true,
      notificationIds: <int>[101, 102],
      statusMessage: 'Local reminder scheduled.',
    );
  }

  @override
  Future<void> cancelForDocument(String documentId) async {
    cancelledDocumentIds.add(documentId);
  }
}

void main() {
  final fixedToday = DateTime(2026, 10, 24);

  testWidgets(
    'Scan -> Review -> User corrects date -> Confirm & Save updates Home '
    'and Ask',
    (WidgetTester tester) async {
      final repository = InMemoryVaultRepository();
      final reminderService = _TestReminderService();
      final captureDelegate = _TestCaptureDelegate(
        nextCameraFile: const PickedImageFile(
          path: 'temp_bike_policy.jpg',
          byteLength: 204800,
          sha256: 'abc123def4567890',
        ),
      );
      final ocrService = _TestOcrService(
        const OcrOutput(
          text: 'BIKE INSURANCE POLICY Valid Upto: 10/11/2026',
          confidence: 0.91,
          processingMs: 420,
        ),
      );
      final extractionService = _TestExtractionService(
        const ExtractionResult(
          suggestedCategory: DocumentCategory.insurance,
          suggestedType: DocumentType.insurancePolicy,
          categoryEvidence: 'Matched keywords: bike, insurance, policy',
          assetNameSuggestion: 'Bike',
          dateCandidates: <DateCandidate>[
            DateCandidate(
              fieldKind: DateFieldKind.expiry,
              rawText: '10/11/2026',
              isoDate: '2026-11-10',
              sourceSnippet: 'Valid Upto: 10/11/2026',
              confidenceLevel: ConfidenceLevel.high,
            ),
          ],
        ),
      );

      final deps = LifeVaultDependencies(
        ocrService: ocrService,
        extractionService: extractionService,
        vaultRepository: repository,
        questionService: GroundedVaultQuestionService(repository),
        reminderService: reminderService,
        captureDelegate: captureDelegate,
        nowProvider: () => fixedToday,
      );

      await tester.pumpWidget(LifeVaultApp(dependencies: deps));
      await tester.pumpAndSettle();

      // Tap empty-state CTA on Home to switch to Scan tab.
      final emptyScanCta = find.byKey(const Key('home_empty_scan_cta'));
      await tester.ensureVisible(emptyScanCta);
      await tester.tap(emptyScanCta);
      await tester.pumpAndSettle();

      // Capture photo.
      await tester.tap(find.byKey(const Key('scan_take_photo_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scan_preview_card')), findsOneWidget);

      // Process document -> opens ReviewScreen.
      final processBtn = find.byKey(const Key('scan_process_button'));
      await tester.ensureVisible(processBtn);
      await tester.tap(processBtn);
      await tester.pumpAndSettle();

      expect(find.text('Review & Confirm'), findsOneWidget);
      expect(
        find.textContaining('EXPIRY: 2026-11-10'),
        findsOneWidget,
      );

      // User corrects title and mistaken OCR date (2026-11-10 -> 2026-11-15).
      await tester.enterText(
        find.byKey(const Key('review_title_field')),
        'Honda Bike Insurance',
      );
      final dateField = find.byKey(const Key('review_date_iso_field'));
      await tester.ensureVisible(dateField);
      await tester.enterText(dateField, '2026-11-15');

      final confirmBtn = find.byKey(const Key('confirm_and_save_button'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Returns to Home tab with confirmed date 2026-11-15, NOT 2026-11-10.
      expect(find.text('Honda Bike Insurance'), findsWidgets);
      expect(find.textContaining('Due 2026-11-15'), findsOneWidget);
      expect(find.textContaining('Due 2026-11-10'), findsNothing);
      expect(find.text('In 22d'), findsOneWidget);
      expect(reminderService.scheduledDeadlines.single.dateIso, '2026-11-15');

      // Switch to Ask tab and ask "bike insurance expiry".
      await tester.tap(find.byKey(const Key('nav_tab_ask')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ask_chip_bike insurance expiry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ask_answer_card')), findsOneWidget);
      expect(find.text('ANSWERED'), findsOneWidget);
      expect(find.textContaining('2026-11-15'), findsOneWidget);
    },
  );

  testWidgets(
    'Vault category filter, duplicate detection, and delete cancel reminders',
    (WidgetTester tester) async {
      final existingDoc = DocumentRecord(
        id: 'doc_med_1',
        title: 'City Hospital Lab Report',
        category: DocumentCategory.medical,
        documentType: DocumentType.medicalRecord,
        originalPath: 'lab_report.jpg',
        sha256: 'dup_hash_999',
        ocrStatus: OcrStatus.manual,
        verificationStatus: VerificationStatus.verifiedNoDeadline,
        createdAt: fixedToday,
        updatedAt: fixedToday,
      );
      final repository = InMemoryVaultRepository(
        initialDocuments: <DocumentRecord>[existingDoc],
      );
      final reminderService = _TestReminderService(permissionGranted: false);
      final captureDelegate = _TestCaptureDelegate(
        nextGalleryFile: const PickedImageFile(
          path: 'lab_report_copy.jpg',
          byteLength: 102400,
          sha256: 'dup_hash_999',
        ),
      );

      final deps = LifeVaultDependencies(
        ocrService: _TestOcrService(const OcrOutput(text: '')),
        extractionService: const FallbackDocumentExtractionService(),
        vaultRepository: repository,
        questionService: GroundedVaultQuestionService(repository),
        reminderService: reminderService,
        captureDelegate: captureDelegate,
        nowProvider: () => fixedToday,
      );

      await tester.pumpWidget(LifeVaultApp(dependencies: deps));
      await tester.pumpAndSettle();

      // Navigate to Scan and pick duplicate image from gallery.
      await tester.tap(find.byKey(const Key('nav_tab_scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scan_choose_gallery_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Duplicate Photo Detected (Matching SHA-256)'),
        findsOneWidget,
      );

      // Navigate to Vault tab, filter by Medical, then delete the document.
      await tester.tap(find.byKey(const Key('nav_tab_vault')));
      await tester.pumpAndSettle();

      expect(find.text('City Hospital Lab Report'), findsOneWidget);
      await tester.tap(find.byKey(const Key('vault_filter_medical')));
      await tester.pumpAndSettle();
      expect(find.text('City Hospital Lab Report'), findsOneWidget);

      await tester.tap(find.byKey(const Key('vault_delete_doc_med_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vault_confirm_delete_button')));
      await tester.pumpAndSettle();

      expect(find.text('City Hospital Lab Report'), findsNothing);
      expect(reminderService.cancelledDocumentIds, contains('doc_med_1'));
    },
  );

  testWidgets(
    'Reminders, Family & Assets, Settings & Privacy, and Welcome screens navigate cleanly',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LifeVaultApp());
      await tester.pumpAndSettle();

      // Open Reminders screen via topbar icon.
      await tester.tap(find.byKey(const Key('topbar_reminders_button')));
      await tester.pumpAndSettle();
      expect(find.text('Reminders & Deadlines'), findsOneWidget);

      // Open Family & Assets screen via topbar icon.
      await tester.tap(find.byKey(const Key('topbar_family_button')));
      await tester.pumpAndSettle();
      expect(find.text('Family & Household Assets'), findsOneWidget);

      // Open Settings & Privacy screen via topbar icon.
      await tester.tap(find.byKey(const Key('topbar_settings_button')));
      await tester.pumpAndSettle();
      expect(find.text('Privacy & Local Processing'), findsOneWidget);

      // Open Welcome Guide from Settings.
      await tester.tap(find.byKey(const Key('settings_open_welcome_button')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to LifeVault'), findsWidgets);

      // Run Check Local Services on Welcome screen.
      await tester.tap(find.byKey(const Key('welcome_check_services_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('welcome_readiness_banner')), findsOneWidget);
    },
  );
}
