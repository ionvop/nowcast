import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'heat_alert_service.dart';
import 'notification_permission.dart';

/// Manages the persistent-notification toggles (a master switch plus the
/// heat-alert and health-reminder sub-toggles) and the heat-index danger
/// threshold, and drives the background notification service.
///
/// Follows the same singleton pattern as [AuthController]: a single
/// [ChangeNotifier] instance shared app-wide. The toggles and [threshold] are
/// persisted with `shared_preferences` so the background service isolate (which
/// cannot read this object's memory) can pick them up, and so the service
/// auto-starts on the next app launch while the master toggle is still on.
class HeatAlertController extends ChangeNotifier {
  /// Whether the current platform can host a native background service.
  ///
  /// Injectable so tests can disable the platform bridge; when false the
  /// controller only persists state and does not touch the background-service
  /// plugin.
  ///
  /// [notificationPermission] is injectable for tests; it defaults to a
  /// service backed by `flutter_local_notifications`.
  HeatAlertController({
    bool? nativeServiceAvailable,
    NotificationPermission? notificationPermission,
  })  : _nativeServiceAvailable =
            nativeServiceAvailable ?? _defaultNativeServiceAvailable(),
        _notificationPermission = notificationPermission ??
            _defaultNotificationPermission(
              nativeServiceAvailable ?? _defaultNativeServiceAvailable(),
            );

  final bool _nativeServiceAvailable;
  final NotificationPermission _notificationPermission;

  /// The permission service used when none is injected.
  ///
  /// Platforms without a native background service also have no notification
  /// permission to ask for, so they get a stub that never touches a platform
  /// channel (which keeps widget tests hermetic).
  static NotificationPermission _defaultNotificationPermission(
    bool nativeServiceAvailable,
  ) {
    return nativeServiceAvailable
        ? NotificationPermission()
        : NotificationPermission(
            platform: const UnsupportedNotificationPermissionPlatform(),
          );
  }

  bool _initialized = false;
  bool _notificationsEnabled = false;
  bool _heatAlertEnabled = true;
  bool _healthReminderEnabled = true;
  bool _notificationsBlocked = false;
  double _threshold = kDefaultHeatAlertThreshold;

  /// Whether [init] has completed.
  bool get isInitialized => _initialized;

  /// Whether persistent notifications are enabled (the master toggle).
  bool get isNotificationsEnabled => _notificationsEnabled;

  /// Whether the heat-alert notification is enabled (a sub-toggle).
  bool get isHeatAlertEnabled => _heatAlertEnabled;

  /// Whether the health-reminder notification is enabled (a sub-toggle).
  bool get isHealthReminderEnabled => _healthReminderEnabled;

  /// The heat-index danger threshold in degrees Celsius.
  double get threshold => _threshold;

  /// Whether notifications are enabled in the app but blocked by the OS.
  ///
  /// True when the master toggle is on while the system notification
  /// permission is missing (for example because the user revoked it in the
  /// system settings after enabling it here).
  bool get areNotificationsBlocked =>
      _notificationsEnabled && _notificationsBlocked;

  /// Whether a native background service backs this platform.
  bool get hasNativeBackgroundService => _nativeServiceAvailable;

  static bool _defaultNativeServiceAvailable() {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Restores the stored state and, if the master toggle was left on, ensures
  /// the service keeps running. Call once at app startup.
  ///
  /// Migrates the legacy single-toggle state: when no master preference has
  /// been stored yet, the master inherits the old `heat_alert_enabled` value so
  /// existing users keep their previous behavior.
  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final legacyEnabled = prefs.getBool(kHeatAlertEnabledKey);
    if (prefs.containsKey(kNotificationsEnabledKey)) {
      _notificationsEnabled = prefs.getBool(kNotificationsEnabledKey) ?? false;
    } else {
      _notificationsEnabled = legacyEnabled ?? false;
      await prefs.setBool(kNotificationsEnabledKey, _notificationsEnabled);
    }
    _heatAlertEnabled = legacyEnabled ?? true;
    _healthReminderEnabled =
        prefs.getBool(kHealthReminderEnabledKey) ?? true;
    _threshold =
        prefs.getDouble(kHeatAlertThresholdKey) ?? kDefaultHeatAlertThreshold;
    _initialized = true;

    if (_notificationsEnabled && _nativeServiceAvailable) {
      await FlutterBackgroundService().startService();
    }
    await refreshPermissionState();
    notifyListeners();
  }

  /// Turns persistent notifications on and starts the background service.
  ///
  /// When the platform has a notification permission, it is requested first.
  /// Returns `false` (leaving the toggle off and the service stopped) when the
  /// user does not grant it, so the UI never claims notifications are on while
  /// the OS blocks them.
  Future<bool> enableNotifications() async {
    if (_notificationPermission.isSupported) {
      final status = await _notificationPermission.request();
      _notificationsBlocked =
          status != NotificationPermissionStatus.granted &&
              status != NotificationPermissionStatus.unsupported;
      if (_notificationsBlocked) {
        notifyListeners();
        return false;
      }
    }

    _notificationsEnabled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kNotificationsEnabledKey, true);
    if (_nativeServiceAvailable) {
      await FlutterBackgroundService().startService();
    }
    notifyListeners();
    return true;
  }

  /// Turns persistent notifications off and stops the background service.
  Future<void> disableNotifications() async {
    _notificationsEnabled = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kNotificationsEnabledKey, false);
    if (_nativeServiceAvailable) {
      FlutterBackgroundService().invoke('stopService');
    }
    notifyListeners();
  }

  /// Enables or disables the heat-alert notification and persists the choice.
  ///
  /// When the master toggle is on, the running service is asked to refresh so
  /// the change is reflected immediately.
  Future<void> setHeatAlertEnabled(bool value) async {
    if (value == _heatAlertEnabled) return;
    _heatAlertEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHeatAlertEnabledKey, value);
    _refreshService();
    notifyListeners();
  }

  /// Enables or disables the health-reminder notification and persists the
  /// choice.
  ///
  /// When the master toggle is on, the running service is asked to refresh so
  /// the change is reflected immediately.
  Future<void> setHealthReminderEnabled(bool value) async {
    if (value == _healthReminderEnabled) return;
    _healthReminderEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHealthReminderEnabledKey, value);
    _refreshService();
    notifyListeners();
  }

  /// Updates the danger threshold (°C) and persists it so the background
  /// service picks it up on its next check.
  Future<void> setThreshold(double value) async {
    if (value == _threshold) return;
    _threshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kHeatAlertThresholdKey, value);
    notifyListeners();
  }

  /// Re-reads the OS notification permission without prompting the user.
  ///
  /// Call this when the app resumes so a permission revoked (or granted) in
  /// the system settings is reflected in the UI.
  Future<void> refreshPermissionState() async {
    if (!_notificationPermission.isSupported) return;
    final status = await _notificationPermission.check();
    final blocked = status != NotificationPermissionStatus.granted &&
        status != NotificationPermissionStatus.unsupported;
    if (blocked == _notificationsBlocked) return;
    _notificationsBlocked = blocked;
    notifyListeners();
  }

  /// Opens the OS notification settings for this app.
  Future<void> openNotificationSettings() =>
      _notificationPermission.openSettings();

  /// Asks the running background service to re-run its check immediately so a
  /// sub-toggle change is reflected without waiting for the next tick.
  void _refreshService() {
    if (_nativeServiceAvailable && _notificationsEnabled) {
      FlutterBackgroundService().invoke('refresh');
    }
  }
}

/// The app-wide [HeatAlertController] singleton.
final HeatAlertController heatAlertController = HeatAlertController();
