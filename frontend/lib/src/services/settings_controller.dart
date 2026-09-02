import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared-preferences key for the dark-mode flag.
const String kDarkModeKey = 'dark_mode';

/// Shared-preferences key for the 24-hour time-format flag.
const String k24HourKey = '24_hour';

/// Manages app-wide user settings (dark mode, time format).
///
/// Follows the same singleton [ChangeNotifier] pattern as [AuthController] and
/// [HeatAlertController]: a single instance shared app-wide, with state
/// persisted via `shared_preferences` so the choice survives app restarts.
class SettingsController extends ChangeNotifier {
  bool _initialized = false;
  bool _darkMode = false;
  bool _is24Hour = false;

  /// Whether the user has explicitly stored a 24-hour time-format preference.
  ///
  /// When `false`, the device's system time format is used as the default.
  bool _hasStored24Hour = false;

  /// Whether the device's time format has already been applied as the default.
  bool _deviceDefaultApplied = false;

  /// Whether [init] has completed.
  bool get isInitialized => _initialized;

  /// Whether dark mode is enabled. Defaults to light mode (`false`).
  bool get isDarkMode => _darkMode;

  /// Whether times are shown in 24-hour (military) format.
  ///
  /// Defaults to the device's system time format when no explicit preference
  /// has been stored, otherwise falls back to 12-hour AM/PM format (`false`).
  bool get is24Hour => _is24Hour;

  /// Restores the stored settings. Call once at app startup before the first
  /// frame so the correct theme is applied immediately.
  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool(kDarkModeKey) ?? false;
    _hasStored24Hour = prefs.containsKey(k24HourKey);
    _is24Hour = prefs.getBool(k24HourKey) ?? false;
    _initialized = true;
    notifyListeners();
  }

  /// Applies the device's system time format as the default when the user has
  /// not stored an explicit preference.
  ///
  /// This is a no-op once a preference has been stored or the device default
  /// has already been applied, so the user's explicit choice always wins.
  void applyDeviceDefault(bool deviceUses24Hour) {
    if (_hasStored24Hour || _deviceDefaultApplied) return;
    _deviceDefaultApplied = true;
    _is24Hour = deviceUses24Hour;
    notifyListeners();
  }

  /// Enables or disables dark mode and persists the choice.
  Future<void> setDarkMode(bool value) async {
    if (value == _darkMode) return;
    _darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDarkModeKey, value);
    notifyListeners();
  }

  /// Enables or disables 24-hour time format and persists the choice.
  Future<void> set24Hour(bool value) async {
    if (value == _is24Hour) return;
    _is24Hour = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(k24HourKey, value);
    notifyListeners();
  }
}

/// The app-wide [SettingsController] singleton.
final SettingsController settingsController = SettingsController();