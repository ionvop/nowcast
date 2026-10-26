import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nowcast/src/shell/app_bottom_nav.dart';
import 'package:nowcast/src/theme/app_theme.dart';

const List<AppNavDestination> _destinations = <AppNavDestination>[
  AppNavDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
  ),
  AppNavDestination(
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    label: 'Heat Data',
  ),
  AppNavDestination(
    icon: Icons.map_outlined,
    selectedIcon: Icons.map,
    label: 'Map',
  ),
  AppNavDestination(
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    label: 'Community',
  ),
  AppNavDestination(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'Profile',
  ),
];

void main() {
  Future<void> pumpNav(
    WidgetTester tester, {
    int selectedIndex = 0,
    ValueChanged<int>? onSelected,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: AppBottomNav(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected ?? (_) {},
            destinations: _destinations,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders all five destination labels', (tester) async {
    await pumpNav(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Heat Data'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('reports the tapped destination index', (tester) async {
    final taps = <int>[];
    await pumpNav(tester, onSelected: taps.add);

    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    expect(taps, <int>[3]);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(taps, <int>[3, 2]);
  });

  testWidgets('does not report a tap on the already selected destination', (
    tester,
  ) async {
    final taps = <int>[];
    await pumpNav(tester, selectedIndex: 0, onSelected: taps.add);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(taps, isEmpty);
  });

  testWidgets('center destination is the raised circle', (tester) async {
    await pumpNav(tester);

    final circle = find.byKey(const Key('nav-center-circle'));
    expect(circle, findsOneWidget);

    final size = tester.getSize(circle);
    expect(size.width, AppBottomNav.circleDiameter);
    expect(size.height, AppBottomNav.circleDiameter);

    // The circle rises above the top edge of the flat bar.
    final navTop = tester.getTopLeft(find.byType(AppBottomNav)).dy;
    final circleTop = tester.getTopLeft(circle).dy;
    expect(circleTop, moreOrLessEquals(navTop, epsilon: 0.5));
  });

  testWidgets('center circle restyles when selected', (tester) async {
    await pumpNav(tester, selectedIndex: 0);

    BoxDecoration decorationOf() {
      final container = tester.widget<AnimatedContainer>(
        find.byKey(const Key('nav-center-circle')),
      );
      return container.decoration! as BoxDecoration;
    }

    // Unselected: filled with the page background and outlined (fake hole).
    final unselected = decorationOf();
    expect(unselected.gradient, isNull);
    expect(unselected.color, AppTheme.background);
    expect(unselected.border, isNotNull);

    await pumpNav(tester, selectedIndex: 2);

    // Selected: gradient fill, no outline.
    final selected = decorationOf();
    expect(selected.gradient, isA<LinearGradient>());
    expect(selected.color, isNull);
    expect(selected.border, isNotNull);
  });

  testWidgets('bar reserves its total height', (tester) async {
    await pumpNav(tester);

    final size = tester.getSize(find.byType(AppBottomNav));
    expect(size.height, AppBottomNav.totalHeight);
  });

  testWidgets('renders in dark mode', (tester) async {
    await pumpNav(tester, theme: AppTheme.dark());

    expect(find.text('Map'), findsOneWidget);
    expect(find.byKey(const Key('nav-center-circle')), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpNav(tester);

    // A RenderFlex overflow would have been recorded as a test failure.
    expect(tester.takeException(), isNull);
    expect(find.text('Community'), findsOneWidget);
    expect(find.byKey(const Key('nav-center-circle')), findsOneWidget);
  });

  testWidgets('accounts for the bottom gesture inset', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);

    await pumpNav(tester);

    final size = tester.getSize(find.byType(AppBottomNav));
    expect(size.height, AppBottomNav.totalHeight + 34);
  });
}
