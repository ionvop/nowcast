import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Global test configuration for the whole suite.
///
/// `VisibilityDetector` batches visibility callbacks on a 500ms timer by
/// default. In tests that leaves a pending timer at teardown (which fails the
/// test) and delays the entrance animations. Reporting at the end of every
/// frame instead makes the callbacks fire deterministically.
///
/// An in-memory `SharedPreferences` store is installed so the position cache
/// (`lib/src/utils/position_cache.dart`) works without a platform channel.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await testMain();
}
