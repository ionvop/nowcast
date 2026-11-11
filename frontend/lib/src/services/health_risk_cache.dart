import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/health_risk_assessment.dart';

/// `shared_preferences` key under which the last health-risk assessment is
/// stored.
const String kHealthRiskCacheKey = 'health_risk_assessment';

/// Persists the last generated health-risk assessment so it survives an app
/// restart, along with the date it was generated.
///
/// There is deliberately no expiry: the assessment is a snapshot the user
/// chose to generate, and the UI shows its date so a stale result is obvious.
/// The user clears it explicitly, or regenerates to replace it.
///
/// The [SharedPreferences] instance and clock are injectable so tests can drive
/// the cache deterministically, following [HeatDangerCooldown].
class HealthRiskCache {
  HealthRiskCache({
    this._prefs,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  SharedPreferences? _prefs;
  final DateTime Function() _now;

  /// Reads the cached assessment, or null when there is none.
  ///
  /// Returns null rather than throwing when the stored JSON is corrupt, so a
  /// bad cache can never block the section from rendering.
  Future<HealthRiskAssessment?> read() async {
    try {
      final prefs = await _prefsFor();
      final raw = prefs.getString(kHealthRiskCacheKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      return HealthRiskAssessment.fromJson(decoded);
    } catch (_) {
      // FormatException, ArgumentError, or a platform-channel failure.
      return null;
    }
  }

  /// Stores [assessment], stamped with the current time.
  ///
  /// Returns the stamped copy so the caller can render the same date it
  /// persisted.
  Future<HealthRiskAssessment> write(HealthRiskAssessment assessment) async {
    final stamped = assessment.withGeneratedAt(_now());
    try {
      final prefs = await _prefsFor();
      await prefs.setString(
        kHealthRiskCacheKey,
        jsonEncode(stamped.toJson()),
      );
    } on Exception {
      // The cache is an optimisation, not a requirement.
    }
    return stamped;
  }

  /// Removes the cached assessment.
  Future<void> clear() async {
    try {
      final prefs = await _prefsFor();
      await prefs.remove(kHealthRiskCacheKey);
    } on Exception {
      // Ignore: nothing to recover from.
    }
  }

  Future<SharedPreferences> _prefsFor() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }
}

/// The app-wide [HealthRiskCache] singleton.
final HealthRiskCache healthRiskCache = HealthRiskCache();
