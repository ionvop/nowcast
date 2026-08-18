import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'heat_alert_service.dart';

/// Manages the heat-alert toggle and danger threshold, and drives the
/// background notification service.
///
/// Follows the same singleton pattern as [AuthController]: a single
/// [ChangeNotifier] instance shared app-wide. The `enabled` flag and
/// [threshold] are persisted with `shared_preferences` so the background
/// service isolate (which cannot read this object's memory) can pick them up,
/// and so the service auto-starts on the next app launch while the toggle is
/// still on.
class HeatAlertController extends ChangeNotifier {
  /// Whether the current platform can host a native background service.
  ///
  /// Injectable so tests can disable the platform bridge; when false the
  /// controller only persists state and does not touch the background-service
  /// plugin.
  HeatAlertController({bool? nativeServiceAvailable})
      : _nativeServiceAvailable =
            nativeServiceAvailable ?? _defaultNativeServiceAvailable();

  final bool _nativeServiceAvailable;

  bool _initialized = false;
  bool _enabled = false;
  double _threshold = kDefaultHeatAlertThreshold;

  /// Whether [init] has completed.
  bool get isInitialized => _initialized;

  /// Whether heat alerts are currently enabled.
  bool get isEnabled => _enabled;

  /// The heat-index danger threshold in degrees Celsius.
  double get threshold => _threshold;

  /// Whether a native background service backs this platform. Web and desktop
  /// platforms do not run a persistent background service.
  bool get hasNativeBackgroundService => _nativeServiceAvailable;

  static bool _defaultNativeServiceAvailable() {
    return !kIsWeb &&
        defaultTargetPlatform != TargetPlatform.linux &&
        defaultTargetPlatform != TargetPlatform.windows &&
        defaultTargetPlatform != TargetPlatform.macOS;
  }

  /// Restores the stored state and, if the toggle was left on, ensures the
  /// service keeps running. Call once at app startup.
  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(kHeatAlertEnabledKey) ?? false;
    _threshold =
        prefs.getDouble(kHeatAlertThresholdKey) ?? kDefaultHeatAlertThreshold;
    _initialized = true;

    if (_enabled && _nativeServiceAvailable) {
      await FlutterBackgroundService().startService();
    }
    notifyListeners();
  }

  /// Turns heat alerts on and starts the background service.
  Future<void> enable() async {
    _enabled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHeatAlertEnabledKey, true);
    if (_nativeServiceAvailable) {
      await FlutterBackgroundService().startService();
    }
    notifyListeners();
  }

  /// Turns heat alerts off and stops the background service.
  Future<void> disable() async {
    _enabled = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHeatAlertEnabledKey, false);
    if (_nativeServiceAvailable) {
      FlutterBackgroundService().invoke('stopService');
    }
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
}

/// The app-wide [HeatAlertController] singleton.
final HeatAlertController heatAlertController = HeatAlertController();
