import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unified interface for persisting the auth token.
///
/// Two backends:
/// - **Native**: `flutter_secure_storage` (Keychain / Keystore).
/// - **Web**: `shared_preferences` (localStorage).
///
/// `flutter_secure_storage` must never be called on web — it throws.
abstract class AuthStoreAdapter {
  Future<String?> getToken();
  Future<void> setToken(String token);
  Future<void> clearToken();
}

/// Native secure-storage backend. Never used on web.
class SecureAuthStoreAdapter implements AuthStoreAdapter {
  const SecureAuthStoreAdapter();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'nowcast_auth_token';

  @override
  Future<String?> getToken() => _storage.read(key: _key);

  @override
  Future<void> setToken(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clearToken() => _storage.delete(key: _key);
}

/// Web localStorage backend (via shared_preferences).
class PrefAuthStoreAdapter implements AuthStoreAdapter {
  const PrefAuthStoreAdapter();

  static const _key = 'nowcast_auth_token';

  @override
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  @override
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Returns the appropriate auth-store backend for the current platform.
AuthStoreAdapter createAuthStoreAdapter() {
  if (kIsWeb) return const PrefAuthStoreAdapter();
  return const SecureAuthStoreAdapter();
}