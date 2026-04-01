import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('BricksApp shows login screen when no auth token', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const BricksApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('Continue with GitHub'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
  });

  testWidgets('BricksApp shows a loading indicator before auth state resolves', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const BricksApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
