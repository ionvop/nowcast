import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nowcast/src/theme/motion.dart';
import 'package:nowcast/src/widgets/fade_slide_in.dart';
import 'package:nowcast/src/widgets/reveal_scope.dart';

/// Wraps [child] in the app-like widget tree: a [RevealScope] above a
/// [MaterialApp] body, matching how the shell provides the scope.
Widget _wrap(
  Widget child, {
  int activation = 0,
  RevealStagger? stagger,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: RevealScope(
        activation: activation,
        stagger: stagger ?? RevealStagger(),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

/// The opacity currently applied by the [FadeSlideIn] under test.
double _opacity(WidgetTester tester) {
  final opacity = tester.widget<Opacity>(
    find
        .descendant(
          of: find.byType(FadeSlideIn),
          matching: find.byType(Opacity),
        )
        .first,
  );
  return opacity.opacity;
}

void main() {
  const child = SizedBox(width: 100, height: 100);

  testWidgets('starts hidden and fades in once visible', (tester) async {
    await tester.pumpWidget(_wrap(const FadeSlideIn(child: child)));

    // The first frame renders the card at its start state.
    expect(_opacity(tester), 0);

    await tester.pumpAndSettle();

    expect(_opacity(tester), 1);
  });

  testWidgets('slides in from the right by default', (tester) async {
    await tester.pumpWidget(_wrap(const FadeSlideIn(child: child)));
    await tester.pump();

    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(FadeSlideIn),
            matching: find.byType(Transform),
          )
          .first,
    );
    // At the start of the animation the card is offset to the right.
    expect(transform.transform.getTranslation().x, AppMotion.revealOffset);
    expect(transform.transform.getTranslation().y, 0);

    await tester.pumpAndSettle();

    final settled = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(FadeSlideIn),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(settled.transform.getTranslation().x, 0);
  });

  testWidgets('slides in from the bottom when asked', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FadeSlideIn(
          direction: RevealDirection.fromBottom,
          child: child,
        ),
      ),
    );
    await tester.pump();

    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(FadeSlideIn),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(transform.transform.getTranslation().x, 0);
    expect(transform.transform.getTranslation().y, AppMotion.revealOffset);
  });

  testWidgets('replays when the tab activation changes', (tester) async {
    await tester.pumpWidget(_wrap(const FadeSlideIn(child: child)));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);

    // Returning to the tab bumps the activation counter.
    await tester.pumpWidget(
      _wrap(const FadeSlideIn(child: child), activation: 1),
    );
    expect(_opacity(tester), 0);

    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
  });

  testWidgets('renders immediately when disabled', (tester) async {
    await tester.pumpWidget(
      _wrap(const FadeSlideIn(enabled: false, child: child)),
    );

    expect(find.byType(Opacity), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('renders immediately when the platform disables animations', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const FadeSlideIn(child: child), disableAnimations: true),
    );

    expect(find.byType(Opacity), findsNothing);
  });

  group('RevealStagger', () {
    test('staggers cards in a batch and caps the delay', () {
      final stagger = RevealStagger();
      final delays = <Duration>[
        for (var i = 0; i < 8; i++) stagger.nextDelay(),
      ];

      expect(delays[0], Duration.zero);
      expect(delays[1], AppMotion.staggerStep);
      expect(delays[2], AppMotion.staggerStep * 2);
      // 70ms * 5 = 350ms, the cap; later cards share it.
      expect(delays[5], AppMotion.staggerMax);
      expect(delays[7], AppMotion.staggerMax);
    });

    test('resets after the batch finishes', () async {
      final stagger = RevealStagger();
      expect(stagger.nextDelay(), Duration.zero);
      expect(stagger.nextDelay(), AppMotion.staggerStep);

      // Let the batch-closing microtask run.
      await Future<void>.delayed(Duration.zero);

      expect(stagger.nextDelay(), Duration.zero);
    });
  });
}
