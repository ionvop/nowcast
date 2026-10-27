import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nowcast/src/theme/app_theme.dart';
import 'package:nowcast/src/theme/card_style.dart';
import 'package:nowcast/src/widgets/app_card.dart';

/// Wraps [child] in a [MaterialApp] using the app's real theme.
Widget _wrap(Widget child, {bool dark = false}) {
  return MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

/// The outer decoration painted by the [AppCard] under test: the bevel ring
/// that also carries the drop shadows.
BoxDecoration _outerDecoration(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(of: find.byType(AppCard), matching: find.byType(DecoratedBox))
        .first,
  );
  return box.decoration as BoxDecoration;
}

/// The inner decoration painted by the [AppCard] under test: the card face.
BoxDecoration _innerDecoration(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(of: find.byType(AppCard), matching: find.byType(DecoratedBox))
        .last,
  );
  return box.decoration as BoxDecoration;
}

void main() {
  group('AppCard', () {
    testWidgets('paints a bevel ring with a gradient and drop shadows', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AppCard(child: SizedBox(width: 100, height: 100))),
      );

      final outer = _outerDecoration(tester);
      expect(outer.gradient, isA<LinearGradient>());
      expect(outer.boxShadow, isNotNull);
      expect(outer.boxShadow, isNotEmpty);
      expect(outer.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('paints a gradient face inset by the bevel width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AppCard(child: SizedBox(width: 100, height: 100))),
      );

      final inner = _innerDecoration(tester);
      expect(inner.gradient, isA<LinearGradient>());
      expect(inner.borderRadius, BorderRadius.circular(15));

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(Padding),
            )
            .last,
      );
      expect(
        padding.padding,
        EdgeInsets.all(CardStyle.bevelWidthValue),
      );
    });

    testWidgets('applies the default card margin', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppCard(child: SizedBox(width: 100, height: 100))),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(
        padding.padding,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );
    });

    testWidgets('honours a custom margin and border radius', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppCard(
            margin: EdgeInsets.zero,
            borderRadius: 12,
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, EdgeInsets.zero);
      expect(_outerDecoration(tester).borderRadius, BorderRadius.circular(12));
      expect(_innerDecoration(tester).borderRadius, BorderRadius.circular(11));
    });

    testWidgets('fires onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          AppCard(
            onTap: () => taps++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      await tester.tap(find.byType(AppCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('is not tappable without onTap', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppCard(child: SizedBox(width: 100, height: 100))),
      );

      expect(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('derives a gradient face from an explicit color', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AppCard(
            color: Color(0xFF00AAFF),
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final inner = _innerDecoration(tester);
      expect(inner.gradient, isA<LinearGradient>());
      expect(inner.color, isNull);
    });

    testWidgets('uses different tokens in dark mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppCard(child: SizedBox(width: 100, height: 100)),
          dark: true,
        ),
      );

      final darkFace = _innerDecoration(tester).gradient! as LinearGradient;
      final darkBevel = _outerDecoration(tester).gradient! as LinearGradient;

      await tester.pumpWidget(
        _wrap(const AppCard(child: SizedBox(width: 100, height: 100))),
      );
      // MaterialApp animates theme changes, so let the transition finish
      // before reading the light-mode tokens.
      await tester.pumpAndSettle();

      final lightFace = _innerDecoration(tester).gradient! as LinearGradient;
      final lightBevel = _outerDecoration(tester).gradient! as LinearGradient;

      expect(darkFace.colors, isNot(lightFace.colors));
      expect(darkBevel.colors, isNot(lightBevel.colors));
    });

    testWidgets('elevated cards cast a stronger shadow', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppCard(child: SizedBox(width: 100, height: 100))),
      );
      final normal = _outerDecoration(tester).boxShadow!;

      await tester.pumpWidget(
        _wrap(
          const AppCard(
            elevated: true,
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );
      final elevated = _outerDecoration(tester).boxShadow!;

      expect(elevated, isNot(normal));
      expect(elevated.first.blurRadius, greaterThan(normal.first.blurRadius));
    });
  });

  group('CardStyle', () {
    testWidgets('light and dark tokens differ', (tester) async {
      late CardStyle light;
      late CardStyle dark;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              light = CardStyle.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              dark = CardStyle.of(context);
              return const SizedBox.shrink();
            },
          ),
          dark: true,
        ),
      );
      // MaterialApp animates theme changes, so let the transition finish
      // before reading the dark-mode tokens.
      await tester.pumpAndSettle();

      expect(light.surfaceGradient, isNot(dark.surfaceGradient));
      expect(light.bevelGradient, isNot(dark.bevelGradient));
      expect(light.shadows, isNot(dark.shadows));
    });
  });
}
