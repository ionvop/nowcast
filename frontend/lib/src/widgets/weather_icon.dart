import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/app_config.dart';

/// Renders a weather icon from an `iconBaseUri`.
///
/// The API returns a base URI without an extension (e.g.
/// `https://maps.gstatic.com/weather/v1/sunny`). The full URL is built by
/// appending `.svg` (light variant) or `_dark.svg` (dark variant), matching
/// the legacy web app.
///
/// The icon is fetched through the backend proxy endpoint
/// (`GET /api/weather/icon?iconBaseUri=...`) rather than directly from the
/// Google CDN, so the web build avoids CORS errors.
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
    final full = dark ? '${base}_dark.svg' : '$base.svg';
    // Route the icon through the backend proxy to avoid CORS on web.
    return Uri.parse('${AppConfig.baseUrl}/weather/icon')
        .replace(queryParameters: <String, String>{'iconBaseUri': full})
        .toString();
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
    return SvgPicture.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (context) => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: SizedBox(
            width: size * 0.5,
            height: size * 0.5,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
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
