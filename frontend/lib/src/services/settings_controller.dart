import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared-preferences key for the dark-mode flag.
const String kDarkModeKey = 'dark_mode';

/// Manages app-wide user settings, currently just the dark-mode toggle.
///
/// Follows the same singleton [ChangeNotifier] pattern as [AuthController] and
/// [HeatAlertController]: a single instance shared app-wide, with state
/// persisted via `shared_preferences` so the choice survives app restarts.
class SettingsController extends ChangeNotifier {
  bool _initialized = false;
  bool _darkMode = false;

  /// Whether [init] has completed.
  bool get isInitialized => _initialized;

  /// Whether dark mode is enabled. Defaults to light mode (`false`).
  bool get isDarkMode => _darkMode;

  /// Restores the stored settings. Call once at app startup before the first
  /// frame so the correct theme is applied immediately.
  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool(kDarkModeKey) ?? false;
    _initialized = true;
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
}

/// The app-wide [SettingsController] singleton.
final SettingsController settingsController = SettingsController();