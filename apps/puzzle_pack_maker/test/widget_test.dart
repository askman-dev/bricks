import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_pack_maker/app/puzzle_pack_maker_app.dart';
import 'package:puzzle_pack_maker/features/auth/oauth_callback.dart';
import 'package:puzzle_pack_maker/features/home/puzzle_pack_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows GitHub login before authentication', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PuzzlePackMakerApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Puzzle Pack Maker'), findsOneWidget);
    expect(find.text('Continue with GitHub'), findsOneWidget);
    expect(find.byIcon(Icons.extension_rounded), findsOneWidget);
  });

  testWidgets('renders three tab hello world shell', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PuzzlePackHomeScreen()),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Hello world from Create.'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);

    await tester.tap(find.text('Gallery'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hello world from Gallery.'), findsOneWidget);

    await tester.tap(find.text('Library'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hello world from Library.'), findsOneWidget);
  });

  test('extracts native OAuth token for Puzzle Pack Maker scheme', () {
    final uri = Uri.parse(
      'puzzlepackmaker://auth/github/callback#auth_token=jwt-token',
    );

    expect(isNativeOAuthCallback(uri), isTrue);
    expect(extractOAuthTokenFromUri(uri), 'jwt-token');
  });
}
