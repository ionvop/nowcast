/// Client-facing Google Maps configuration.
///
/// The Maps SDK key is a build-time **client** key, distinct from the
/// server's `GOOGLE_MAPS_KEY` (which goes through the API proxy and must
/// never be compiled into the app). Provide it per environment with:
///   flutter run --dart-define=GOOGLE_MAPS_CLIENT_KEY=...
abstract final class MapsConfig {
  /// Client Google Maps API key, injected at build time.
  static const String clientKey = String.fromEnvironment(
    'GOOGLE_MAPS_CLIENT_KEY',
  );
}