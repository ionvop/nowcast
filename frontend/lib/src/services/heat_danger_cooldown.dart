import 'package:shared_preferences/shared_preferences.dart';

import '../config/heat_danger_config.dart';

/// Tracks when the startup heat-danger dialog was last shown, so it can be
/// suppressed for a cooldown period (default 2 hours) that survives app
/// restarts.
///
/// The last-shown timestamp is persisted via `shared_preferences`. The
/// [SharedPreferences] instance and clock are injectable so tests can drive
/// the cooldown deterministically.
class HeatDangerCooldown {
  HeatDangerCooldown({
    this._prefs,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  SharedPreferences? _prefs;
  final DateTime Function() _now;

  /// Whether the danger dialog may be shown right now.
  ///
  /// Returns `true` when it has never been shown, or when the cooldown since
  /// the last time it was shown has elapsed. Returns `false` when it was
  /// shown recently enough that the cooldown is still active.

  Future<bool> canShow() async {
    final prefs = await _prefsFor();
    final lastShownMs = prefs.getInt(HeatDangerConfig.lastShownKey);
    if (lastShownMs == null) return true;
    final elapsed = _now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastShownMs),
    );
    return elapsed >= HeatDangerConfig.cooldown;
  }

  /// Records that the danger dialog was shown right now, so the cooldown
  /// starts counting from this moment.
  Future<void> recordShown() async {
    final prefs = await _prefsFor();
    await prefs.setInt(
      HeatDangerConfig.lastShownKey,
      _now().millisecondsSinceEpoch,
    );
  }

  Future<SharedPreferences> _prefsFor() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }
}

/// The app-wide [HeatDangerCooldown] singleton.

final HeatDangerCooldown heatDangerCooldown = HeatDangerCooldown();