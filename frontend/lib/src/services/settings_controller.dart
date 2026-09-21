import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared-preferences key for the dark-mode flag.
const String kDarkModeKey = 'dark_mode';

/// Shared-preferences key for the 24-hour time-format flag.
const String k24HourKey = '24_hour';

/// Shared-preferences key for the heat-danger vibration flag.
const String kVibrationKey = 'vibration';

/// Shared-preferences key for the AI-summary flag.
const String kAiSummaryKey = 'ai_summary';

/// Shared-preferences key for the emergency hotline number.
const String kEmergencyNumberKey = 'emergency_number';

/// The default emergency hotline number used until the user changes it.
const String kDefaultEmergencyNumber = '911';

/// Manages app-wide user settings (dark mode, time format, vibration).
///
/// Follows the same singleton [ChangeNotifier] pattern as [AuthController] and
/// [HeatAlertController]: a single instance shared app-wide, with state
/// persisted via `shared_preferences` so the choice survives app restarts.
class SettingsController extends ChangeNotifier {
  bool _initialized = false;
  bool _darkMode = false;
  bool _is24Hour = false;
  bool _vibration = true;
  bool _aiSummary = false;
  String _emergencyNumber = kDefaultEmergencyNumber;

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

  /// Whether the phone should vibrate when a heat danger alert appears.
  ///
  /// Enabled by default (`true`).
  bool get isVibrationEnabled => _vibration;

  /// Whether the AI summary card is shown on the home page.
  ///
  /// Disabled by default (`false`) so the `POST /api/ai/summary` endpoint is
  /// only hit by users who explicitly opt in.
  bool get isAiSummaryEnabled => _aiSummary;

  /// The emergency hotline number shown on the home page's emergency button.
  ///
  /// Tapping that button opens the dialer pre-filled with this number (no call
  /// is placed automatically). Defaults to `911` until the user changes it.
  String get emergencyNumber => _emergencyNumber;

  /// Restores the stored settings. Call once at app startup before the first
  /// frame so the correct theme is applied immediately.
  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool(kDarkModeKey) ?? false;
    _hasStored24Hour = prefs.containsKey(k24HourKey);
    _is24Hour = prefs.getBool(k24HourKey) ?? false;
    _vibration = prefs.getBool(kVibrationKey) ?? true;
    _aiSummary = prefs.getBool(kAiSummaryKey) ?? false;
    _emergencyNumber =
        prefs.getString(kEmergencyNumberKey) ?? kDefaultEmergencyNumber;
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

  /// Enables or disables heat-danger vibration and persists the choice.
  Future<void> setVibrationEnabled(bool value) async {
    if (value == _vibration) return;
    _vibration = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kVibrationKey, value);
    notifyListeners();
  }

  /// Enables or disables the AI summary card and persists the choice.
  Future<void> setAiSummaryEnabled(bool value) async {
    if (value == _aiSummary) return;
    _aiSummary = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAiSummaryKey, value);
    notifyListeners();
  }

  /// Updates the emergency hotline number and persists the choice.
  ///
  /// The number is trimmed; empty values are ignored so the user can never
  /// leave it blank. Calling with the current value is a no-op.
  Future<void> setEmergencyNumber(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == _emergencyNumber) return;
    _emergencyNumber = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kEmergencyNumberKey, trimmed);
    notifyListeners();
  }
}

/// The app-wide [SettingsController] singleton.
final SettingsController settingsController = SettingsController();