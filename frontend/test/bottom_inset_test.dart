import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/screens/new_post_screen.dart';
import 'package:nowcast/src/screens/privacy_policy_screen.dart';
import 'package:nowcast/src/screens/settings_screen.dart';

/// Pushed routes (Settings, Privacy Policy, New Post, Post detail, Health
/// details) are not hosted by `AppShell`, so nothing above them reserves the
/// system navigation bar inset. Each one wraps its body in a `SafeArea` so the
/// scroll viewport stops above the bar instead of letting the last item sit
/// underneath it.
///
/// These tests pin that behaviour: the route still sees the system inset, and
/// the body's `SafeArea` consumes it so nothing inside is overlapped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const double navBarInset = 34;

  /// Pumps [screen] with a bottom system inset and asserts that [body] sits
  /// inside a `SafeArea` that has consumed the inset.
  Future<void> expectReservesNavBarInset(
    WidgetTester tester,
    Widget screen,
    Finder body,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewPadding = const FakeViewPadding(bottom: navBarInset);
    tester.view.padding = const FakeViewPadding(bottom: navBarInset);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();

    // The route itself still reports the system navigation bar inset...
    expect(
      MediaQuery.paddingOf(tester.element(find.byType(Scaffold))).bottom,
      navBarInset,
      reason: 'The test viewport should report a bottom system inset.',
    );

    // ...and the body's SafeArea consumes it, so the scroll viewport ends
    // above the bar and no content is overlapped.
    expect(
      MediaQuery.paddingOf(tester.element(body)).bottom,
      0,
      reason:
          'The body must be wrapped in a SafeArea that consumes the system '
          'navigation bar inset.',
    );
  }

  testWidgets('Settings screen reserves the navigation bar inset', (
    tester,
  ) async {
    await expectReservesNavBarInset(
      tester,
      const SettingsScreen(),
      find.byType(ListView),
    );
  });

  testWidgets('Privacy Policy screen reserves the navigation bar inset', (
    tester,
  ) async {
    await expectReservesNavBarInset(
      tester,
      const PrivacyPolicyScreen(),
      find.byType(ListView),
    );
  });

  testWidgets('New Post screen reserves the navigation bar inset', (
    tester,
  ) async {
    await expectReservesNavBarInset(
      tester,
      const NewPostScreen(),
      find.byType(SingleChildScrollView),
    );
  });
}
