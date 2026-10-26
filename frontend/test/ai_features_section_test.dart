import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/auth/auth_controller.dart';
import 'package:nowcast/src/overlay/activities_bubble_controller.dart';
import 'package:nowcast/src/widgets/ai_features_section.dart';
import 'package:nowcast/src/widgets/ai_summary_section.dart';
import 'package:nowcast/src/widgets/bubble_toggle_card.dart';

/// Minimal overlay platform fake: permission granted, overlay starts on show.
class _FakeBubblePlatform extends ActivitiesBubblePlatform {
  final StreamController<dynamic> _events = StreamController.broadcast();

  int showOverlayCalls = 0;
  int closeOverlayCalls = 0;
  bool overlayActive = false;

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<bool> showOverlay() async {
    showOverlayCalls++;
    overlayActive = true;
    return true;
  }

  @override
  Future<void> closeOverlay() async {
    closeOverlayCalls++;
    overlayActive = false;
  }

  @override
  Future<bool> isActive() async => overlayActive;

  @override
  Future<Size> getScreenSize() async => const Size(400, 800);

  @override
  Stream<dynamic> get overlayListener => _events.stream;
}

/// A minimal raw current-conditions payload (see API §5.1).
Map<String, dynamic> _conditionsJson() {
  return <String, dynamic>{
    'temperature': <String, dynamic>{'degrees': 33.0, 'unit': 'CELSIUS'},
    'weatherCondition': <String, dynamic>{
      'description': <String, dynamic>{'text': 'Sunny', 'languageCode': 'en'},
      'type': 'CLEAR',
    },
  };
}

Widget _wrap({
  required AuthController auth,
  ActivitiesBubbleController? bubbleController,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: AiFeaturesSection(
          currentConditions: _conditionsJson(),
          auth: auth,
          bubbleController: bubbleController,
        ),
      ),
    ),
  );
}

/// Runs [body] with [platform] as the reported target platform.
///
/// The override is cleared inside the test body because the framework's
/// "foundation debug variable was changed" invariant is verified before
/// `tearDown` runs.
Future<void> _withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('signed out shows the sign-in prompt and no AI features',
      (WidgetTester tester) async {
    final auth = AuthController();

    await tester.pumpWidget(_wrap(auth: auth));

    expect(find.text('AI features'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.byType(AiSummarySection), findsNothing);
    expect(find.byType(BubbleToggleCard), findsNothing);
  });

  testWidgets('signed in shows the AI summary section',
      (WidgetTester tester) async {
    await _withPlatform(TargetPlatform.iOS, () async {
      final auth = AuthController(initialToken: 'test-token');

      await tester.pumpWidget(_wrap(auth: auth));

      expect(find.byType(AiSummarySection), findsOneWidget);
      expect(find.text('Sign in with Google'), findsNothing);
    });
  });

  testWidgets('signed in on Android also shows the bubble toggle',
      (WidgetTester tester) async {
    await _withPlatform(TargetPlatform.android, () async {
      final auth = AuthController(initialToken: 'test-token');

      await tester.pumpWidget(_wrap(auth: auth));

      expect(find.byType(AiSummarySection), findsOneWidget);
      expect(find.byType(BubbleToggleCard), findsOneWidget);
      expect(find.text('Floating AI bubble'), findsOneWidget);
    });
  });

  testWidgets('signed in on iOS hides the bubble toggle',
      (WidgetTester tester) async {
    await _withPlatform(TargetPlatform.iOS, () async {
      final auth = AuthController(initialToken: 'test-token');

      await tester.pumpWidget(_wrap(auth: auth));

      expect(find.byType(AiSummarySection), findsOneWidget);
      expect(find.byType(BubbleToggleCard), findsNothing);
    });
  });

  testWidgets('tapping the bubble switch drives the injected controller',
      (WidgetTester tester) async {
    await _withPlatform(TargetPlatform.android, () async {
      final auth = AuthController(initialToken: 'test-token');
      final platform = _FakeBubblePlatform();
      final bubble = ActivitiesBubbleController(platform: platform);
      addTearDown(bubble.dispose);

      await tester.pumpWidget(_wrap(auth: auth, bubbleController: bubble));

      expect(bubble.isActive, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(platform.showOverlayCalls, 1);
      expect(bubble.isActive, isTrue);
      expect(
        find.text('Showing over other apps. Tap to hide.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('signing out replaces the AI features with the prompt',
      (WidgetTester tester) async {
    await _withPlatform(TargetPlatform.android, () async {
      final auth = AuthController(initialToken: 'test-token');

      await tester.pumpWidget(_wrap(auth: auth));
      expect(find.byType(AiSummarySection), findsOneWidget);

      await auth.signOut();
      await tester.pumpAndSettle();

      expect(find.byType(AiSummarySection), findsNothing);
      expect(find.byType(BubbleToggleCard), findsNothing);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });
  });
}
