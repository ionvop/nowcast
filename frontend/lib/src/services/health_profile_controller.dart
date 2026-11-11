import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../models/health_profile.dart';

/// Loads, saves, and clears the signed-in user's health profile.
///
/// Follows the same singleton [ChangeNotifier] pattern as
/// [SettingsController] and [AuthController]: one instance shared app-wide,
/// with the profile held in memory and mirrored to the backend. The profile
/// lives server-side (rather than in `shared_preferences`) so the AI endpoint
/// can read it directly and so it follows the user across devices.
class HealthProfileController extends ChangeNotifier {
  HealthProfileController({ApiClient? api, AuthController? auth})
      : _api = api ?? ApiClient(),
        _auth = auth ?? authController;

  final ApiClient _api;
  final AuthController _auth;

  HealthProfile? _profile;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  /// The user's profile, or null when they have not entered one.
  HealthProfile? get profile => _profile;

  /// Whether a request is in flight.
  bool get isLoading => _loading;

  /// Whether [load] has completed at least once for the current session.
  bool get isLoaded => _loaded;

  /// The last load/save error, if any.
  String? get error => _error;

  /// Whether the user has a usable profile.
  bool get hasProfile => _profile?.isComplete ?? false;

  /// Fetches the profile from the backend.
  ///
  /// Does nothing when signed out. Pass [force] to refetch even when a profile
  /// is already in memory.
  Future<void> load({bool force = false}) async {
    if (!_auth.isAuthenticated) {
      _profile = null;
      _loaded = false;
      notifyListeners();
      return;
    }
    if (_loading || (_loaded && !force)) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final json = await _api.get('profile/health', token: _auth.token);
      if (json is Map<String, dynamic>) {
        final profile = json['profile'];
        _profile = profile is Map<String, dynamic>
            ? HealthProfile.fromJson(profile)
            : null;
      } else {
        _profile = null;
      }
      _loaded = true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _auth.signOut();
        _profile = null;
        _loaded = false;
      } else {
        _error = e.message;
      }
    } on NetworkException catch (e) {
      _error = e.message;
    } on Exception {
      _error = 'Something went wrong while loading your health details.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Saves [profile] to the backend and stores the returned copy.
  ///
  /// Returns true on success. On failure [error] is set and false is returned
  /// so the caller can keep the form open.
  Future<bool> save(HealthProfile profile) async {
    if (!_auth.isAuthenticated) {
      _error = 'Sign in to save your health details.';
      notifyListeners();
      return false;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final json = await _api.put(
        'profile/health',
        profile.toJson(),
        token: _auth.token,
      );
      if (json is Map<String, dynamic> &&
          json['profile'] is Map<String, dynamic>) {
        _profile = HealthProfile.fromJson(
          json['profile'] as Map<String, dynamic>,
        );
      } else {
        _profile = profile;
      }
      _loaded = true;
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _auth.signOut();
        _error = 'Your session expired. Please sign in again.';
      } else {
        _error = e.message;
      }
      return false;
    } on NetworkException catch (e) {
      _error = e.message;
      return false;
    } on Exception {
      _error = 'Something went wrong while saving your health details.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Deletes the profile from the backend and clears it locally.
  Future<bool> clear() async {
    if (!_auth.isAuthenticated) {
      _profile = null;
      notifyListeners();
      return true;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.delete('profile/health', token: _auth.token);
      _profile = null;
      _loaded = true;
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _auth.signOut();
      }
      _error = e.message;
      return false;
    } on NetworkException catch (e) {
      _error = e.message;
      return false;
    } on Exception {
      _error = 'Something went wrong while clearing your health details.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Drops the in-memory profile without contacting the backend.
  ///
  /// Called on sign-out so one user's health details never linger in memory
  /// for the next session.
  void reset() {
    _profile = null;
    _loaded = false;
    _loading = false;
    _error = null;
    notifyListeners();
  }
}

/// The app-wide [HealthProfileController] singleton.
final HealthProfileController healthProfileController = HealthProfileController();
