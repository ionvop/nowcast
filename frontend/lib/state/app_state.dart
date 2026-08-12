// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../core/adapters/auth_store_adapter.dart';
import '../core/api_client.dart';
import '../models/models.dart';

/// Holds the current authenticated user and token.
///
/// The token is persisted via the auth-store adapter (secure storage on
/// native, localStorage on web). The `user` is loaded from `GET /api/profile`
/// when present.
class AuthState extends ChangeNotifier {
  AuthState({required AuthStoreAdapter authStore}) : _authStore = authStore;

  final AuthStoreAdapter _authStore;

  String? _token;
  User? _user;

  String? get token => _token;
  User? get user => _user;
  bool get isSignedIn => _token != null && _token!.isNotEmpty;

  /// Loads the token from the store and, if present, fetches the profile.
  Future<void> restore() async {
    _token = await _authStore.getToken();
    notifyListeners();
  }

  void setToken(String token) {
    _token = token;
    _authStore.setToken(token);
    notifyListeners();
  }

  void setUser(User? user) {
    _user = user;
    notifyListeners();
  }

  Future<void> clear() async {
    _token = null;
    _user = null;
    await _authStore.clearToken();
    notifyListeners();
  }
}

/// Global app state exposed via Provider.
class AppState extends ChangeNotifier {
  AppState({
    required this.api,
    required this.auth,
  });

  final ApiClient api;
  final AuthState auth;

  int _currentTab = 0;
  int get currentTab => _currentTab;
  set currentTab(int value) {
    if (value == _currentTab) return;
    _currentTab = value;
    notifyListeners();
  }
}