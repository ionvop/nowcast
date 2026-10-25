import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Outcome of [ActivitiesBubbleController.toggle].
enum BubbleToggleResult {
  /// The bubble is now visible over other apps.
  shown,

  /// The bubble was visible and has been hidden.
  hidden,

  /// The "Display over other apps" permission is missing, so nothing was
  /// shown. The user has been sent to the system settings page.
  permissionDenied,

  /// The permission is granted but the overlay window did not come up. This
  /// happens on vendor ROMs (notably MIUI/HyperOS) that silently drop
  /// `TYPE_APPLICATION_OVERLAY` windows unless an extra, non-standard
  /// permission is also enabled.
  failed,
}

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

  /// Whether the overlay window is currently shown.
  ///
  /// The plugin reports `showOverlay()` as successful as soon as the service
  /// start intent has been dispatched, so this is the only reliable way to
  /// tell whether the window actually came up.
  Future<bool> isActive();

  /// The screen size in logical pixels (dp).
  Future<Size> getScreenSize();

  Stream<dynamic> get overlayListener;
}

/// Default [ActivitiesBubblePlatform] backed by `flutter_overlay_window`.
class OverlayWindowBubblePlatform extends ActivitiesBubblePlatform {
  const OverlayWindowBubblePlatform();

  /// Diameter of the compact bubble, in logical pixels (dp).
  static const int bubbleSizeDp = 56;

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
    // Unlike `resizeOverlay`, `showOverlay`'s width/height are used verbatim as
    // `WindowManager.LayoutParams` pixels, so convert from dp to keep the
    // bubble the same physical size on every screen density.
    final dpr = WidgetsBinding
            .instance.platformDispatcher.implicitView?.devicePixelRatio ??
        1.0;
    final size = (bubbleSizeDp * dpr).round();
    await FlutterOverlayWindow.showOverlay(
      height: size,
      width: size,
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
  Future<bool> isActive() async {
    try {
      return await FlutterOverlayWindow.isActive();
    } on Exception {
      return false;
    }
  }

  @override
  Future<Size> getScreenSize() async {
    final size = await FlutterOverlayWindow.getScreenSize();
    return Size(size.x, size.y);
  }

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

  /// How long to wait for the overlay service to report itself as running
  /// after `showOverlay()` returns.
  static const Duration _startupTimeout = Duration(milliseconds: 800);

  /// How often to poll [ActivitiesBubblePlatform.isActive] while waiting for
  /// the overlay service to start.
  static const Duration _startupPollInterval = Duration(milliseconds: 100);

  /// How long to wait for `closeOverlay()` before giving up on it.
  static const Duration _closeTimeout = Duration(seconds: 2);

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
  /// next app resume via [onAppResumed].
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
  /// no-op unless [ensurePermission] scheduled a retry.
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
  /// returns `false` when the overlay permission is missing or the window
  /// could not be created.
  Future<bool> showBubble() async {
    if (!await ensurePermission()) return false;
    return _show();
  }

  /// Hides the floating bubble (the overlay engine keeps running).
  ///
  /// The local state is always cleared, even when the plugin call fails or
  /// never completes, so the Profile toggle can never get stuck on.
  Future<void> hideBubble() async {
    if (!_active) return;
    try {
      await _platform.closeOverlay().timeout(_closeTimeout);
    } on Exception {
      // The overlay may already be gone, or the plugin never completed the
      // call. Either way the window is gone from our point of view.
    } finally {
      _active = false;
      notifyListeners();
    }
  }

  /// Toggles the bubble: shows it when hidden, hides it when visible.
  Future<BubbleToggleResult> toggle() async {
    if (_active) {
      await hideBubble();
      return BubbleToggleResult.hidden;
    }
    if (!await ensurePermission()) return BubbleToggleResult.permissionDenied;
    return await _show() ? BubbleToggleResult.shown : BubbleToggleResult.failed;
  }

  /// Starts the overlay window and waits for it to report itself as running.
  ///
  /// Returns `false` when the plugin throws or the window never comes up.
  Future<bool> _show() async {
    if (_active) return true;
    try {
      await _platform.showOverlay();
    } on Exception {
      return false;
    }
    if (!await _waitUntilActive()) return false;
    _active = true;
    _awaitingPermissionRecheck = false;
    notifyListeners();
    return true;
  }

  /// Polls [ActivitiesBubblePlatform.isActive] until the overlay service has
  /// started, or [_startupTimeout] elapses.
  ///
  /// `showOverlay()` only dispatches a service start intent, so the service is
  /// not necessarily running by the time the call returns.
  Future<bool> _waitUntilActive() async {
    final deadline = DateTime.now().add(_startupTimeout);
    while (true) {
      if (await _platform.isActive()) return true;
      if (!DateTime.now().isBefore(deadline)) return false;
      await Future<void>.delayed(_startupPollInterval);
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
