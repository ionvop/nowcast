import 'dart:async';

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
    return true;
  }

  @override
  Future<void> closeOverlay() async {
    closeOverlayCalls++;
  }

  @override
  Stream<dynamic> get overlayListener => _events.stream;
}

void main() {
  test('toggle shows the bubble when permission is granted', () async {
    final platform = FakeBubblePlatform.withPermission();
    final controller = ActivitiesBubbleController(platform: platform);

    expect(controller.isActive, isFalse);
    final shown = await controller.toggle();
    expect(shown, isTrue);
    expect(controller.isActive, isTrue);
    expect(platform.showOverlayCalls, 1);

    controller.dispose();
  });

  test('toggle hides the bubble when it is active', () async {
    final platform = FakeBubblePlatform.withPermission();
    final controller = ActivitiesBubbleController(platform: platform);

    await controller.showBubble();
    final shown = await controller.toggle();
    expect(shown, isFalse);
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
}
