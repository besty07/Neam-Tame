import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifevault/app/boot.dart';
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
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets(
    'Full E2E integration: D1 OCR -> D2 Classifier -> D4 Review -> D3 SQLite '
    '& Grounded Q&A',
    (WidgetTester tester) async {
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

      final deps = LifeVaultDependencies(
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

      await tester.pumpWidget(LifeVaultApp(dependencies: deps));
      await tester.pumpAndSettle();

      // 1. Navigate to Scan via Home empty-state CTA.
      await tester.tap(find.byKey(const Key('home_empty_scan_cta')));
      await tester.pumpAndSettle();

      // 2. Capture image and run D1 OCR + D2 Extraction.
      await tester.tap(find.byKey(const Key('scan_take_photo_button')));
      await tester.pumpAndSettle();

      final processBtn = find.byKey(const Key('scan_process_button'));
      await tester.ensureVisible(processBtn);
      await tester.pumpAndSettle();
      await tester.tap(processBtn);
      await tester.pumpAndSettle();

      // 3. Verify D2 extracted category Appliances, type Warranty, and date
      //    2026-12-15.
      expect(find.text('Review & Confirm'), findsOneWidget);
      expect(find.textContaining('EXPIRY: 2026-12-15'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('review_title_field')),
        'Kitchen Fridge Warranty',
      );

      final confirmBtn = find.byKey(const Key('confirm_and_save_button'));
      await tester.ensureVisible(confirmBtn);
      await tester.pumpAndSettle();
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // 4. Verify D3 persisted the record in SQLite and Home displays it.
      expect(find.text('Kitchen Fridge Warranty'), findsOneWidget);
      expect(find.textContaining('Due 2026-12-15'), findsOneWidget);

      // 5. Switch to Ask tab and test the "fridge warranty" suggested chip
      //    against D3's QuestionServiceImpl.
      await tester.tap(find.byKey(const Key('nav_tab_ask')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ask_chip_fridge warranty')));
      await tester.pumpAndSettle();

      expect(find.text('ANSWERED'), findsOneWidget);
      expect(find.textContaining('2026-12-15'), findsOneWidget);
    },
  );
}
