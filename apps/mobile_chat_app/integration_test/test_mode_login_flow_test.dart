import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_chat_app/app/app.dart';

/// Integration test for the test-mode quick login flow.
///
/// Run with:
///   flutter test integration_test/test_mode_login_flow_test.dart \
///     --dart-define=BRICKS_TEST_TOKEN=test-token
///
/// The test requires a runnable target (e.g. Chrome) and the
/// BRICKS_TEST_TOKEN dart-define so the quick-login button is visible.
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
