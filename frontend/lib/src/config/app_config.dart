/// App-wide configuration.
///
/// The base URL adapter is the single place that knows where the Laravel
/// proxy API lives. The app is a standalone client to a remote API and never
/// assumes a shared origin or a proxy path.
///
/// The default points at a local dev server. Override it per environment with:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
abstract final class AppConfig {
  /// Absolute base URL of the Laravel proxy API (no trailing slash).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );
}
