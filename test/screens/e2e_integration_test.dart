import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifevault/app/app_controller.dart';
import 'package:lifevault/app/default_services.dart';
import 'package:lifevault/core/contracts/contracts.dart';
import 'package:lifevault/features/capture_ocr/capture_ocr.dart';
import 'package:lifevault/features/classification/classification.dart';
import 'package:lifevault/features/vault/vault.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestCaptureDelegate implements ImageCaptureDelegate {
  _TestCaptureDelegate(this.file);

  final PickedImageFile file;

  @override
  Future<PickedImageFile?> pickFromCamera() async => file;

  @override
  Future<PickedImageFile?> pickFromGallery() async => file;

  @override
  Future<PickedImageFile?> retrieveLostImage() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'Full E2E integration: D1 OCR -> D2 Classifier -> D4 Controller -> '
    'D3 SQLite & Grounded Q&A',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('lv_e2e_');
      final db = await VaultDatabase.openInMemory();
      addTearDown(() async {
        await db.close();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final sampleImage = File(p.join(tempDir.path, 'fridge_warranty.jpg'));
      await sampleImage.writeAsBytes(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x11, 0x22]);

      const ocrChannel = MethodChannel('lifevault/ocr_e2e_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ocrChannel, (MethodCall call) async {
        if (call.method == 'recognizeImage') {
          return <String, Object?>{
            'text': 'REFRIGERATOR WARRANTY CERTIFICATE\n'
                'Appliance: Refrigerator\n'
                'Warranty Ends: 15/12/2026\n',
            'language': 'eng',
            'page': 1,
            'confidence': 89.5,
            'processingMs': 310,
          };
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ocrChannel, null);
      });

      final vaultRepo = VaultRepositoryImpl(db: db, storageDir: tempDir);
      final questionService = IntegratedQuestionService(
        QuestionServiceImpl(vaultRepo),
      );
      final ocrService = OfflineOcrServiceImpl(channel: ocrChannel);
      const extractionService = LifeVaultDocumentExtractionService();

      final controller = LifeVaultController(
        ocrService: ocrService,
        extractionService: extractionService,
        vaultRepository: vaultRepo,
        questionService: questionService,
        reminderService: const NoOpReminderService(),
        captureDelegate: _TestCaptureDelegate(
          PickedImageFile(
            path: sampleImage.path,
            byteLength: 6,
            sha256: 'e2e_fridge_sha256_001',
          ),
        ),
        nowProvider: () => DateTime(2026, 10, 24),
      );

      await controller.initialize();
      expect(controller.allDocuments, isEmpty);

      // 1. Capture photo via D4 controller.
      await controller.pickFromCamera();
      expect(controller.selectedScanFile, isNotNull);

      // 2. Process image through D1 OfflineOcrServiceImpl +
      //    D2 LifeVaultDocumentExtractionService.
      final draft = await controller.processSelectedImage();
      expect(draft, isNotNull);
      expect(draft!.ocrStatus, equals(OcrStatus.success));
      expect(
        draft.extractionResult.suggestedCategory,
        equals(DocumentCategory.appliances),
      );
      expect(
        draft.extractionResult.suggestedType,
        equals(DocumentType.warranty),
      );
      expect(draft.extractionResult.dateCandidates, isNotEmpty);
      expect(
        draft.extractionResult.dateCandidates.first.isoDate,
        equals('2026-12-15'),
      );

      // 3. Confirm & Save verified document + deadline into D3 SQLite repo.
      final savedDoc = await controller.saveReviewedDocument(
        VerifiedDocumentInput(
          originalTempPath: draft.imagePath,
          title: 'Kitchen Fridge Warranty',
          category: draft.extractionResult.suggestedCategory,
          documentType: draft.extractionResult.suggestedType,
          assetName: draft.extractionResult.assetNameSuggestion ?? 'Fridge',
          sha256: draft.sha256,
          ocrStatus: draft.ocrStatus,
          verificationStatus: VerificationStatus.verified,
          verifiedDeadlines: const <VerifiedDeadlineInput>[
            VerifiedDeadlineInput(
              kind: DeadlineKind.expiry,
              dateIso: '2026-12-15',
              evidenceSnippet: 'Warranty Ends: 15/12/2026',
            ),
          ],
        ),
      );

      expect(savedDoc.title, equals('Kitchen Fridge Warranty'));
      expect(controller.allDocuments, hasLength(1));
      expect(controller.upcomingItems, hasLength(1));
      expect(
        controller.upcomingItems.single.deadline.dateIso,
        equals('2026-12-15'),
      );

      // 4. Ask "fridge warranty" via D3 QuestionServiceImpl +
      //    D4 IntegratedQuestionService.
      await controller.askQuestion('fridge warranty');
      expect(controller.lastAnswerResult, isNotNull);
      expect(
        controller.lastAnswerResult!.status,
        equals(AnswerStatus.answered),
      );
      expect(controller.lastAnswerResult!.text, contains('2026-12-15'));

      // 5. Delete document and verify SQLite + file cleanup.
      await controller.deleteDocument(savedDoc.id);
      expect(controller.allDocuments, isEmpty);
      expect(controller.verifiedDeadlines, isEmpty);
    },
  );
}
