import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../config/app_config.dart';

/// Deep-link scheme used to deliver the OAuth callback back to the app.
///
/// Matches the `nowcast://auth` intent-filter in the Android manifest and the
/// `CFBundleURLTypes` scheme in the iOS Info.plist.
const String kAuthScheme = 'nowcast';

/// Host portion of the deep link (e.g. `nowcast://auth`).
const String kAuthHost = 'auth';

/// `shared_preferences` key under which the Sanctum token is stored.
const String kTokenPrefsKey = 'auth_token';

/// Holds the authenticated user's Bearer token and drives the Google OAuth
/// sign-in / sign-out flow.
///
/// Sign-in uses the backend's redirect endpoint to build the Google consent
/// URL (`GET /api/auth/google/redirect?returnTo=<target>`), opens it in the
/// external browser, and receives the Sanctum token back in a URL fragment
/// (`<returnTo>#token=<sanctum-token>`, or `#error=1` on failure). The token
/// is persisted with `shared_preferences` and surfaced to the UI through this
/// [ChangeNotifier] so screens can react to login/logout.
class AuthController extends ChangeNotifier {
  AuthController({String? baseUrl, AppLinks? appLinks})
      : _api = ApiClient(baseUrl: baseUrl),
        _appLinks = appLinks ?? AppLinks();

  final ApiClient _api;
  final AppLinks _appLinks;

  StreamSubscription<Uri>? _linkSub;

  String? _token;

  /// Whether `init()` has run at least once.
  bool _initialized = false;

  /// The stored Bearer token, or null when signed out.
  String? get token => _token;

  /// True when a token is available.
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// Whether [init] has completed (even if signed out).
  bool get isInitialized => _initialized;

  /// Restores the stored token and starts listening for deep-link callbacks.
  ///
  /// On web, also scans the current URL fragment for a post-consent token
  /// (the browser may land back on the app's URL with `#token=...`).
  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(kTokenPrefsKey);

    if (kIsWeb) {
      await _handleIncomingUri(Uri.base);
    }

    _listenForAuthLinks();

    _initialized = true;
    notifyListeners();
  }

  /// Starts listening for the OAuth deep link that delivers the token.
  void _listenForAuthLinks() {
    _linkSub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) _handleIncomingUri(uri);
    });

    // Cold start: the very first link (web / singleTop relaunch) may not be
    // emitted on the stream, so grab it here if not already handled.
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) _handleIncomingUri(uri);
    });
  }

  /// Builds the backend Google consent URL and opens it in the browser.
  ///
  /// [returnTo] is the fragment target the server redirects back to after
  /// consent: on web the same-origin origin, on native the `nowcast://` deep
  /// link. Throws a [StateError] if the page could not be opened.
  Future<void> signIn() async {
    final target = kIsWeb ? Uri.base.origin : '$kAuthScheme://$kAuthHost';
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/auth/google/redirect',
    ).replace(queryParameters: <String, String>{'returnTo': target});
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw StateError('Could not open the sign-in page.');
    }
  }

  /// Handles an incoming callback URI.
  ///
  /// A `#token=...` fragment persists the token; a `#error=1` fragment signs
  /// the user out (consent was rejected). Non-callback URIs are ignored.
  Future<void> _handleIncomingUri(Uri uri) async {
    final params = Uri.splitQueryString(uri.fragment);
    final token = params['token'];
    if (token != null && token.isNotEmpty) {
      await _saveToken(token);
    } else if (params['error'] == '1') {
      await _clearToken();
    }
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTokenPrefsKey, token);
    notifyListeners();
  }

  /// Ends the session: best-effort server-side logout, then clears the local
  /// token regardless of network outcome.
  Future<void> signOut() async {
    final hadToken = _token;
    if (hadToken != null) {
      try {
        await _api.post('logout', const <String, dynamic>{}, token: hadToken);
      } catch (err) {
        // Best-effort: the server may be unreachable, but we still sign out
        // locally.
      }
    }

    await _clearToken();
  }

  /// Clears the local token and persistence.
  Future<void> _clearToken() async {
    _token = null;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTokenPrefsKey);
    notifyListeners();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }
}

/// The app-wide [AuthController] singleton shared by the shell and screens.
final AuthController authController = AuthController();