import 'package:flutter_test/flutter_test.dart';
import 'package:lifevault/core/contracts/contracts.dart';
import 'package:lifevault/features/classification/classification.dart';

void main() {
  const service = LifeVaultDocumentExtractionService();

  group('category and type suggestions', () {
    const fixtures = <_ClassificationFixture>[
      _ClassificationFixture(
        'medical prescription',
        'Dr Patel\nPrescription\nTake medicine after meals',
        DocumentCategory.medical,
        DocumentType.prescription,
      ),
      _ClassificationFixture(
        'finance bank statement',
        'Bank Statement\nAccount Number: synthetic-account',
        DocumentCategory.finance,
        DocumentType.other,
      ),
      _ClassificationFixture(
        'appliance warranty',
        'Refrigerator Warranty Certificate',
        DocumentCategory.appliances,
        DocumentType.warranty,
      ),
      _ClassificationFixture(
        'vehicle registration',
        'Vehicle Registration Certificate\nRegistration No: TEST-1234',
        DocumentCategory.vehicles,
        DocumentType.registration,
      ),
      _ClassificationFixture(
        'insurance policy',
        'Motor Insurance Policy\nPolicy Number: DEMO-001',
        DocumentCategory.insurance,
        DocumentType.insurancePolicy,
      ),
      _ClassificationFixture(
        'home utility bill',
        'Electricity Bill\nAmount Due: 500',
        DocumentCategory.homeUtilities,
        DocumentType.bill,
      ),
      _ClassificationFixture(
        'identity document',
        'Passport\nRepublic of Example',
        DocumentCategory.identityPersonal,
        DocumentType.other,
      ),
      _ClassificationFixture(
        'education document',
        'University Enrollment Certificate\nSemester 2',
        DocumentCategory.education,
        DocumentType.certificate,
      ),
      _ClassificationFixture(
        'legal document',
        'Legal Notice\nAgreement between parties',
        DocumentCategory.legalLetters,
        DocumentType.letter,
      ),
      _ClassificationFixture(
        'unknown text defaults safely',
        'A short unrelated handwritten note.',
        DocumentCategory.other,
        DocumentType.other,
      ),
      _ClassificationFixture(
        'invoice remains separate from appliance category',
        'Fridge Tax Invoice\nCash Memo',
        DocumentCategory.appliances,
        DocumentType.invoiceReceipt,
      ),
      _ClassificationFixture(
        'insurance wins a vehicle overlap with stronger evidence',
        'Bike Insurance Policy\nPolicy Period To: 24 Nov 2027',
        DocumentCategory.insurance,
        DocumentType.insurancePolicy,
      ),
    ];

    for (final fixture in fixtures) {
      test(fixture.name, () {
        final result = service.extract(fixture.text);

        expect(result.suggestedCategory, fixture.category);
        expect(result.suggestedType, fixture.type);
        if (fixture.category == DocumentCategory.other) {
          expect(result.categoryEvidence, startsWith('Low confidence:'));
        } else {
          expect(result.categoryEvidence, startsWith('Keyword evidence:'));
        }
      });
    }

    test('empty text reports low-confidence safe fallbacks', () {
      final result = service.extract('   ');

      expect(result.suggestedCategory, DocumentCategory.other);
      expect(result.suggestedType, DocumentType.other);
      expect(result.categoryEvidence, contains('Low confidence'));
      expect(result.typeEvidence, contains('Low confidence'));
    });

    test('suggests a safe asset label without deriving a record', () {
      final result = service.extract('Bike Insurance Policy');

      expect(result.assetNameSuggestion, 'Bike');
      expect(result.suggestedCategory, DocumentCategory.insurance);
    });
  });

  group('labeled deadline extraction', () {
    test('extracts named-month insurance expiry', () {
      final result = service.extract(
        'Insurance Policy\nExpiry Date: 24 Nov 2027',
      );

      expect(result.dateCandidates, hasLength(1));
      final candidate = result.dateCandidates.single;
      expect(candidate.fieldKind, DateFieldKind.expiry);
      expect(candidate.isoDate, '2027-11-24');
      expect(candidate.sourceSnippet, contains('Expiry Date'));
      expect(candidate.ambiguous, isFalse);
      expect(candidate.page, 1);
    });

    test('extracts valid-upto ISO date', () {
      final result = service.extract('Valid Upto: 2028-12-31');

      expect(result.dateCandidates.single.isoDate, '2028-12-31');
      expect(result.dateCandidates.single.fieldKind, DateFieldKind.expiry);
    });

    test('extracts an unambiguous numeric policy end date', () {
      final result = service.extract('Policy Period To: 24/11/2027');

      expect(result.dateCandidates.single.isoDate, '2027-11-24');
    });

    test('extracts warranty-end date', () {
      final result = service.extract('Warranty Ends: 13-02-2028');

      expect(result.dateCandidates.single.fieldKind, DateFieldKind.expiry);
      expect(result.dateCandidates.single.isoDate, '2028-02-13');
    });

    test('extracts payment due date', () {
      final result =
          service.extract('Electricity Bill\nPayment Due: 15 Mar 2028');

      expect(result.dateCandidates.single.fieldKind, DateFieldKind.due);
      expect(result.dateCandidates.single.isoDate, '2028-03-15');
    });

    test('extracts pay-before deadline', () {
      final result = service.extract('Pay Before: 2028-04-30');

      expect(result.dateCandidates.single.fieldKind, DateFieldKind.due);
      expect(result.dateCandidates.single.isoDate, '2028-04-30');
    });

    test('keeps conflicting labeled candidates for user review', () {
      final result = service.extract(
        'Policy Expiry Date: 24 Nov 2027\nValid Until: 25 Nov 2027',
      );

      expect(result.dateCandidates, hasLength(2));
      expect(
        result.dateCandidates.map((candidate) => candidate.isoDate),
        containsAll(<String>['2027-11-24', '2027-11-25']),
      );
    });

    test('uses the date after a label when an issue date appears first', () {
      final result = service.extract(
        'Issue Date: 15 Mar 2027; Expiry Date: 15 Mar 2028',
      );

      expect(result.dateCandidates, hasLength(1));
      expect(result.dateCandidates.single.isoDate, '2028-03-15');
    });

    test('marks ambiguous numeric dates but does not normalize them', () {
      final result = service.extract('Due Date: 01/02/2028');

      final candidate = result.dateCandidates.single;
      expect(candidate.ambiguous, isTrue);
      expect(candidate.isoDate, isNull);
      expect(candidate.confidenceLevel, ConfidenceLevel.low);
    });

    test('rejects impossible dates', () {
      final result = service.extract('Expiry Date: 31/04/2028');

      expect(result.dateCandidates, isEmpty);
    });

    test('keeps two-digit years unverified and unnormalized', () {
      final result = service.extract('Payment Due: 15/03/28');

      final candidate = result.dateCandidates.single;
      expect(candidate.ambiguous, isTrue);
      expect(candidate.isoDate, isNull);
    });

    test('does not turn an issue date into an expiry candidate', () {
      final result = service.extract(
        'Insurance Policy\nIssue Date: 15 Mar 2027\nPolicy Number: DEMO',
      );

      expect(result.dateCandidates, isEmpty);
    });

    test('does not turn a purchase date into an expiry without duration', () {
      final result = service.extract(
        'Fridge Warranty\nPurchase Date: 15 Mar 2027',
      );

      expect(result.dateCandidates, isEmpty);
    });

    test('does not read OCR O as a numeric zero', () {
      final result = service.extract('Expiry Date: 2O/11/2028');

      expect(result.dateCandidates, isEmpty);
    });
  });

  group('derived warranty proposals', () {
    test('derives an explicit warranty end only from clear inputs', () {
      final result = service.extract(
        'Fridge Warranty\nPurchase Date: 15 Mar 2027\nWarranty: 12 months',
      );

      final candidate = result.dateCandidates.single;
      expect(candidate.fieldKind, DateFieldKind.expiry);
      expect(candidate.isoDate, '2028-03-15');
      expect(candidate.isDerived, isTrue);
      expect(candidate.confidenceLevel, ConfidenceLevel.medium);
    });

    test('clamps a derived leap-day anniversary safely', () {
      final result = service.extract(
        'Warranty\nPurchase Date: 29 Feb 2024\nWarranty Duration: 1 year',
      );

      expect(result.dateCandidates.single.isoDate, '2025-02-28');
    });

    test('does not derive from an ambiguous purchase date', () {
      final result = service.extract(
        'Warranty\nPurchase Date: 01/02/2027\nWarranty: 12 months',
      );

      expect(result.dateCandidates, isEmpty);
    });
  });
}

class _ClassificationFixture {
  const _ClassificationFixture(this.name, this.text, this.category, this.type);

  final String name;
  final String text;
  final DocumentCategory category;
  final DocumentType type;
}
