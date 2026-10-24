import '../../core/contracts/contracts.dart';

/// Deterministic offline Action Guide generator (Phase 1 of Qwen Integration Plan).
///
/// Produces instant, zero-hallucination preparation checklists tailored to the
/// verified document's category, type, asset, deadline, and OCR snippet.
class DeterministicActionGuideService implements ActionGuideService {
  const DeterministicActionGuideService();

  static final RegExp _identifierPattern = RegExp(
    r'(?:policy|consumer|meter|serial|invoice|account|reg(?:istration)?|chassis|id|no|number)\s*[:#\-]?\s*([A-Z0-9][A-Z0-9\-/]{3,24})',
    caseSensitive: false,
  );

  /// Extracts a copyable reference ID (policy number, meter ID, serial number,
  /// or asset identifier) from the snippet, title, or asset name.
  static String? extractCopyableIdentifier({
    required DocumentRecord document,
    String? evidenceSnippet,
  }) {
    if (evidenceSnippet != null && evidenceSnippet.trim().isNotEmpty) {
      final match = _identifierPattern.firstMatch(evidenceSnippet);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }
    final titleMatch = _identifierPattern.firstMatch(document.title);
    if (titleMatch != null && titleMatch.group(1) != null) {
      return titleMatch.group(1)!.trim();
    }
    if (document.assetName != null && document.assetName!.trim().isNotEmpty) {
      return document.assetName!.trim();
    }
    return document.title.trim().isNotEmpty ? document.title.trim() : null;
  }

  @override
  Future<ActionPlaybook> generatePlaybook({
    required DocumentRecord document,
    DeadlineRecord? deadline,
    String? evidenceSnippet,
  }) async {
    final effectiveSnippet = evidenceSnippet ?? deadline?.evidenceSnippet;
    final copyableId = extractCopyableIdentifier(
      document: document,
      evidenceSnippet: effectiveSnippet,
    );
    final dueLabel = deadline != null && deadline.isVerified
        ? 'before ${deadline.dateIso}'
        : 'ahead of your next review cycle';
    final assetLabel =
        (document.assetName != null && document.assetName!.trim().isNotEmpty)
            ? document.assetName!.trim()
            : document.title;

    if (document.category == DocumentCategory.insurance ||
        document.documentType == DocumentType.insurancePolicy) {
      return ActionPlaybook(
        documentId: document.id,
        summary:
            'Insurance renewal playbook for $assetLabel ($dueLabel). Completing '
            'these steps early preserves your No Claim Bonus (NCB) and avoids '
            'mandatory physical inspection.',
        source: PlaybookSource.deterministicFallback,
        steps: <ActionStep>[
          ActionStep(
            id: '${document.id}_step_1',
            title: 'Keep Policy & Asset Reference Ready',
            description:
                'Use your existing policy/asset reference when requesting '
                'renewal quotes or verifying previous coverage details.',
            copyableText: copyableId,
          ),
          ActionStep(
            id: '${document.id}_step_2',
            title: 'Verify No Claim Bonus (NCB) & IDV Slab',
            description:
                'Confirm your accumulated NCB discount percentage and Insured '
                'Declared Value (IDV) on the current schedule $dueLabel.',
          ),
          ActionStep(
            id: '${document.id}_step_3',
            title: 'Renew Before Midnight Cutoff to Avoid Inspection',
            description:
                'A policy lapse of even 1 day can trigger a mandatory physical '
                'vehicle/asset inspection and delay active coverage.',
          ),
          ActionStep(
            id: '${document.id}_step_4',
            title: 'Keep RC / Previous Policy Copy Accessible',
            description:
                'Once renewed, scan or import the new policy schedule into '
                'LifeVault so next year’s expiry reminder updates automatically.',
          ),
        ],
      );
    }

    if (document.category == DocumentCategory.homeUtilities ||
        document.documentType == DocumentType.bill) {
      return ActionPlaybook(
        documentId: document.id,
        summary:
            'Utility & bill payment checklist for ${document.title} ($dueLabel) '
            'to prevent late surcharges or service disconnection.',
        source: PlaybookSource.deterministicFallback,
        steps: <ActionStep>[
          ActionStep(
            id: '${document.id}_step_1',
            title: 'Copy Consumer / Meter Account ID',
            description:
                'Keep your consumer or meter identifier ready for quick bill '
                'lookup at your payment counter or banking app.',
            copyableText: copyableId,
          ),
          ActionStep(
            id: '${document.id}_step_2',
            title: 'Pay Before Grace Cutoff ($dueLabel)',
            description:
                'Clear the bill $dueLabel to avoid late payment penalties and '
                'disconnection notices.',
          ),
          ActionStep(
            id: '${document.id}_step_3',
            title: 'Cross-Check Meter Reading & Tariff Slab',
            description:
                'Verify that the billed units on the statement match your '
                'physical meter reading and previous payment credit.',
          ),
          ActionStep(
            id: '${document.id}_step_4',
            title: 'Save Payment Confirmation Receipt',
            description:
                'Record the payment receipt or update this bill entry in '
                'LifeVault once paid.',
          ),
        ],
      );
    }

    if (document.category == DocumentCategory.appliances ||
        document.documentType == DocumentType.warranty ||
        document.documentType == DocumentType.invoiceReceipt) {
      return ActionPlaybook(
        documentId: document.id,
        summary:
            'Warranty & service protection guide for $assetLabel ($dueLabel). '
            'Report any performance issues before coverage expires.',
        source: PlaybookSource.deterministicFallback,
        steps: <ActionStep>[
          ActionStep(
            id: '${document.id}_step_1',
            title: 'Keep Serial Number & Tax Invoice Reference Handy',
            description:
                'Authorized service centers require the original tax invoice '
                'and model/serial reference to honor warranty claims.',
            copyableText: copyableId,
          ),
          ActionStep(
            id: '${document.id}_step_2',
            title: 'Inspect Appliance Performance Before Coverage Ends',
            description:
                'Check cooling, motor noise, battery health, or leakage '
                '$dueLabel while parts and labor remain covered.',
          ),
          ActionStep(
            id: '${document.id}_step_3',
            title: 'Log Official Service Ticket Prior to Expiry Date',
            description:
                'Ensure any warranty service request is registered before the '
                'expiry date so the ticket timestamp falls within coverage.',
          ),
        ],
      );
    }

    if (document.category == DocumentCategory.medical ||
        document.documentType == DocumentType.prescription ||
        document.documentType == DocumentType.medicalRecord) {
      return ActionPlaybook(
        documentId: document.id,
        summary: 'Medical record & follow-up preparation checklist for '
            '${document.title} ($dueLabel).',
        source: PlaybookSource.deterministicFallback,
        steps: <ActionStep>[
          ActionStep(
            id: '${document.id}_step_1',
            title: 'Keep Record / Prescription Reference Accessible',
            description:
                'Use this record title or reference when booking a clinic '
                'follow-up or pharmacy refill.',
            copyableText: copyableId,
          ),
          ActionStep(
            id: '${document.id}_step_2',
            title: 'Check Prescription Validity & Refill Window',
            description:
                'Verify remaining refill quantities and prescription validity '
                '$dueLabel.',
          ),
          ActionStep(
            id: '${document.id}_step_3',
            title: 'Prepare Prior Lab Reports for Consultation',
            description:
                'Keep this verified scan available offline in LifeVault to '
                'show your physician during the follow-up visit.',
          ),
        ],
      );
    }

    if (document.category == DocumentCategory.vehicles ||
        document.documentType == DocumentType.registration) {
      return ActionPlaybook(
        documentId: document.id,
        summary:
            'Vehicle compliance & renewal checklist for $assetLabel ($dueLabel).',
        source: PlaybookSource.deterministicFallback,
        steps: <ActionStep>[
          ActionStep(
            id: '${document.id}_step_1',
            title: 'Copy Vehicle / Registration Identifier',
            description:
                'Keep your registration or chassis reference ready for PUC, '
                'service, or RTO renewal forms.',
            copyableText: copyableId,
          ),
          ActionStep(
            id: '${document.id}_step_2',
            title: 'Verify PUC & Registration Fitness Validity',
            description:
                'Complete emission testing or registration renewal $dueLabel '
                'to avoid traffic penalties.',
          ),
          ActionStep(
            id: '${document.id}_step_3',
            title: 'Keep Insurance & RC Linked in Vault',
            description: 'Ensure both your Registration Certificate and active '
                'Insurance Policy are verified in LifeVault.',
          ),
        ],
      );
    }

    return ActionPlaybook(
      documentId: document.id,
      summary:
          'Preparation checklist for ${document.title} ($dueLabel) based on '
          'your verified local vault record.',
      source: PlaybookSource.deterministicFallback,
      steps: <ActionStep>[
        ActionStep(
          id: '${document.id}_step_1',
          title: 'Keep Document Reference Ready',
          description:
              'Copy the document reference or asset label for quick lookup '
              'when completing this task.',
          copyableText: copyableId,
        ),
        ActionStep(
          id: '${document.id}_step_2',
          title: 'Review Supporting Papers ($dueLabel)',
          description:
              'Check the original document image in LifeVault and gather any '
              'supporting ID or receipt required $dueLabel.',
        ),
        ActionStep(
          id: '${document.id}_step_3',
          title: 'Archive Updated Record After Completion',
          description:
              'Once renewed or completed, update the verified deadline in '
              'LifeVault to keep your dashboard accurate.',
        ),
      ],
    );
  }
}
