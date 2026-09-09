/// Dev-configurable constants for the startup flood-danger dialog.
///
/// On app startup the map page checks whether any crowd-sourced weather
/// reading predicts heavy rain (high QPF) with a high probability of
/// precipitation close to the user. These values control that check. They are
/// plain compile-time constants so a developer can tune them without touching
/// the map screen logic.
abstract final class FloodDangerConfig {
  /// Maximum distance (in kilometres) from the user's position within which
  /// a weather location is considered "nearby" for the danger dialog.
  static const double distanceKm = 15.0;

  /// Quantitative precipitation forecast threshold (in millimetres). A
  /// weather location is considered flood-dangerous when its expected
  /// rainfall strictly exceeds this value.
  static const double qpfThresholdMm = 30.0;

  /// Probability-of-precipitation threshold (as a percentage). A weather
  /// location is considered flood-dangerous only when its chance of
  /// precipitation strictly exceeds this value.
  static const int popThresholdPercent = 50;

  /// How long to wait after showing the danger dialog before it can appear
  /// again. The last-shown timestamp is persisted via `shared_preferences`,
  /// so the cooldown survives app restarts.
  ///
  /// The flood-danger dialog shares the same cooldown as the heat-danger
  /// dialog, so this value must stay in sync with
  /// [HeatDangerConfig.cooldown].
  static const Duration cooldown = Duration(hours: 2);

  /// Shared-preferences key storing the last time the danger dialog was shown
  /// (as a Unix-milliseconds timestamp).
  ///
  /// This deliberately matches [HeatDangerConfig.lastShownKey] so the flood
  /// and heat danger dialogs share a single cooldown.
  static const String lastShownKey = 'heat_danger_last_shown';
}