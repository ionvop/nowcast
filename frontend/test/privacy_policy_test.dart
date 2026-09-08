import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/screens/privacy_policy_screen.dart';
import 'package:nowcast/src/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('privacy policy screen renders its key sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: const PrivacyPolicyScreen()),
    );

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Information We Collect'), findsOneWidget);

    // The remaining sections are below the fold; scroll to each one.
    for (final title in <String>[
      'How We Use Your Information',
      'Third-Party Services',
      'Data Retention',
      'Your Choices and Control',
      'Security',
      'Analytics and Cookies',
      'Contact Us',
      'Changes to This Policy',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('settings screen navigates to the privacy policy on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: const SettingsScreen()),
    );

    // The settings row is present.
    expect(find.text('Privacy Policy'), findsOneWidget);

    // Tapping the row pushes the privacy policy screen.
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    // The privacy policy screen is now shown.
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Information We Collect'), findsOneWidget);
  });
}