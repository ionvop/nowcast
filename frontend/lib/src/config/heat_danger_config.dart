/// Dev-configurable constants for the startup heat-danger dialog.
///
/// On app startup the map page checks whether any crowd-sourced weather
/// reading is dangerously hot and close to the user. These values control
/// that check. They are plain compile-time constants so a developer can tune
/// them without touching the map screen logic.
abstract final class HeatDangerConfig {
  /// Maximum distance (in kilometres) from the user's position within which
  /// a weather location is considered "nearby" for the danger dialog.
  static const double distanceKm = 5.0;

  /// Heat-index threshold (in °C). A weather location is considered
  /// dangerous when its heat index strictly exceeds this value.
  static const double thresholdC = 40.0;

  /// How long to wait after showing the danger dialog before it can appear
  /// again. The last-shown timestamp is persisted via `shared_preferences`,
  /// so the cooldown survives app restarts.

  static const Duration cooldown = Duration(hours: 2);

  /// Shared-preferences key storing the last time the danger dialog was shown
  /// (as a Unix-milliseconds timestamp).
  static const String lastShownKey = 'heat_danger_last_shown';
}