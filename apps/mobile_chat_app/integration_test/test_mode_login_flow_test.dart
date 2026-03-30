import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_chat_app/app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('quick login appears in test mode and opens chat',
      (tester) async {
    await tester.pumpWidget(const BricksApp());
    await tester.pumpAndSettle();

    expect(find.text('Quick Login (Test)'), findsOneWidget);

    await tester.tap(find.text('Quick Login (Test)'));
    await tester.pumpAndSettle();

    expect(find.text('| New Session'), findsOneWidget);
  });
}
