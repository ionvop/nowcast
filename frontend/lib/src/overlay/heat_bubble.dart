import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';
import '../config/refresh_intervals.dart';
import '../models/weather.dart';
import '../theme/app_theme.dart';
import '../utils/geolocation.dart';
import '../utils/heat_color.dart';
import '../widgets/weather_icon.dart';

/// The compact floating bubble shown over other apps.
///
/// Mirrors the heat-map marker: a circle filled with the current heat-index
/// color, ringed in white, with the current weather condition glyph inside a
/// translucent white badge. The reading is refreshed on mount and then every
/// [refreshInterval] (15 minutes, or 15 seconds when the app is launched with
/// `--dart-define=TEST_INTERVAL=true`).
///
/// Until a reading has been fetched successfully — and whenever location or
/// weather is unavailable — the bubble falls back to the original blue circle
/// with the `auto_awesome` icon, so it always looks intentional.
class HeatBubble extends StatefulWidget {
  const HeatBubble({
    super.key,
    this.size = 56,
    this.api,
    this.positionResolver,
    this.refreshInterval,
  });

  /// Diameter of the bubble in logical pixels.
  final double size;

  /// Injectable client for tests. Defaults to a real [ApiClient].
  final ApiClient? api;

  /// Injectable location resolver for tests. Defaults to
  /// [getPositionSilently], which never prompts for permission.
  final Future<Position?> Function()? positionResolver;

  /// How often to re-read the weather. Defaults to [bubbleRefreshInterval].
  final Duration? refreshInterval;

  @override
  State<HeatBubble> createState() => _HeatBubbleState();
}

class _HeatBubbleState extends State<HeatBubble> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final Future<Position?> Function() _resolvePosition =
      widget.positionResolver ?? getPositionSilently;

  Timer? _timer;

  /// The most recent successfully fetched reading, or null when none has been
  /// fetched yet (the blue fallback is shown).
  Weather? _weather;

  /// Guards against overlapping refreshes when a request outlives the
  /// interval.
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(
      widget.refreshInterval ?? bubbleRefreshInterval,
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Fetches the current weather for the device location.
  ///
  /// Failures are swallowed: the last good reading (or the blue fallback) is
  /// kept so the bubble never flickers or shows an error.
  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final position = await _resolvePosition();
      if (position == null) return;

      final json = await _api.post('weather', <String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
      if (!mounted || json is! Map<String, dynamic>) return;

      final weather = Weather.fromJson(json);
      setState(() => _weather = weather);
    } on Exception {
      // Keep the previous reading (or the fallback).
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weather;
    if (weather == null) {
      return _fallback();
    }

    final size = widget.size;
    final border = size * 0.054; // ~3dp at 56dp, matching the map marker.
    final fillRadius = size / 2 - border;
    final badgeDiameter = fillRadius * 2 * 0.62;
    final iconBaseUri = weather.condition.iconBaseUri;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: getHeatIndexColor(weather.heatIndexC ?? 0),
        border: Border.all(color: Colors.white, width: border),
        boxShadow: _shadow,
      ),
      child: iconBaseUri.isEmpty
          ? null
          : Center(
              child: Container(
                width: badgeDiameter,
                height: badgeDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                child: ClipOval(
                  child: Center(
                    child: WeatherIcon(
                      iconBaseUri: iconBaseUri,
                      size: badgeDiameter,
                      api: widget.api,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  /// The original bubble: a blue circle with the AI sparkle icon.
  Widget _fallback() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.seed,
        boxShadow: _shadow,
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white),
    );
  }

  static const List<BoxShadow> _shadow = <BoxShadow>[
    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
  ];
}
