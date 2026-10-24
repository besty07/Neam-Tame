import 'package:flutter_test/flutter_test.dart';
import 'package:lifevault/app/boot.dart';
import 'package:lifevault/core/contracts/contracts.dart';

void main() {
  testWidgets('LifeVault bootstrap smoke test renders app shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LifeVaultApp());

    expect(find.text('LifeVault'), findsOneWidget);
    expect(
      find.textContaining('Photograph it once. Find it instantly.'),
      findsOneWidget,
    );
  });

  test('Frozen contracts serialize and parse enums accurately', () {
    expect(
      DocumentCategory.fromWire('home_utilities'),
      equals(DocumentCategory.homeUtilities),
    );
    expect(
      DocumentCategory.home_utilities,
      equals(DocumentCategory.homeUtilities),
    );
    expect(
      DocumentType.fromWire('insurance_policy'),
      equals(DocumentType.insurancePolicy),
    );
    expect(DateFieldKind.expiry.isDeadlineCandidate, isTrue);
    expect(DateFieldKind.issue.isDeadlineCandidate, isFalse);
  });
}
