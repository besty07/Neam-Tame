import 'package:flutter_test/flutter_test.dart';
import 'package:lifevault/app/boot.dart';
import 'package:lifevault/core/contracts/contracts.dart';

void main() {
  testWidgets('LifeVault bootstrap smoke test renders app shell and tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LifeVaultApp());
    await tester.pumpAndSettle();

    expect(find.text('LifeVault'), findsOneWidget);
    expect(find.text('Your Local Vault is Empty'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Vault'), findsOneWidget);
    expect(find.text('Ask'), findsOneWidget);
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
