import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifevault/app/app_controller.dart';
import 'package:lifevault/app/boot.dart';
import 'package:lifevault/app/default_services.dart';
import 'package:lifevault/core/contracts/contracts.dart';
import 'package:lifevault/features/action_guide/action_guide.dart';
import 'package:lifevault/features/classification/classification.dart';
import 'package:lifevault/features/vault/vault.dart';

void main() {
  final fixedNow = DateTime(2026, 10, 24, 10, 0);

  DocumentRecord sampleInsuranceDoc() {
    return DocumentRecord(
      id: 'doc_ins_1',
      title: 'Honda Activa Insurance Policy',
      category: DocumentCategory.insurance,
      documentType: DocumentType.insurancePolicy,
      assetName: 'Honda Activa',
      originalPath: 'test_policy.jpg',
      sha256: 'sha256_ins_1',
      ocrStatus: OcrStatus.success,
      verificationStatus: VerificationStatus.verified,
      createdAt: fixedNow,
      updatedAt: fixedNow,
    );
  }

  DeadlineRecord sampleInsuranceDeadline() {
    return const DeadlineRecord(
      id: 'dl_ins_1',
      documentId: 'doc_ins_1',
      kind: DeadlineKind.expiry,
      dateIso: '2026-11-15',
      evidenceSnippet: 'Policy Number: POL-998877 Valid Until 2026-11-15',
      isVerified: true,
    );
  }

  group('DeterministicActionGuideService (Phase 1)', () {
    const service = DeterministicActionGuideService();

    test(
        'generates Insurance playbook with NCB, inspection warning, and copyable policy ID',
        () async {
      final playbook = await service.generatePlaybook(
        document: sampleInsuranceDoc(),
        deadline: sampleInsuranceDeadline(),
      );

      expect(playbook.documentId, 'doc_ins_1');
      expect(playbook.source, PlaybookSource.deterministicFallback);
      expect(playbook.summary, contains('No Claim Bonus (NCB)'));
      expect(playbook.steps.length, 4);
      expect(playbook.steps.first.copyableText, 'POL-998877');
      expect(
        playbook.steps.any((s) => s.title.contains('Avoid Inspection')),
        isTrue,
      );
    });

    test(
        'generates Utility Bill playbook with consumer/meter ID and cutoff step',
        () async {
      final billDoc = DocumentRecord(
        id: 'doc_bill_1',
        title: 'BESCOM Electricity Bill',
        category: DocumentCategory.homeUtilities,
        documentType: DocumentType.bill,
        originalPath: 'bill.jpg',
        sha256: 'sha_bill_1',
        ocrStatus: OcrStatus.success,
        verificationStatus: VerificationStatus.verified,
        createdAt: fixedNow,
        updatedAt: fixedNow,
      );
      const billDeadline = DeadlineRecord(
        id: 'dl_bill_1',
        documentId: 'doc_bill_1',
        kind: DeadlineKind.billDue,
        dateIso: '2026-11-05',
        evidenceSnippet: 'Consumer No: MTR-445566 Due Date: 2026-11-05',
        isVerified: true,
      );

      final playbook = await service.generatePlaybook(
        document: billDoc,
        deadline: billDeadline,
      );

      expect(playbook.source, PlaybookSource.deterministicFallback);
      expect(playbook.steps.first.copyableText, 'MTR-445566');
      expect(
        playbook.steps.any((s) => s.title.contains('Grace Cutoff')),
        isTrue,
      );
    });

    test(
        'generates Appliance Warranty & Medical playbooks with grounded references',
        () async {
      final warrantyDoc = DocumentRecord(
        id: 'doc_war_1',
        title: 'LG Fridge Warranty Card',
        category: DocumentCategory.appliances,
        documentType: DocumentType.warranty,
        assetName: 'LG Refrigerator',
        originalPath: 'war.jpg',
        sha256: 'sha_war_1',
        ocrStatus: OcrStatus.success,
        verificationStatus: VerificationStatus.verified,
        createdAt: fixedNow,
        updatedAt: fixedNow,
      );
      final warrantyPlaybook = await service.generatePlaybook(
        document: warrantyDoc,
        evidenceSnippet: 'Serial Number: SN-LG-2026',
      );
      expect(warrantyPlaybook.steps.first.copyableText, 'SN-LG-2026');
      expect(
        warrantyPlaybook.steps.any((s) => s.title.contains('Tax Invoice')),
        isTrue,
      );

      final medicalDoc = DocumentRecord(
        id: 'doc_med_1',
        title: 'Apollo Clinic Prescription',
        category: DocumentCategory.medical,
        documentType: DocumentType.prescription,
        originalPath: 'med.jpg',
        sha256: 'sha_med_1',
        ocrStatus: OcrStatus.success,
        verificationStatus: VerificationStatus.verified,
        createdAt: fixedNow,
        updatedAt: fixedNow,
      );
      final medicalPlaybook = await service.generatePlaybook(
        document: medicalDoc,
      );
      expect(
        medicalPlaybook.steps.any((s) => s.title.contains('Prescription')),
        isTrue,
      );
    });
  });

  group('QwenActionGuideService & HybridActionGuideService (Phase 2)', () {
    test(
        'QwenActionGuideService parses bulleted output and sanitizes hallucinated dates',
        () async {
      final qwenService = QwenActionGuideService(
        promptRunner: (args) async {
          expect(args['temperature'], 0.2);
          expect(args['topP'], 0.9);
          expect(args['userPrompt'] as String, contains('2026-11-15'));
          return <String, Object?>{
            'text': '''
- **Check Policy & NCB**: Verify policy POL-998877 before 2026-11-15.
- **Avoid Inspection**: Renew before 2099-01-01 to prevent physical vehicle inspection.
- **Keep RC Ready**: Keep registration certificate handy during payment.
''',
            'summary': 'Qwen custom renewal plan.',
          };
        },
      );

      final playbook = await qwenService.generatePlaybook(
        document: sampleInsuranceDoc(),
        deadline: sampleInsuranceDeadline(),
      );

      expect(playbook.source, PlaybookSource.qwen);
      expect(playbook.summary, 'Qwen custom renewal plan.');
      expect(playbook.steps.length, 3);
      expect(playbook.steps.first.copyableText, 'POL-998877');
      // Verify Rule 2 Grounding Safeguard: invented date 2099-01-01 was scrubbed
      // and replaced with the verified deadline date 2026-11-15!
      expect(playbook.steps[1].description, isNot(contains('2099-01-01')));
      expect(playbook.steps[1].description, contains('2026-11-15'));
    });

    test(
        'HybridActionGuideService falls back to deterministic playbook on error or timeout',
        () async {
      final failingQwen = QwenActionGuideService(
        promptRunner: (_) async => <String, Object?>{
          'errorCode': 'MODEL_NOT_STAGED',
          'errorMessage': 'GGUF not present',
        },
      );
      final hybridOnFailure = HybridActionGuideService(primary: failingQwen);
      final fallbackResult = await hybridOnFailure.generatePlaybook(
        document: sampleInsuranceDoc(),
        deadline: sampleInsuranceDeadline(),
      );
      expect(fallbackResult.source, PlaybookSource.deterministicFallback);
      expect(fallbackResult.steps.length, 4);

      final slowQwen = QwenActionGuideService(
        promptRunner: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return <String, Object?>{
            'text': '- **Step 1**: Slow\n- **Step 2**: Slow'
          };
        },
      );
      final hybridOnTimeout = HybridActionGuideService(
        primary: slowQwen,
        timeout: const Duration(milliseconds: 30),
      );
      final timeoutResult = await hybridOnTimeout.generatePlaybook(
        document: sampleInsuranceDoc(),
        deadline: sampleInsuranceDeadline(),
      );
      expect(timeoutResult.source, PlaybookSource.deterministicFallback);
    });
  });

  group('Phase 3 & Phase 4: ActionPlaybookCard UI & Notification Deep-Link',
      () {
    testWidgets(
        'renders ActionPlaybookCard, toggles step checkboxes, copies ID, and handles notification deep-link',
        (tester) async {
      String? copiedClipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final map = call.arguments as Map<dynamic, dynamic>;
            copiedClipboardText = map['text'] as String?;
          }
          return null;
        },
      );

      final repository = InMemoryVaultRepository();
      final savedDoc = await repository.saveVerified(
        const VerifiedDocumentInput(
          originalTempPath: 'bike_policy.jpg',
          title: 'Bajaj Pulsar Insurance Policy',
          category: DocumentCategory.insurance,
          documentType: DocumentType.insurancePolicy,
          assetName: 'Bajaj Pulsar',
          sha256: 'sha_pulsar_1',
          verifiedDeadlines: <VerifiedDeadlineInput>[
            VerifiedDeadlineInput(
              kind: DeadlineKind.expiry,
              dateIso: '2026-11-10',
              evidenceSnippet:
                  'Policy Number: BAJ-778899 Valid Until 2026-11-10',
            ),
          ],
        ),
      );

      final controller = LifeVaultController(
        ocrService: const MethodChannelOfflineOcrService(),
        extractionService: const LifeVaultDocumentExtractionService(),
        vaultRepository: repository,
        questionService: GroundedVaultQuestionService(repository),
        reminderService: const NoOpReminderService(),
        actionGuideService: const DeterministicActionGuideService(),
        captureDelegate: CaptureServiceImageDelegate(),
        nowProvider: () => fixedNow,
      );

      await tester.pumpWidget(LifeVaultApp(controller: controller));
      await tester.pumpAndSettle();

      // Simulate tapping a local notification with Phase 4 deep-link payload.
      final payload = ReminderServiceImpl.encodePlaybookPayload(savedDoc.id);
      expect(payload, contains('"action":"open_playbook"'));

      controller.handleNotificationPayload(payload);
      await tester.pumpAndSettle();

      // Verify DocumentDetailScreen opened with ActionPlaybookCard rendered.
      expect(find.byKey(const Key('action_playbook_card')), findsOneWidget);
      expect(
        find.text('0 of 4 preparation tasks completed'),
        findsOneWidget,
      );

      // Toggle first step checkbox and verify progress updates.
      final firstStepCheckbox = find.byKey(
        Key('playbook_checkbox_${savedDoc.id}_step_1'),
      );
      await tester.ensureVisible(firstStepCheckbox);
      await tester.tap(firstStepCheckbox);
      await tester.pumpAndSettle();

      expect(
        find.text('1 of 4 preparation tasks completed'),
        findsOneWidget,
      );

      // Tap the Copy ID button and verify clipboard text.
      final copyButton = find.byKey(
        Key('playbook_copy_${savedDoc.id}_step_1'),
      );
      await tester.ensureVisible(copyButton);
      await tester.tap(copyButton);
      await tester.pumpAndSettle();

      expect(copiedClipboardText, 'BAJ-778899');
    });
  });
}
