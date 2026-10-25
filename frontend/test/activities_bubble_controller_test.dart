import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:nowcast/src/overlay/activities_bubble_controller.dart';

/// Records calls and lets tests drive permission state and the overlay
/// event stream.
class FakeBubblePlatform extends ActivitiesBubblePlatform {
  FakeBubblePlatform({this.permissionGranted = false});

  FakeBubblePlatform.withPermission() : permissionGranted = true;

  final StreamController<dynamic> _events = StreamController.broadcast();

  bool permissionGranted;
  int requestPermissionCalls = 0;
  int showOverlayCalls = 0;
  int closeOverlayCalls = 0;
  bool showOverlayThrows = false;

  /// Whether the overlay service reports itself as running. Mirrors the
  /// plugin's `isOverlayActive` flag.
  bool overlayActive = false;

  /// When false, `showOverlay()` succeeds but the service never starts — the
  /// MIUI/HyperOS failure mode.
  bool showOverlayStartsService = true;

  /// When true, `closeOverlay()` never completes (the 0.4.5 plugin bug).
  bool closeOverlayHangs = false;

  Size screenSize = const Size(400, 800);

  /// Emits an event as if it came from the overlay engine.
  void emit(dynamic event) => _events.add(event);

  @override
  Future<bool> isPermissionGranted() async => permissionGranted;

  @override
  Future<void> requestPermission() async {
    requestPermissionCalls++;
    // The plugin resolves as soon as settings is launched; simulate that the
    // user has not granted yet at this point.
  }

  @override
  Future<bool> showOverlay() async {
    if (showOverlayThrows) throw Exception('show failed');
    showOverlayCalls++;
    overlayActive = showOverlayStartsService;
    return true;
  }

  @override
  Future<void> closeOverlay() async {
    closeOverlayCalls++;
    if (closeOverlayHangs) return Completer<void>().future;
    overlayActive = false;
  }

  @override
  Future<bool> isActive() async => overlayActive;

  @override
  Future<Size> getScreenSize() async => screenSize;

  @override
  Stream<dynamic> get overlayListener => _events.stream;
}

void main() {
  test('toggle shows the bubble when permission is granted', () async {
    final platform = FakeBubblePlatform.withPermission();
    final controller = ActivitiesBubbleController(platform: platform);

    expect(controller.isActive, isFalse);
    final result = await controller.toggle();
    expect(result, BubbleToggleResult.shown);
    expect(controller.isActive, isTrue);
    expect(platform.showOverlayCalls, 1);

    controller.dispose();
  });

  test('toggle hides the bubble when it is active', () async {
    final platform = FakeBubblePlatform.withPermission();
    final controller = ActivitiesBubbleController(platform: platform);

    await controller.showBubble();
    final result = await controller.toggle();
    expect(result, BubbleToggleResult.hidden);
    expect(controller.isActive, isFalse);
    expect(platform.closeOverlayCalls, 1);

    controller.dispose();
  });

  test('showBubble returns false when permission is missing', () async {
    final platform = FakeBubblePlatform();
    final controller = ActivitiesBubbleController(platform: platform);

    final shown = await controller.showBubble();
    expect(shown, isFalse);
    expect(platform.showOverlayCalls, 0);
    expect(platform.requestPermissionCalls, 1);

    controller.dispose();
  });

  test('closed event from the overlay deactivates the controller', () async {
    final platform = FakeBubblePlatform.withPermission();
    final controller = ActivitiesBubbleController(platform: platform);

    await controller.showBubble();
    expect(controller.isActive, isTrue);

    var notified = false;
    controller.addListener(() => notified = true);

    platform.emit(<String, dynamic>{'event': 'closed'});
    await Future<void>.delayed(Duration.zero);

    expect(controller.isActive, isFalse);
    expect(notified, isTrue);
    // The plugin was not asked to close again — the overlay closed itself.
    expect(platform.closeOverlayCalls, 0);

    controller.dispose();
  });

  test('unrelated overlay events are ignored', () async {
    final platform = FakeBubblePlatform.withPermission();
    final controller = ActivitiesBubbleController(platform: platform);

    await controller.showBubble();
    platform.emit(<String, dynamic>{'event': 'other'});
    platform.emit('not-a-map');
    await Future<void>.delayed(Duration.zero);

    expect(controller.isActive, isTrue);

    controller.dispose();
  });

  test(
    'closed event when already inactive is a no-op without notification',
    () async {
      final platform = FakeBubblePlatform();
      final controller = ActivitiesBubbleController(platform: platform);

      var notifications = 0;
      controller.addListener(() => notifications++);

      platform.emit(<String, dynamic>{'event': 'closed'});
      await Future<void>.delayed(Duration.zero);

      expect(controller.isActive, isFalse);
      // Only the initial checkPermission notify from construction path —
      // here nothing, since permission was never checked.
      expect(notifications, 0);

      controller.dispose();
    },
  );

  test('showBubble failure keeps the controller inactive', () async {
    final platform = FakeBubblePlatform.withPermission()
      ..showOverlayThrows = true;
    final controller = ActivitiesBubbleController(platform: platform);

    final shown = await controller.showBubble();
    expect(shown, isFalse);
    expect(controller.isActive, isFalse);

    controller.dispose();
  });

  test(
    'onAppResumed is a no-op when no permission re-check is pending',
    () async {
      final platform = FakeBubblePlatform();
      final controller = ActivitiesBubbleController(platform: platform);

      await controller.onAppResumed();
      expect(controller.awaitingPermissionRecheck, isFalse);
      expect(platform.showOverlayCalls, 0);

      controller.dispose();
    },
  );

  test(
    'onAppResumed shows the bubble once the permission was granted',
    () async {
      final platform = FakeBubblePlatform();
      final controller = ActivitiesBubbleController(platform: platform);

      // First toggle: permission missing, opens settings, schedules retry.
      final shown = await controller.showBubble();
      expect(shown, isFalse);
      expect(controller.awaitingPermissionRecheck, isTrue);
      expect(platform.showOverlayCalls, 0);

      // User grants in settings and returns to the app.
      platform.permissionGranted = true;
      await controller.onAppResumed();

      expect(controller.isActive, isTrue);
      expect(controller.awaitingPermissionRecheck, isFalse);
      expect(platform.showOverlayCalls, 1);

      controller.dispose();
    },
  );

  test(
    'onAppResumed keeps waiting when permission is still not granted',
    () async {
      final platform = FakeBubblePlatform();
      final controller = ActivitiesBubbleController(platform: platform);

      await controller.showBubble();
      expect(controller.awaitingPermissionRecheck, isTrue);

      // Still denied after coming back; retry stays scheduled.
      await controller.onAppResumed();
      expect(controller.isActive, isFalse);
      expect(controller.awaitingPermissionRecheck, isTrue);
      expect(platform.showOverlayCalls, 0);

      controller.dispose();
    },
  );

  test(
    'toggle reports failure when the overlay service never starts',
    () async {
      // The MIUI/HyperOS case: the permission is granted and showOverlay()
      // succeeds, but the window never comes up.
      final platform = FakeBubblePlatform.withPermission()
        ..showOverlayStartsService = false;
      final controller = ActivitiesBubbleController(platform: platform);

      final result = await controller.toggle();
      expect(result, BubbleToggleResult.failed);
      expect(controller.isActive, isFalse);

      controller.dispose();
    },
  );

  test('toggle reports permissionDenied when permission is missing', () async {
    final platform = FakeBubblePlatform();
    final controller = ActivitiesBubbleController(platform: platform);

    final result = await controller.toggle();
    expect(result, BubbleToggleResult.permissionDenied);
    expect(controller.isActive, isFalse);
    expect(platform.showOverlayCalls, 0);

    controller.dispose();
  });

  test('hideBubble clears state even when closeOverlay hangs', () async {
    final platform = FakeBubblePlatform.withPermission();
    final controller = ActivitiesBubbleController(platform: platform);

    await controller.showBubble();
    expect(controller.isActive, isTrue);

    // Reproduces the 0.4.5 plugin bug where closeOverlay() never completes.
    platform.closeOverlayHangs = true;
    await controller.hideBubble();

    expect(controller.isActive, isFalse);
    expect(platform.closeOverlayCalls, 1);

    controller.dispose();
  });

  test('toggle can be turned off again after a hung closeOverlay', () async {
    final platform = FakeBubblePlatform.withPermission();
    final controller = ActivitiesBubbleController(platform: platform);

    await controller.showBubble();
    platform.closeOverlayHangs = true;

    expect(await controller.toggle(), BubbleToggleResult.hidden);
    expect(controller.isActive, isFalse);

    // The toggle must not be stuck: a second tap shows the bubble again.
    platform.closeOverlayHangs = false;
    expect(await controller.toggle(), BubbleToggleResult.shown);
    expect(controller.isActive, isTrue);

    controller.dispose();
  });

  test('showBubble waits for the service to report itself active', () async {
    final platform = FakeBubblePlatform.withPermission();
    final controller = ActivitiesBubbleController(platform: platform);

    expect(platform.overlayActive, isFalse);
    final shown = await controller.showBubble();

    expect(shown, isTrue);
    expect(platform.overlayActive, isTrue);
    expect(controller.isActive, isTrue);

    controller.dispose();
  });
}
