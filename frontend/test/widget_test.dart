// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:nowcast/main.dart';

void main() {
  testWidgets('App shell renders with five navigation destinations',
      (WidgetTester tester) async {
    await tester.pumpWidget(const NowcastApp());

    // The root app should be present.
    expect(find.byType(NowcastApp), findsOneWidget);

    // The five bottom navigation destinations should be shown.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Heat Data'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
