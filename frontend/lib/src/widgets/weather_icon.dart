import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../api/api_client.dart';

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
///
/// The SVG bytes are fetched with our own HTTP client and rendered via
/// [SvgPicture.memory] rather than [SvgPicture.network]. This avoids a
/// flutter_svg quirk where a failed network load is cached forever (its
/// `_pending` entry is never cleared on error), which would otherwise leave
/// the icon stuck on the cloud placeholder until the app is restarted. Only
/// *successful* loads are cached, so a failed icon is retried whenever the
/// widget is rebuilt or [retryToken] changes.
class WeatherIcon extends StatefulWidget {
  const WeatherIcon({
    super.key,
    required this.iconBaseUri,
    this.dark = false,
    this.size = 48,
    this.retryToken = 0,
    this.api,
  });

  /// Base URI from the weather API response.
  final String iconBaseUri;

  /// Whether to use the `_dark` variant (used in the forecast strip).
  final bool dark;

  final double size;

  /// Bumped by the parent to force a retry of a previously failed load.
  ///
  /// The home screen increments this on every refresh so that icons which
  /// failed (e.g. because the backend DB was temporarily locked) are fetched
  /// again instead of staying on the cloud placeholder.
  final int retryToken;

  /// Injectable client for tests. Defaults to a real [ApiClient].
  final ApiClient? api;

  @override
  State<WeatherIcon> createState() => _WeatherIconState();
}

class _WeatherIconState extends State<WeatherIcon> {
  /// Cache of successfully decoded icon bytes, keyed by the full icon URL.
  ///
  /// Only successful loads are stored here so that a failed icon is retried
  /// on the next build/refresh rather than being served a stale failure.
  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  Uint8List? _bytes;
  bool _failed = false;

  /// The full Google CDN icon URL (base + `.svg` / `_dark.svg`).
  ///
  /// This is the value sent as the `iconBaseUri` query parameter to the
  /// backend proxy endpoint, and also serves as the cache key.
  String get _iconUrl {
    final base = widget.iconBaseUri.trim();
    if (base.isEmpty) {
      return '';
    }
    return widget.dark ? '${base}_dark.svg' : '$base.svg';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WeatherIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final urlChanged = oldWidget.iconBaseUri != widget.iconBaseUri ||
        oldWidget.dark != widget.dark;
    final retryRequested =
        oldWidget.retryToken != widget.retryToken && _failed;
    if (urlChanged || retryRequested) {
      _load();
    }
  }

  Future<void> _load() async {
    final iconUrl = _iconUrl;
    if (iconUrl.isEmpty) {
      setState(() {
        _bytes = null;
        _failed = false;
      });
      return;
    }

    final cached = _cache[iconUrl];
    if (cached != null) {
      setState(() {
        _bytes = cached;
        _failed = false;
      });
      return;
    }

    final api = widget.api ?? ApiClient();
    try {
      final bytes = await api.getBytes(
        'weather/icon',
        query: <String, String>{'iconBaseUri': iconUrl},
      );
      if (!mounted) return;
      _cache[iconUrl] = bytes;
      setState(() {
        _bytes = bytes;
        _failed = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return SvgPicture.memory(
        bytes,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      );
    }
    if (_failed) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Icon(Icons.wb_cloudy_outlined, size: widget.size * 0.6),
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: SizedBox(
          width: widget.size * 0.5,
          height: widget.size * 0.5,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
