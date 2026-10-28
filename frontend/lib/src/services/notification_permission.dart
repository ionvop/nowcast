import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared_preferences key recording that the OS notification permission has
/// been requested at least once.
///
/// Android only shows the `POST_NOTIFICATIONS` dialog a limited number of
/// times; after that `requestNotificationsPermission()` returns `false`
/// without any UI. Remembering that we already asked lets us tell "the user
/// just declined" apart from "the user must change this in system settings".
const String kNotificationPermissionRequestedKey =
    'notification_permission_requested';

/// The state of the OS-level notification permission.
enum NotificationPermissionStatus {
  /// Notifications may be posted.
  granted,

  /// Notifications are blocked, but the user has not been asked yet (or the
  /// system may still show the dialog).
  denied,

  /// Notifications are blocked and the system will no longer show the
  /// permission dialog. The user has to enable them in system settings.
  permanentlyDenied,

  /// The current platform has no notification permission concept.
  unsupported,
}

/// Platform seam for [NotificationPermission].
///
/// Wraps the calls into `package:flutter_local_notifications` so the service
/// can be unit tested with a fake implementation.
abstract class NotificationPermissionPlatform {
  const NotificationPermissionPlatform();

  /// Whether the current platform supports a notification permission.
  bool get isSupported;

  /// Whether the app is currently allowed to post notifications.
  Future<bool> areNotificationsEnabled();

  /// Shows the system permission dialog and returns whether it was granted.
  Future<bool> requestPermission();

  /// Opens the OS notification settings for this app.
  Future<void> openSettings();
}

/// A [NotificationPermissionPlatform] for platforms without notifications.
///
/// Every call reports "unsupported" and never touches a platform channel.
class UnsupportedNotificationPermissionPlatform
    extends NotificationPermissionPlatform {
  const UnsupportedNotificationPermissionPlatform();

  @override
  bool get isSupported => false;

  @override
  Future<bool> areNotificationsEnabled() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> openSettings() async {}
}

/// Default [NotificationPermissionPlatform] backed by
/// `flutter_local_notifications`.
class LocalNotificationsPermissionPlatform
    extends NotificationPermissionPlatform {
  const LocalNotificationsPermissionPlatform();

  FlutterLocalNotificationsPlugin get _plugin =>
      FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<bool> areNotificationsEnabled() async {
    final android = _android;
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _ios;
    if (ios != null) {
      final options = await ios.checkPermissions();
      return options?.isEnabled ?? false;
    }
    return false;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            sound: true,
            badge: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<void> openSettings() async {
    final android = _android;
    if (android != null) {
      await android.openAppNotificationSettings();
      return;
    }
    final ios = _ios;
    if (ios != null) {
      await ios.openAppNotificationSettings();
    }
  }
}

/// Checks and requests the OS-level notification permission.
///
/// On Android 13+ this drives the `POST_NOTIFICATIONS` runtime permission; on
/// iOS it drives the `UNUserNotificationCenter` authorization. On other
/// platforms every call is a no-op reporting
/// [NotificationPermissionStatus.unsupported].
class NotificationPermission {
  /// Creates a service. [platform] is injectable for tests.
  NotificationPermission({NotificationPermissionPlatform? platform})
      : _platform = platform ?? const LocalNotificationsPermissionPlatform();

  final NotificationPermissionPlatform _platform;

  /// Whether the current platform supports a notification permission.
  bool get isSupported => _platform.isSupported;

  /// Reads the current permission state without prompting the user.
  Future<NotificationPermissionStatus> check() async {
    if (!_platform.isSupported) {
      return NotificationPermissionStatus.unsupported;
    }
    if (await _platform.areNotificationsEnabled()) {
      return NotificationPermissionStatus.granted;
    }
    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested =
        prefs.getBool(kNotificationPermissionRequestedKey) ?? false;
    return alreadyRequested
        ? NotificationPermissionStatus.permanentlyDenied
        : NotificationPermissionStatus.denied;
  }

  /// Requests the permission, prompting the user if the system still allows
  /// it, and returns the resulting state.
  Future<NotificationPermissionStatus> request() async {
    if (!_platform.isSupported) {
      return NotificationPermissionStatus.unsupported;
    }
    if (await _platform.areNotificationsEnabled()) {
      return NotificationPermissionStatus.granted;
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested =
        prefs.getBool(kNotificationPermissionRequestedKey) ?? false;

    final granted = await _platform.requestPermission();
    await prefs.setBool(kNotificationPermissionRequestedKey, true);

    if (granted) return NotificationPermissionStatus.granted;
    return alreadyRequested
        ? NotificationPermissionStatus.permanentlyDenied
        : NotificationPermissionStatus.denied;
  }

  /// Opens the OS notification settings for this app.
  Future<void> openSettings() => _platform.openSettings();
}
