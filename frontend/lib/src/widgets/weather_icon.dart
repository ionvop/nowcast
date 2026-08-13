import 'package:flutter/material.dart';

/// Renders a weather icon from an `iconBaseUri`.
///
/// The API returns a base URI without an extension (e.g.
/// `https://maps.gstatic.com/weather/v1/sunny`). The full URL is built by
/// appending `.svg` (light variant) or `_dark.svg` (dark variant), matching
/// the legacy web app.
class WeatherIcon extends StatelessWidget {
  const WeatherIcon({
    super.key,
    required this.iconBaseUri,
    this.dark = false,
    this.size = 48,
  });

  /// Base URI from the weather API response.
  final String iconBaseUri;

  /// Whether to use the `_dark` variant (used in the forecast strip).
  final bool dark;

  final double size;

  String get _url {
    final base = iconBaseUri.trim();
    if (base.isEmpty) {
      return '';
    }
    return dark ? '${base}_dark.svg' : '$base.svg';
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.wb_sunny_outlined, size: size * 0.6),
      );
    }
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.wb_cloudy_outlined, size: size * 0.6),
        );
      },
    );
  }
}
