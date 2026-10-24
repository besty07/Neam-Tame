import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifevault/app/app_controller.dart';
import 'package:lifevault/app/boot.dart';
import 'package:lifevault/app/default_services.dart';
import 'package:lifevault/core/contracts/contracts.dart';
import 'package:lifevault/features/action_guide/action_guide.dart';
import 'package:lifevault/features/classification/classification.dart';
import 'package:lifevault/features/gemma_vision/gemma_vision.dart';
import 'package:lifevault/features/screens/review_screen.dart';

class _StubCaptureDelegate implements ImageCaptureDelegate {
  _StubCaptureDelegate(this.file);

  final PickedImageFile file;

  @override
  Future<PickedImageFile?> pickFromCamera() async => file;

  @override
  Future<PickedImageFile?> pickFromGallery() async => file;

  @override
  Future<PickedImageFile?> retrieveLostImage() async => null;
}

class _StubOcrService implements OfflineOcrService {
  const _StubOcrService(this.output);

  final OcrOutput output;

  @override
  Future<OcrOutput> recognizeImage(
    String localImagePath, {
    String language = 'eng',
  }) async {
    return output;
  }
}

void main() {
  final fixedToday = DateTime(2026, 10, 24);

  group('GemmaCandidateJsonParser defensive validation (§3)', () {
    test(
      'parses valid PUC JSON, strips markdown fences, and never promotes issue date to expiry',
      () {
        const sampleJson = '''
```json
{
  "category": "vehicle",
  "document_type": "pollution_certificate",
  "title": "Pollution Under Control Certificate",
  "asset_name": "DL01AB1234",
  "amount": "Rs. 120",
  "reference_number": "PUCC-998811",
  "date_candidates": [
    {
      "label": "issue",
      "raw_date": "10/01/2026",
      "iso_date": "2026-01-10",
      "evidence_quote": "Date of Testing: 10/01/2026",
      "ambiguous": false
    },
    {
      "label": "expiry",
      "raw_date": "09/07/2026",
      "iso_date": "2026-07-09",
      "evidence_quote": "Valid Upto: 09/07/2026",
      "ambiguous": false
    }
  ],
  "warnings": []
}
```
''';

        final draft = GemmaCandidateJsonParser.parse(
          sampleJson,
          sourceImagePath: 'puc_scan.jpg',
        );

        expect(draft.usedGemmaVision, isTrue);
        expect(draft.category, 'vehicle');
        expect(draft.resolvedCategory, DocumentCategory.vehicle);
        expect(draft.resolvedDocumentType, DocumentType.certificate);
        expect(draft.title, 'Pollution Under Control Certificate');
        expect(draft.assetName, 'DL01AB1234');
        expect(draft.amount, 'Rs. 120');
        expect(draft.referenceNumber, 'PUCC-998811');
        expect(draft.warnings, isEmpty);
        expect(draft.dates, hasLength(2));

        // Issue date must NOT be promoted to a deadline candidate.
        expect(draft.dates[0].fieldKind, DateFieldKind.issue);
        expect(draft.dates[0].fieldKind.isDeadlineCandidate, isFalse);
        expect(draft.dates[0].isoDate, '2026-01-10');
        expect(draft.dates[0].sourceSnippet, 'Date of Testing: 10/01/2026');

        // Expiry date is a deadline candidate.
        expect(draft.dates[1].fieldKind, DateFieldKind.expiry);
        expect(draft.dates[1].fieldKind.isDeadlineCandidate, isTrue);
        expect(draft.dates[1].isoDate, '2026-07-09');
        expect(draft.dates[1].sourceSnippet, 'Valid Upto: 09/07/2026');
      },
    );

    test(
      'rejects malformed JSON safely without throwing and returns warning',
      () {
        final draft = GemmaCandidateJsonParser.parse(
          '{not_valid_json: [1, 2',
          sourceImagePath: 'corrupt.jpg',
        );

        expect(draft.usedGemmaVision, isTrue);
        expect(draft.dates, isEmpty);
        expect(draft.warnings, isNotEmpty);
        expect(
          draft.warnings.first,
          contains('not valid JSON'),
        );
      },
    );

    test(
      'rejects invented categories and invalid calendar dates while preserving warnings',
      () {
        const jsonWithInvalidFields = '''
{
  "category": "cryptocurrency_portfolio",
  "document_type": "warranty",
  "title": "Washing Machine Warranty",
  "asset_name": "Samsung Washer",
  "amount": null,
  "reference_number": "WM-2026-X",
  "date_candidates": [
    {
      "label": "purchase",
      "raw_date": "31/02/2026",
      "iso_date": "2026-02-31",
      "evidence_quote": "Purchase Date: 31/02/2026",
      "ambiguous": false
    },
    {
      "label": "expiry",
      "raw_date": "04/05/2027",
      "iso_date": "2027-05-04",
      "evidence_quote": "Warranty Valid Till 04/05/2027",
      "ambiguous": true
    }
  ],
  "warnings": [
    "Date 04/05/2027 could be DD/MM/YYYY or MM/DD/YYYY"
  ]
}
''';

        final draft = GemmaCandidateJsonParser.parse(
          jsonWithInvalidFields,
          sourceImagePath: 'washer.jpg',
        );

        // Invented category defaulted to 'other' with warning.
        expect(draft.category, 'other');
        expect(draft.resolvedCategory, DocumentCategory.other);
        expect(
          draft.warnings.any((w) => w.contains('cryptocurrency_portfolio')),
          isTrue,
        );

        // Purchase date with impossible calendar date 2026-02-31 rejected.
        expect(draft.dates[0].fieldKind, DateFieldKind.purchase);
        expect(draft.dates[0].fieldKind.isDeadlineCandidate, isFalse);
        expect(draft.dates[0].isoDate, isNull);
        expect(draft.dates[0].ambiguous, isTrue);

        // Ambiguous expiry date has isoDate cleared so user must confirm.
        expect(draft.dates[1].fieldKind, DateFieldKind.expiry);
        expect(draft.dates[1].isoDate, isNull);
        expect(draft.dates[1].ambiguous, isTrue);
        expect(draft.dates[1].confidenceLevel, ConfidenceLevel.low);
      },
    );
  });

  group('HybridVisionExtractionService fallback orchestration (§4 & §8)', () {
    test(
      'uses GemmaVisionExtractionService when model is ready and falls back to OcrExtractionService when missing',
      () async {
        var modelAvailable = true;
        final gemmaService = GemmaVisionExtractionService(
          methodRunner: (method, args) async {
            if (method == 'getModelStatus') {
              return <Object?, Object?>{
                'state': modelAvailable ? 'ready' : 'model_missing',
                'available': modelAvailable,
                'modelName':
                    modelAvailable ? 'gemma-3n-E4B-it-int4.litertlm' : null,
              };
            }
            if (method == 'extractDocumentFields') {
              return <Object?, Object?>{
                'status': 'ok',
                'rawJson': '''
{
  "category": "insurance",
  "document_type": "insurance_policy",
  "title": "Car Insurance Schedule",
  "asset_name": "Maruti Swift",
  "amount": "Rs. 8,450",
  "reference_number": "POL-SWIFT-77",
  "date_candidates": [
    {
      "label": "expiry",
      "raw_date": "20/11/2026",
      "iso_date": "2026-11-20",
      "evidence_quote": "Midnight of 20/11/2026",
      "ambiguous": false
    }
  ],
  "warnings": []
}
''',
              };
            }
            return null;
          },
        );

        final ocrFallback = OcrExtractionService(
          ocrService: const _StubOcrService(
            OcrOutput(
              text: 'ELECTRICITY BILL\nDue Date: 12/11/2026\n',
              confidence: 0.92,
            ),
          ),
          extractionService: const LifeVaultDocumentExtractionService(),
        );

        final hybrid = HybridVisionExtractionService(
          gemmaService: gemmaService,
          ocrFallbackService: ocrFallback,
        );

        // 1. Model ready -> uses Gemma 3n Vision.
        final gemmaDraft = await hybrid.extractImage('swift_policy.jpg');
        expect(gemmaDraft.usedGemmaVision, isTrue);
        expect(gemmaDraft.title, 'Car Insurance Schedule');
        expect(gemmaDraft.referenceNumber, 'POL-SWIFT-77');
        expect(gemmaDraft.dates.single.isoDate, '2026-11-20');

        // 2. Model missing -> falls back to deterministic OCR pipeline.
        modelAvailable = false;
        final fallbackDraft = await hybrid.extractImage('bill.jpg');
        expect(fallbackDraft.usedGemmaVision, isFalse);
        expect(fallbackDraft.resolvedCategory, DocumentCategory.homeUtilities);
        expect(fallbackDraft.dates, isNotEmpty);
        expect(fallbackDraft.dates.first.isoDate, '2026-11-12');
      },
    );
  });

  group('UI & Controller Gemma 3n states, warnings, and coexistence (§4 & §5)',
      () {
    testWidgets(
      'surfaces Gemma 3n proposal banner, warnings, ref/amount chips on ReviewScreen and enforces deterministic playbook when Gemma is active',
      (tester) async {
        final gemmaService = GemmaVisionExtractionService(
          methodRunner: (method, args) async {
            if (method == 'getModelStatus' || method == 'importLocalModel') {
              return <Object?, Object?>{
                'state': 'ready',
                'available': true,
                'modelName': 'gemma-3n-E4B-it-int4.litertlm',
                'message': 'Gemma 3n E4B ready (gemma-3n-E4B-it-int4.litertlm)',
              };
            }
            if (method == 'extractDocumentFields') {
              return <Object?, Object?>{
                'status': 'ok',
                'rawJson': '''
{
  "category": "insurance",
  "document_type": "insurance_policy",
  "title": "Two Wheeler Package Policy",
  "asset_name": "TVS Jupiter",
  "amount": "Rs. 1,850",
  "reference_number": "TVS-POL-5544",
  "date_candidates": [
    {
      "label": "expiry",
      "raw_date": "18/11/2026",
      "iso_date": "2026-11-18",
      "evidence_quote": "Policy Expiry: 18/11/2026",
      "ambiguous": false
    }
  ],
  "warnings": [
    "Bottom-right stamp partially obscures chassis number"
  ]
}
''',
              };
            }
            return null;
          },
        );

        var qwenCalled = false;
        final spyQwenGuide = QwenActionGuideService(
          promptRunner: (_) async {
            qwenCalled = true;
            return <String, Object?>{
              'text': '- **Step 1**: Should not run while Gemma is active\n'
                  '- **Step 2**: Second step',
            };
          },
        );

        final repository = InMemoryVaultRepository();
        final controller = LifeVaultController(
          ocrService: const _StubOcrService(OcrOutput(text: '')),
          extractionService: const LifeVaultDocumentExtractionService(),
          vaultRepository: repository,
          questionService: GroundedVaultQuestionService(repository),
          reminderService: const NoOpReminderService(),
          actionGuideService: HybridActionGuideService(primary: spyQwenGuide),
          gemmaVisionService: gemmaService,
          captureDelegate: _StubCaptureDelegate(
            const PickedImageFile(
              path: 'tvs_policy.jpg',
              byteLength: 65536,
              sha256: 'sha_tvs_5544',
            ),
          ),
          nowProvider: () => fixedToday,
        );

        await controller.refreshVisionModelStatus();
        expect(controller.visionModelState, VisionModelState.ready);

        await controller.pickFromCamera();
        final draft = await controller.processSelectedImage();
        expect(draft, isNotNull);
        expect(draft!.usedGemmaVision, isTrue);
        expect(controller.visionModelState, VisionModelState.needsReview);

        await tester.pumpWidget(
          MaterialApp(
            home: ReviewScreen(
              controller: controller,
              draft: draft,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Gemma unverified banner, warning card, and ref/amount chips.
        expect(
          find.byKey(const Key('review_gemma_unverified_banner')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('review_extraction_warnings_card')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Bottom-right stamp partially obscures'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('review_proposed_ref_chip')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('review_proposed_amount_chip')),
          findsOneWidget,
        );

        // Save the reviewed document and verify coexistence rule (§5.3):
        // DeterministicActionGuideService runs instead of Qwen when Gemma is active.
        final confirmBtn = find.byKey(const Key('confirm_and_save_button'));
        await tester.ensureVisible(confirmBtn);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(controller.allDocuments, hasLength(1));
        final savedDoc = controller.allDocuments.single;
        final playbook = controller.playbookForDocument(savedDoc.id);
        expect(playbook, isNotNull);
        expect(playbook!.source, PlaybookSource.deterministicFallback);
        expect(qwenCalled, isFalse);
      },
    );

    testWidgets(
      'SettingsScreen displays Gemma 3n Vision card and supports local model import & unload',
      (tester) async {
        var isLoaded = false;
        final gemmaService = GemmaVisionExtractionService(
          methodRunner: (method, args) async {
            if (method == 'importLocalModel') {
              isLoaded = true;
              return <Object?, Object?>{
                'state': 'ready',
                'available': true,
                'modelName': 'gemma-3n-E4B-it-int4.litertlm',
                'message': 'Imported gemma-3n-E4B-it-int4.litertlm',
              };
            }
            if (method == 'unloadModel') {
              isLoaded = false;
              return <Object?, Object?>{
                'state': 'model_missing',
                'available': false,
              };
            }
            return <Object?, Object?>{
              'state': isLoaded ? 'ready' : 'model_missing',
              'available': isLoaded,
              'modelName': isLoaded ? 'gemma-3n-E4B-it-int4.litertlm' : null,
            };
          },
        );

        final repository = InMemoryVaultRepository();
        final deps = LifeVaultDependencies(
          ocrService: const _StubOcrService(OcrOutput(text: '')),
          extractionService: const LifeVaultDocumentExtractionService(),
          vaultRepository: repository,
          questionService: GroundedVaultQuestionService(repository),
          reminderService: const NoOpReminderService(),
          gemmaVisionService: gemmaService,
        );

        await tester.pumpWidget(LifeVaultApp(dependencies: deps));
        await tester.pumpAndSettle();

        // Open Settings screen.
        await tester.tap(find.byKey(const Key('topbar_settings_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('settings_gemma_vision_card')),
          findsOneWidget,
        );

        final pathField = find.byKey(
          const Key('settings_gemma_model_path_field'),
        );
        await tester.ensureVisible(pathField);
        await tester.enterText(
          pathField,
          '/sdcard/Download/gemma-3n-E4B-it-int4.litertlm',
        );

        final importBtn = find.byKey(
          const Key('settings_import_gemma_model_button'),
        );
        await tester.ensureVisible(importBtn);
        await tester.tap(importBtn);
        await tester.pumpAndSettle();

        expect(find.text('Gemma 3n E4B ready'), findsOneWidget);

        final unloadBtn = find.byKey(
          const Key('settings_unload_gemma_model_button'),
        );
        await tester.ensureVisible(unloadBtn);
        await tester.tap(unloadBtn);
        await tester.pumpAndSettle();

        expect(find.text('Model missing'), findsOneWidget);
      },
    );
  });
}
