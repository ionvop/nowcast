import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Platform seam for [ActivitiesBubbleController].
///
/// Wraps the calls into `package:flutter_overlay_window` so the controller
/// can be unit tested with a fake implementation.
abstract class ActivitiesBubblePlatform {
  const ActivitiesBubblePlatform();

  Future<bool> isPermissionGranted();

  Future<void> requestPermission();

  Future<bool> showOverlay();

  Future<void> closeOverlay();

  Stream<dynamic> get overlayListener;
}

/// Default [ActivitiesBubblePlatform] backed by `flutter_overlay_window`.
class OverlayWindowBubblePlatform extends ActivitiesBubblePlatform {
  const OverlayWindowBubblePlatform();

  @override
  Future<bool> isPermissionGranted() async {
    try {
      return (await FlutterOverlayWindow.isPermissionGranted()) == true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> requestPermission() => FlutterOverlayWindow.requestPermission();

  @override
  Future<bool> showOverlay() async {
    await FlutterOverlayWindow.showOverlay(
      height: 56,
      width: 56,
      alignment: OverlayAlignment.centerRight,
      flag: OverlayFlag.defaultFlag,
      enableDrag: true,
      positionGravity: PositionGravity.auto,
      overlayTitle: 'Nowcast AI',
      overlayContent: 'Tap for activity suggestions.',
    );
    return true;
  }

  @override
  Future<void> closeOverlay() => FlutterOverlayWindow.closeOverlay();

  @override
  Stream<dynamic> get overlayListener => FlutterOverlayWindow.overlayListener;
}

/// Main-isolate controller for the floating AI activities bubble.
///
/// The bubble itself is rendered by a separate Flutter engine instance
/// (see [overlayMain] in `overlay_main.dart`); this controller only manages
/// the Android "display over other apps" permission and the visibility of
/// the overlay window from inside the main app.
///
/// The controller listens to the overlay event stream so that the Profile
/// toggle stays in sync when the bubble is closed from within the overlay
/// itself (the overlay sends `{'event': 'closed'}`).
class ActivitiesBubbleController extends ChangeNotifier {
  /// Creates the controller. [platform] is injectable for tests.
  ActivitiesBubbleController({
    ActivitiesBubblePlatform platform = const OverlayWindowBubblePlatform(),
  }) : _platform = platform {
    _eventSubscription = platform.overlayListener.listen(_handleOverlayEvent);
  }

  /// Singleton instance used by the app UI.
  static final ActivitiesBubbleController instance =
      ActivitiesBubbleController();

  final ActivitiesBubblePlatform _platform;

  StreamSubscription<dynamic>? _eventSubscription;

  /// Whether the overlay window is currently shown.
  bool _active = false;

  /// Whether the user has granted the "Display over other apps" permission.
  bool _permissionGranted = false;

  /// Set when a settings trip was started but the permission was still
  /// reported as not granted; the controller then retries the show when the
  /// app is resumed (see [onAppResumed]).
  bool _awaitingPermissionRecheck = false;

  /// Whether a permission re-check on app resume is pending.
  bool get awaitingPermissionRecheck => _awaitingPermissionRecheck;

  /// Whether the overlay window is currently shown.
  bool get isActive => _active;

  /// Whether the overlay permission has been granted (cached from the last
  /// check; call [ensurePermission] for a fresh check).
  bool get permissionGranted => _permissionGranted;

  /// Handles events sent from the overlay engine.
  void _handleOverlayEvent(dynamic event) {
    if (event is Map && event['event'] == 'closed') {
      // The overlay closed itself (e.g. the user tapped Close in the chat
      // panel); keep the toggle in sync.
      if (!_active) return;
      _active = false;
      notifyListeners();
    }
  }

  /// Checks the overlay permission state and refreshes [permissionGranted].
  Future<bool> checkPermission() async {
    _permissionGranted = await _platform.isPermissionGranted();
    notifyListeners();
    return _permissionGranted;
  }

  /// Ensures the overlay permission is granted, opening the system settings
  /// page when it is not. Returns `true` when the permission is granted.
  ///
  /// When the permission is still not granted after returning from settings
  /// (the plugin's `requestPermission()` resolves as soon as the settings
  /// page is launched), the controller schedules an automatic retry on the
  /// next app resume via [schedulePermissionRecheck].
  Future<bool> ensurePermission() async {
    var granted = await checkPermission();
    if (granted) return true;
    try {
      await _platform.requestPermission();
      // The plugin returns as soon as the settings page is launched, so the
      // user has most likely not granted yet. Retry when they come back —
      // `main.dart` calls [onAppResumed] from its lifecycle listener.
      granted = await checkPermission();
      if (!granted) {
        _awaitingPermissionRecheck = true;
      }
    } on Exception {
      granted = false;
    }
    return granted;
  }

  /// Re-checks the overlay permission when the app is resumed and shows
  /// the bubble if it was granted in the meantime (e.g. the user enabled
  /// "Display over other apps" in the system settings and came back).
  ///
  /// Call this from an app-lifecycle listener (see `main.dart`); it is a
  /// no-op unless [schedulePermissionRecheck] scheduled a retry.
  Future<void> onAppResumed() async {
    if (!_awaitingPermissionRecheck) return;
    if (await checkPermission()) {
      _awaitingPermissionRecheck = false;
      await showBubble();
    }
  }

  /// Shows the floating bubble over other apps.
  ///
  /// Returns `true` when the bubble is (already) visible. Fails silently and
  /// returns `false` when the overlay permission is missing.
  Future<bool> showBubble() async {
    if (!await ensurePermission()) return false;
    if (_active) return true;
    try {
      await _platform.showOverlay();
      _active = true;
      _awaitingPermissionRecheck = false;
      notifyListeners();
      return true;
    } on Exception {
      return false;
    }
  }

  /// Hides the floating bubble (the overlay engine keeps running).
  Future<void> hideBubble() async {
    if (!_active) return;
    try {
      await _platform.closeOverlay();
    } on Exception {
      // The overlay may already be gone.
    }
    _active = false;
    notifyListeners();
  }

  /// Toggles the bubble: shows it when hidden, hides it when visible.
  Future<bool> toggle() async {
    if (_active) {
      await hideBubble();
      return false;
    }
    return showBubble();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
