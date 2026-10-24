// test/vault/helpers/test_fixtures.dart
// Owner: Developer 3 — D3.6 shared test data
//
// Synthetic VerifiedDocumentInput fixtures. No real personal data.
// Aligned with the actual frozen contracts in lib/core/contracts/.

import 'package:uuid/uuid.dart';
import 'package:lifevault/core/contracts/contracts.dart';

const _uuid = Uuid();

/// Factory for test-only VerifiedDocumentInput objects.
/// Never use real personal documents, policy numbers, or medical data here.
class TestFixtures {
  TestFixtures._();

  // ─── Insurance ────────────────────────────────────────────────────────────────

  static VerifiedDocumentInput bikeInsuranceExpiry({
    required String imagePath,
    String expiryDate = '2027-03-31',
  }) =>
      VerifiedDocumentInput(
        originalTempPath: imagePath,
        title: 'Bike Insurance Policy',
        category: DocumentCategory.insurance,
        documentType: DocumentType.insurancePolicy,
        assetName: 'Bike',
        ocrStatus: OcrStatus.success,
        verificationStatus: VerificationStatus.verified,
        evidenceRecords: [
          EvidenceRecord(
            id: _uuid.v4(),
            documentId: '', // will be overwritten by repository
            fieldKind: DateFieldKind.expiry,
            provenance: EvidenceProvenance.userConfirmed,
            proposedRaw: '31/03/2027',
            proposedIso: expiryDate,
            confirmedIso: expiryDate,
            sourceSnippet: 'Policy expires on 31/03/2027',
            pageNumber: 1,
            isVerified: true,
          ),
        ],
        verifiedDeadlines: [
          VerifiedDeadlineInput(
            kind: DeadlineKind.expiry,
            dateIso: expiryDate,
            evidenceSnippet: 'Policy expires on 31/03/2027',
            reminderOffsetsDays: [30, 7, 1],
          ),
        ],
      );

  // ─── Warranty ─────────────────────────────────────────────────────────────────

  static VerifiedDocumentInput fridgeWarranty({
    required String imagePath,
    String warrantyEnd = '2028-06-15',
  }) =>
      VerifiedDocumentInput(
        originalTempPath: imagePath,
        title: 'Fridge Warranty Card',
        category: DocumentCategory.appliances,
        documentType: DocumentType.warranty,
        assetName: 'Fridge',
        ocrStatus: OcrStatus.success,
        verificationStatus: VerificationStatus.verified,
        evidenceRecords: [
          EvidenceRecord(
            id: _uuid.v4(),
            documentId: '',
            fieldKind: DateFieldKind.expiry,
            provenance: EvidenceProvenance.userConfirmed,
            proposedRaw: '15 Jun 2028',
            proposedIso: warrantyEnd,
            confirmedIso: warrantyEnd,
            sourceSnippet: 'Warranty valid until 15 Jun 2028',
            pageNumber: 1,
            isVerified: true,
          ),
        ],
        verifiedDeadlines: [
          VerifiedDeadlineInput(
            kind: DeadlineKind.expiry,
            dateIso: warrantyEnd,
            evidenceSnippet: 'Warranty valid until 15 Jun 2028',
            reminderOffsetsDays: [30, 7],
          ),
        ],
      );

  // ─── Bill ─────────────────────────────────────────────────────────────────────

  static VerifiedDocumentInput electricityBill({
    required String imagePath,
    String dueDate = '2026-11-15',
  }) =>
      VerifiedDocumentInput(
        originalTempPath: imagePath,
        title: 'Electricity Bill November',
        category: DocumentCategory.homeUtilities,
        documentType: DocumentType.bill,
        ocrStatus: OcrStatus.success,
        verificationStatus: VerificationStatus.verified,
        evidenceRecords: [
          EvidenceRecord(
            id: _uuid.v4(),
            documentId: '',
            fieldKind: DateFieldKind.due,
            provenance: EvidenceProvenance.userConfirmed,
            proposedRaw: '15/11/2026',
            proposedIso: dueDate,
            confirmedIso: dueDate,
            sourceSnippet: 'Pay before 15/11/2026',
            pageNumber: 1,
            isVerified: true,
          ),
        ],
        verifiedDeadlines: [
          VerifiedDeadlineInput(
            kind: DeadlineKind.billDue,
            dateIso: dueDate,
            evidenceSnippet: 'Pay before 15/11/2026',
            reminderOffsetsDays: [7, 1],
          ),
        ],
      );

  // ─── No deadline (medical record) ────────────────────────────────────────────

  static VerifiedDocumentInput medicalRecord({required String imagePath}) =>
      VerifiedDocumentInput(
        originalTempPath: imagePath,
        title: 'Blood Test Report',
        category: DocumentCategory.medical,
        documentType: DocumentType.medicalRecord,
        ocrStatus: OcrStatus.success,
        verificationStatus: VerificationStatus.verified,
        evidenceRecords: const [],
        verifiedDeadlines: const [],
      );

  // ─── Finance / Credit Card Bill ──────────────────────────────────────────────

  static VerifiedDocumentInput creditCardBill({
    required String imagePath,
    String dueDate = '2026-11-01',
  }) =>
      VerifiedDocumentInput(
        originalTempPath: imagePath,
        title: 'Credit Card Statement October',
        category: DocumentCategory.finance,
        documentType: DocumentType.bill,
        assetName: 'Credit Card',
        ocrStatus: OcrStatus.success,
        verificationStatus: VerificationStatus.verified,
        evidenceRecords: [
          EvidenceRecord(
            id: _uuid.v4(),
            documentId: '',
            fieldKind: DateFieldKind.due,
            provenance: EvidenceProvenance.userConfirmed,
            proposedRaw: '01-11-2026',
            proposedIso: dueDate,
            confirmedIso: dueDate,
            sourceSnippet: 'Minimum payment due by 01-11-2026',
            pageNumber: 1,
            isVerified: true,
          ),
        ],
        verifiedDeadlines: [
          VerifiedDeadlineInput(
            kind: DeadlineKind.billDue,
            dateIso: dueDate,
            reminderOffsetsDays: [3, 1],
          ),
        ],
      );

  // ─── Vehicle Registration ────────────────────────────────────────────────────

  static VerifiedDocumentInput vehicleRegistration({
    required String imagePath,
    String expiryDate = '2027-08-20',
  }) =>
      VerifiedDocumentInput(
        originalTempPath: imagePath,
        title: 'Vehicle Registration Certificate',
        category: DocumentCategory.vehicles,
        documentType: DocumentType.registration,
        assetName: 'Car',
        ocrStatus: OcrStatus.success,
        verificationStatus: VerificationStatus.verified,
        evidenceRecords: [
          EvidenceRecord(
            id: _uuid.v4(),
            documentId: '',
            fieldKind: DateFieldKind.expiry,
            provenance: EvidenceProvenance.userConfirmed,
            proposedRaw: '20/08/2027',
            proposedIso: expiryDate,
            confirmedIso: expiryDate,
            sourceSnippet: 'Valid until 20/08/2027',
            pageNumber: 1,
            isVerified: true,
          ),
        ],
        verifiedDeadlines: [
          VerifiedDeadlineInput(
            kind: DeadlineKind.expiry,
            dateIso: expiryDate,
            reminderOffsetsDays: [30, 7],
          ),
        ],
      );

  // ─── Already-overdue ──────────────────────────────────────────────────────────

  static VerifiedDocumentInput overdueInsurance({required String imagePath}) =>
      VerifiedDocumentInput(
        originalTempPath: imagePath,
        title: 'Scooter Insurance (Expired)',
        category: DocumentCategory.insurance,
        documentType: DocumentType.insurancePolicy,
        assetName: 'Scooter',
        ocrStatus: OcrStatus.success,
        verificationStatus: VerificationStatus.verified,
        evidenceRecords: [
          EvidenceRecord(
            id: _uuid.v4(),
            documentId: '',
            fieldKind: DateFieldKind.expiry,
            provenance: EvidenceProvenance.userConfirmed,
            proposedRaw: '01/01/2025',
            proposedIso: '2025-01-01',
            confirmedIso: '2025-01-01',
            sourceSnippet: 'Policy expired on 01/01/2025',
            pageNumber: 1,
            isVerified: true,
          ),
        ],
        verifiedDeadlines: [
          const VerifiedDeadlineInput(
            kind: DeadlineKind.expiry,
            dateIso: '2025-01-01',
            reminderOffsetsDays: [30, 7, 1],
          ),
        ],
      );
}
