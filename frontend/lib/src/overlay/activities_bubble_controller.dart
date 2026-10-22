import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Main-isolate controller for the floating AI activities bubble.
///
/// The bubble itself is rendered by a separate Flutter engine instance
/// (see [overlayMain] in `overlay_main.dart`); this controller only manages
/// the Android "display over other apps" permission and the visibility of
/// the overlay window from inside the main app.
class ActivitiesBubbleController extends ChangeNotifier {
  ActivitiesBubbleController._();

  static final ActivitiesBubbleController instance =
      ActivitiesBubbleController._();

  /// Whether the overlay window is currently shown.
  bool _active = false;

  /// Whether the user has granted the "Display over other apps" permission.
  bool _permissionGranted = false;

  /// Whether the overlay window is currently shown.
  bool get isActive => _active;

  /// Whether the overlay permission has been granted (cached from the last
  /// check; call [ensurePermission] for a fresh check).
  bool get permissionGranted => _permissionGranted;

  /// Checks the overlay permission state and refreshes [permissionGranted].
  Future<bool> checkPermission() async {
    try {
      _permissionGranted = await FlutterOverlayWindow.isPermissionGranted();
    } on Exception {
      _permissionGranted = false;
    }
    notifyListeners();
    return _permissionGranted;
  }

  /// Ensures the overlay permission is granted, opening the system settings
  /// page when it is not. Returns `true` when the permission is granted.
  Future<bool> ensurePermission() async {
    var granted = await checkPermission();
    if (granted) return true;
    try {
      await FlutterOverlayWindow.requestPermission();
      // The user returns from the settings page; re-check.
      granted = await checkPermission();
    } on Exception {
      granted = false;
    }
    return granted;
  }

  /// Shows the floating bubble over other apps.
  ///
  /// Returns `true` when the bubble is (already) visible. Fails silently and
  /// returns `false` when the overlay permission is missing.
  Future<bool> showBubble() async {
    if (!await ensurePermission()) return false;
    if (_active) return true;
    try {
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
      _active = true;
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
      await FlutterOverlayWindow.closeOverlay();
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
}
