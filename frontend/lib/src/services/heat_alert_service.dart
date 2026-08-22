import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/forecast_hour.dart';
import '../models/weather.dart';
import '../utils/geolocation.dart';

/// Shared_preferences key for whether heat alerts are enabled.
const String kHeatAlertEnabledKey = 'heat_alert_enabled';

/// Shared_preferences key for the heat-index danger threshold (°C).
const String kHeatAlertThresholdKey = 'heat_alert_threshold';

/// The default heat-index threshold (°C) used before the user changes it.
const double kDefaultHeatAlertThreshold = 32.0;

/// How often the background service re-checks the heat index and refreshes
/// the persistent notification.
const Duration kHeatAlertCheckInterval = Duration(minutes: 15);

/// Notification channel used by the heat-alert service.
const String kHeatAlertChannelId = 'heat_alerts';

/// Channel name surfaced in the system notification settings.
const String kHeatAlertChannelName = 'Heat Alerts';

/// Notification id used by the persistent heat-alert status notification.
const int kHeatAlertNotificationId = 9001;

/// The current heat-alert status.
enum HeatAlertStatus { safe, warning, danger }

/// Computes the heat-alert status from the current heat index and the 6-hour
/// forecast.
///
/// Returns [HeatAlertStatus.danger] when the current heat index strictly
/// exceeds [thresholdC], [HeatAlertStatus.warning] when the forecast contains
/// an hour whose heat index exceeds it (but the current reading does not), and
/// [HeatAlertStatus.safe] otherwise. A null/absent reading or empty forecast
/// falls through to [HeatAlertStatus.safe].
HeatAlertStatus determineHeatAlertStatus({
  required double? currentHeatIndexC,
  required List<double?> forecastHeatIndexesC,
  required double thresholdC,
}) {
  if (currentHeatIndexC != null && currentHeatIndexC > thresholdC) {
    return HeatAlertStatus.danger;
  }
  for (final hour in forecastHeatIndexesC) {
    if (hour != null && hour > thresholdC) {
      return HeatAlertStatus.warning;
    }
  }
  return HeatAlertStatus.safe;
}

/// Initializes the background service (Android foreground service / iOS
/// background fetch). Safe to call more than once. On platforms without a
/// native background service (web, desktop) this is a no-op.
Future<void> configureHeatAlertService() async {
  if (!_supportsNativeService) return;

  final service = FlutterBackgroundService();

  const channel = AndroidNotificationChannel(
    kHeatAlertChannelId,
    kHeatAlertChannelName,
    description: 'Live heat-index status and danger alerts.',
    importance: Importance.low,
  );

  final notifications = FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // Runs in a separate Dart isolate so it keeps working when the app is
      // backgrounded or closed.
      onStart: heatAlertOnStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: kHeatAlertChannelId,
      initialNotificationTitle: 'Heat alerts',
      initialNotificationContent: 'Monitoring heat index…',
      foregroundServiceNotificationId: kHeatAlertNotificationId,
      foregroundServiceTypes: const [AndroidForegroundType.specialUse],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: heatAlertOnStart,
      onBackground: heatAlertOnIosBackground,
    ),
  );
}

/// The background-isolate entry point invoked when the service starts on
/// Android (and, in the foreground, on iOS).
///
/// Must be a top-level function so the plugin can retain a callback handle.
@pragma('vm:entry-point')
void heatAlertOnStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final notifications = FlutterLocalNotificationsPlugin();

  service.on('stopService').listen((_) async {
    await notifications.cancel(id: kHeatAlertNotificationId);
    await service.stopSelf();
  });

  // Run an immediate check, then every 15 minutes.
  unawaited(_heatAlertTick(notifications));
  Timer.periodic(kHeatAlertCheckInterval, (_) {
    unawaited(_heatAlertTick(notifications));
  });
}

/// iOS background-fetch entry point. Returns whether a fresh status was
/// computed so the OS can schedule the next fetch.
@pragma('vm:entry-point')
Future<bool> heatAlertOnIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return _heatAlertTick(FlutterLocalNotificationsPlugin());
}

/// Performs one heat-alert check: reads prefs, fetches current + forecast heat
/// index, computes the status, and updates the persistent notification.
///
/// Returns whether the service should keep running (the alert is still
/// enabled). When disabled, the notification is cleared.
Future<bool> _heatAlertTick(
  FlutterLocalNotificationsPlugin notifications,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final enabled = prefs.getBool(kHeatAlertEnabledKey) ?? false;
    if (!enabled) {
      await notifications.cancel(id: kHeatAlertNotificationId);
      return false;
    }

    final threshold =
        prefs.getDouble(kHeatAlertThresholdKey) ?? kDefaultHeatAlertThreshold;

    final api = ApiClient();
    final position = await _resolvePosition();
    if (position == null) {
      // Location unavailable: keep the service alive but report Safe.
      await _showStatus(
        notifications,
        status: HeatAlertStatus.safe,
        currentHeatIndexC: null,
        thresholdC: threshold,
      );
      return true;
    }

    final weatherJson = await api.post('weather', {
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
    final currentHeatIndexC = _weatherHeatIndex(weatherJson);

    final forecastJson = await api.post('forecast', {
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
    final forecastHeatIndexes = _forecastHeatIndexes(forecastJson);

    final status = determineHeatAlertStatus(
      currentHeatIndexC: currentHeatIndexC,
      forecastHeatIndexesC: forecastHeatIndexes,
      thresholdC: threshold,
    );

    await _showStatus(
      notifications,
      status: status,
      currentHeatIndexC: currentHeatIndexC,
      thresholdC: threshold,
    );
    return true;
  } catch (_) {
    // Best-effort: keep the service alive and retry on the next tick.
    return true;
  }
}

/// Reads the current heat index (°C) from a raw `/weather` response.
double? _weatherHeatIndex(dynamic json) {
  if (json is! Map<String, dynamic>) return null;
  return Weather.fromJson(json).heatIndexC;
}

/// Reads the forecast heat indexes (°C) from a raw `/forecast` response.
List<double?> _forecastHeatIndexes(dynamic json) {
  if (json is! Map<String, dynamic>) return const <double?>[];
  final forecast = Forecast.fromJson(json);
  return forecast.hours.map((ForecastHour h) => h.heatIndexC).toList();
}

/// Resolves the current location without throwing, returning null on failure
/// so a location error degrades to "Safe" instead of killing the service.
Future<dynamic> _resolvePosition() async {
  try {
    return await getPosition(subject: 'heat alerts');
  } catch (_) {
    return null;
  }
}

/// Displays (or updates) the persistent heat-alert status notification.
Future<void> _showStatus(
  FlutterLocalNotificationsPlugin notifications, {
  required HeatAlertStatus status,
  required double? currentHeatIndexC,
  required double thresholdC,
}) async {
  final (title, body, _) = _statusText(status, currentHeatIndexC, thresholdC);
  await notifications.show(
    id: kHeatAlertNotificationId,
    title: 'Heat alert',
    body: '$title — $body',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        kHeatAlertChannelId,
        kHeatAlertChannelName,
        icon: 'ic_notification',
        importance: Importance.low,
        priority: Priority.defaultPriority,
        ongoing: true,
        onlyAlertOnce: true,
        showWhen: false,
      ),
      iOS: DarwinNotificationDetails(presentAlert: false, presentSound: false),
    ),
  );
}

/// Human-readable status text.
///
/// Returns `(statusLabel, detail)` where `statusLabel` is "Danger", "Warning"
/// or "Safe" and `detail` summarises the current heat index vs. the threshold.
(String, String, HeatAlertStatus) _statusText(
  HeatAlertStatus status,
  double? currentHeatIndexC,
  double thresholdC,
) {
  final current = currentHeatIndexC == null
      ? '--'
      : '${currentHeatIndexC.toStringAsFixed(1)}°C';
  return switch (status) {
    HeatAlertStatus.danger => (
        'Danger',
        'Heat index is $current, above ${thresholdC.toStringAsFixed(0)}°C.',
        status,
      ),
    HeatAlertStatus.warning => (
        'Warning',
        'High heat index expected in the next 6 hours.',
        status,
      ),
    HeatAlertStatus.safe => (
        'Safe',
        'Heat index is $current (threshold ${thresholdC.toStringAsFixed(0)}°C).',
        status,
      ),
  };
}

/// Whether the current platform can host a persistent background service.
/// flutter_background_service only supports Android and iOS.
bool get _supportsNativeService =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
