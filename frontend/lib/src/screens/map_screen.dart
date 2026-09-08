import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api/api_client.dart';
import '../models/weather.dart';
import '../models/weather_location.dart';
import '../services/heat_danger_cooldown.dart';
import '../services/settings_controller.dart';
import '../utils/format.dart';
import '../utils/geocode.dart';
import '../utils/geolocation.dart';
import '../utils/heat_color.dart';
import '../utils/heat_danger.dart';
import '../utils/map_focus.dart';
import '../widgets/error_view.dart';
import '../widgets/heat_marker.dart';
import '../widgets/loading_overlay.dart';
import 'settings_screen.dart';

/// Map tab: an interactive map of crowd-sourced weather readings.
///
/// Centers on the user's location, renders colored circular markers for the
/// weather locations, and lets the user tap anywhere to analyze that spot's
/// heat index (loading marker → colored marker → info window).
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  String _progressLabel = 'Loading geolocation... (1/2)';
  String? _error;

  LatLng? _center;
  final Set<Marker> _markers = <Marker>{};

  GoogleMapController? _mapController;
  bool _analyzing = false;
  bool _dialogVisible = false;

  /// Whether the heat-danger vibration loop is currently running. Guards
  /// against starting the loop more than once.
  bool _vibrating = false;

  /// The marker whose custom info card is currently shown, and its data.
  ///
  /// When non-null, the map is centered on this position and the card is shown
  /// pinned to the bottom of the map.
  LatLng? _selectedPosition;
  double? _selectedHeatIndex;
  DateTime? _selectedCreatedAt;
  Weather? _selectedWeather;

  /// Whether the current camera movement was triggered by showing the info
  /// card (centering on a marker). When true, [onCameraMoveStarted] must NOT
  /// close the card; the flag is cleared once the camera settles.
  bool _keepCardOpen = false;

  /// Taps delivered to the map shortly after a dialog is dismissed can be the
  /// tail of the tap that closed the dialog. Ignore taps within this window.
  static const Duration _dialogCooldown = Duration(milliseconds: 350);
  DateTime? _lastDialogClosedAt;

  @override
  void initState() {
    super.initState();
    // Consume a pending center on every focus event (e.g. when a community
    // post's tagged location is tapped), not just when the map is created.
    mapFocus.addListener(_applyPendingCenter);
    _load();
  }

  @override
  void dispose() {
    _stopDangerVibration();
    mapFocus.removeListener(_applyPendingCenter);
    _mapController?.dispose();
    super.dispose();
  }

  /// Applies a pending center requested via [mapFocus] (e.g. from a community
  /// post's tagged location) once the map is ready.
  void _applyPendingCenter() {
    final pending = mapFocus.takePendingCenter();
    if (pending == null) return;
    final controller = _mapController;
    if (controller != null) {
      controller.animateCamera(CameraUpdate.newLatLng(pending));
    } else {
      setState(() => _center = pending);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _progressLabel = 'Loading geolocation... (1/2)';
    });

    try {
      // 1/2 — device location.
      final position = await getPosition(subject: 'the weather map');
      if (!mounted) return;

      setState(() => _progressLabel = 'Loading map... (2/2)');

      // 2/2 — existing weather locations.
      final weatherJson = await _api.post('weather-locations', <String, dynamic>{});
      if (!mounted) return;

      final weatherLocations = _parseWeatherLocations(weatherJson);
      final markers = await _buildMarkers(weatherLocations);

      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _markers
          ..clear()
          ..addAll(markers);
        _loading = false;
      });

      // After the map is ready, check whether any nearby crowd-sourced
      // reading is dangerously hot and, if so, surface a one-time danger dialog
      // (subject to a persisted cooldown).
      await _maybeShowDangerAlert(
        position.latitude,
        position.longitude,
        weatherLocations,
      );
    } on ApiException catch (e) {
      _fail(e.message);
    } on NetworkException catch (e) {
      _fail(e.message);
    } on Exception {
      _fail('Something went wrong while loading the weather map.');
    }
  }

  List<WeatherLocation> _parseWeatherLocations(dynamic json) {
    if (json is! List) return const <WeatherLocation>[];
    return json
        .whereType<Map<String, dynamic>>()
        .map(WeatherLocation.fromJson)
        .toList();
  }

  Future<Set<Marker>> _buildMarkers(List<WeatherLocation> locations) async {
    final markers = <Marker>{};
    for (final location in locations) {
      final heatIndex = location.data?.heatIndexC;
      if (heatIndex == null) continue;
      final icon = await _buildMarkerIcon(location.data);
      markers.add(_markerFor(
        location.latitude,
        location.longitude,
        heatIndex,
        location.createdAt,
        location.data,
        icon,
      ));
    }
    return markers;
  }

  /// Builds the heat-marker bitmap for [weather], overlaying the weather glyph
  /// inside the circle when a condition icon is available.
  ///
  /// Falls back to the plain heat marker when the icon is missing or cannot be
  /// fetched/decoded, so the map stays usable offline.
  Future<BitmapDescriptor> _buildMarkerIcon(Weather? weather) async {
    final color = getHeatIndexColor(weather?.heatIndexC ?? 0);
    final condition = weather?.condition;
    final baseUri = condition?.iconBaseUri ?? '';
    if (baseUri.isEmpty) {
      return buildHeatMarker(color);
    }

    try {
      final bytes = await _api.getBytes(
        'weather/icon',
        query: <String, String>{'iconBaseUri': '$baseUri.svg'},
      );
      final loader = SvgBytesLoader(bytes);
      final info = await vg.loadPicture(loader, null, clipViewbox: true);
      return buildHeatMarkerWithIcon(
        color,
        weatherIcon: info.picture,
        iconSize: info.size,
      );
    } on Exception {
      return buildHeatMarker(color);
    }
  }

  Marker _markerFor(
    double latitude,
    double longitude,
    double heatIndex,
    DateTime? createdAt,
    Weather? weather,
    BitmapDescriptor icon,
  ) {
    final id = MarkerId('heat_$latitude,$longitude');
    return Marker(
      markerId: id,
      position: LatLng(latitude, longitude),
      icon: icon,
      // Consume taps so the native (tiny, truncating) info window never
      // appears; we render our own custom info card instead.
      consumeTapEvents: true,
      onTap: () => _showInfoCard(
        LatLng(latitude, longitude),
        heatIndex,
        createdAt,
        weather,
      ),
      infoWindow: InfoWindow(
        title: 'Heat Index: ${_formatHeat(heatIndex)} °C',
        snippet: buildInfoSnippet(createdAt, weather),
      ),
    );
  }

  /// Shows the custom info card for a marker at [position].
  ///
  /// Centers the map on the marker and pins the card to the bottom of the map,
  /// so no screen-coordinate math is needed.
  void _showInfoCard(
    LatLng position,
    double heatIndex,
    DateTime? createdAt,
    Weather? weather,
  ) {
    setState(() {
      _selectedPosition = position;
      _selectedHeatIndex = heatIndex;
      _selectedCreatedAt = createdAt;
      _selectedWeather = weather;
    });

    final controller = _mapController;
    if (controller != null) {
      // Keep the card open during the programmatic centering animation; the
      // flag is cleared once the camera settles (see onCameraIdle).
      _keepCardOpen = true;
      controller.animateCamera(CameraUpdate.newLatLng(position));
    }
  }

  /// Closes the custom info card, if shown.
  void _closeInfoCard() {
    if (_selectedPosition == null) return;
    setState(() {
      _selectedPosition = null;
      _selectedHeatIndex = null;
      _selectedCreatedAt = null;
      _selectedWeather = null;
    });
  }

  /// Handles a tap on the map itself (not on a marker).
  ///
  /// Closes any open info card, then analyzes the tapped spot.
  void _handleMapTap(LatLng location) {
    _closeInfoCard();
    _analyzeSpot(location);
  }

  Future<void> _analyzeSpot(LatLng location) async {
    if (!_canAnalyzeSpot()) return;
    _analyzing = true;

    final controller = _mapController;
    if (controller != null) {
      await controller.animateCamera(CameraUpdate.newLatLng(location));
    }

    // Loading marker.
    final loadingIcon = await buildLoadingMarker();
    final loadingId =
        MarkerId('loading_${location.latitude},${location.longitude}');
    setState(() {
      _markers.add(
        Marker(markerId: loadingId, position: location, icon: loadingIcon),
      );
    });

    try {
      final json = await _api.post('analyze-weather-location', <String, dynamic>{
        'latitude': location.latitude,
        'longitude': location.longitude,
      });
      if (!mounted) return;

      final result = WeatherLocation.fromJson(
        json is Map<String, dynamic> ? json : <String, dynamic>{},
      );

      setState(() {
        _markers.removeWhere((m) => m.markerId == loadingId);
      });

      final heatIndex = result.data?.heatIndexC;
      if (heatIndex == null) {
        _showHeatUnavailableAlert();
        return;
      }

      final icon = await _buildMarkerIcon(result.data);
      if (!mounted) return;

      final marker = _markerFor(
        result.latitude,
        result.longitude,
        heatIndex,
        result.createdAt,
        result.data,
        icon,
      );
      setState(() {
        _markers.add(marker);
      });

      // Auto-open the custom info card for the freshly analyzed marker so the
      // user immediately sees the heat index, weather and precipitation for
      // the tapped spot.
      _showInfoCard(
        LatLng(result.latitude, result.longitude),
        heatIndex,
        result.createdAt,
        result.data,
      );
    } on ApiException catch (e) {
      _removeLoadingMarker(loadingId);
      _showAlert('Could not analyze this location', e.message);
    } on NetworkException catch (e) {
      _removeLoadingMarker(loadingId);
      _showAlert('Could not analyze this location', e.message);
    } on Exception {
      _removeLoadingMarker(loadingId);
      _showAlert(
        'Could not analyze this location',
        'Something went wrong while analyzing this spot.',
      );
    } finally {
      _analyzing = false;
    }
  }

  bool _canAnalyzeSpot() {
    if (_analyzing || _dialogVisible) return false;
    final closedAt = _lastDialogClosedAt;
    if (closedAt != null) {
      final elapsed = DateTime.now().difference(closedAt);
      if (elapsed < _dialogCooldown) return false;
    }
    return true;
  }

  void _removeLoadingMarker(MarkerId id) {
    if (!mounted) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId == id);
    });
  }

  void _showHeatUnavailableAlert() {
    _showAlert(
      'Heat index unavailable',
      'Heat index could not be calculated for this location. '
      '(Maybe due to data license restrictions and local market protections.)',
    );
  }

  void _showAlert(String title, String message) {
    if (!mounted) return;
    setState(() => _dialogVisible = true);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    ).whenComplete(() {
      if (!mounted) return;
      _stopDangerVibration();
      setState(() {
        _dialogVisible = false;
        _lastDialogClosedAt = DateTime.now();
      });
    });
  }

  /// Starts repeatedly pulsing the phone while the heat-danger dialog is open.
  ///
  /// The loop runs until [_stopDangerVibration] is called, the dialog is
  /// dismissed, or the screen is unmounted. It is fire-and-forget so it does
  /// not block the caller. No-op when vibration is disabled in settings or the
  /// loop is already running.
  void _startDangerVibration() {
    if (_vibrating || !settingsController.isVibrationEnabled) return;
    _vibrating = true;
    () async {
      while (_vibrating && mounted && _dialogVisible) {
        await HapticFeedback.vibrate();
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }();
  }

  /// Stops the heat-danger vibration loop. The loop exits on its next
  /// iteration after [_vibrating] is cleared.
  void _stopDangerVibration() {
    _vibrating = false;
  }

  /// Checks whether any nearby crowd-sourced reading is dangerously hot and, if
  /// so, shows a one-time danger dialog (subject to a persisted cooldown).

  /// Called once after the map finishes loading on startup. No-op when the map
  /// failed to load, when a dialog is already visible, when no nearby
  /// reading exceeds the danger threshold, or when the cooldown is still
  /// active.

  Future<void> _maybeShowDangerAlert(
    double userLat,
    double userLon,
    List<WeatherLocation> locations,
  ) async {
    if (!mounted || _dialogVisible) return;

    final danger = findNearestDanger(
      locations,
      userLat: userLat,
      userLon: userLon,
    );
    if (danger == null) return;

    if (!await heatDangerCooldown.canShow()) return;
    await heatDangerCooldown.recordShown();
    if (!mounted) return;

    final heatIndex = danger.data?.heatIndexC ?? 0;
    final distance = haversineKm(
      userLat,
      userLon,
      danger.latitude,
      danger.longitude,
    );

    // Worst-case address looks up; default to a message without it when the
    // reverse-geocode request fails or returns nothing.
    String address = '';
    try {
      final geocodeJson = await _api.post('geocode', <String, dynamic>{
        'latitude': danger.latitude,
        'longitude': danger.longitude,
      });
      final parsed = addressFromGeocode(geocodeJson);
      if (parsed != null) address = ' at $parsed';
    } on Exception {
      // Leave address empty and show the message without it.
    }

    if (!mounted) return;
    if (settingsController.isVibrationEnabled) {
      _startDangerVibration();
    }
    _showAlert(
      'Heat danger',
      'A nearby weather reading has a heat index of '
      '${heatIndex.toStringAsFixed(1)} °C$address, about '
      '${distance.toStringAsFixed(1)} km from your location. '
      'Take precautions to stay cool and hydrated.',
    );
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  String _formatHeat(double value) => value.toStringAsFixed(1);

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: _openSettings,
        ),
        title: const Text('Heat Map'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return LoadingOverlay(label: _progressLabel);
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    final center = _center;
    if (center == null) {
      return const ErrorView(
        message: 'Unable to determine your location.',
      );
    }
    return IgnorePointer(
      ignoring: _dialogVisible,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 13),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) {
                _mapController = controller;
                _applyPendingCenter();
              },
              onTap: _handleMapTap,
              onCameraMoveStarted: () {
                // Moving the map closes the card — unless the movement is the
                // programmatic centering triggered by showing the card.
                if (!_keepCardOpen) {
                  _closeInfoCard();
                }
              },
              onCameraIdle: () {
                // The centering animation finished; allow future movements to
                // close the card again.
                if (_keepCardOpen) {
                  _keepCardOpen = false;
                }
              },
            ),
          ),
          if (_selectedPosition != null) _buildInfoCard(),
        ],
      ),
    );
  }

  /// Builds the custom info card pinned to the bottom of the map.
  Widget _buildInfoCard() {
    final heatIndex = _selectedHeatIndex;
    final createdAt = _selectedCreatedAt;
    final weather = _selectedWeather;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _InfoCard(
            heatIndex: heatIndex,
            createdAt: createdAt,
            weather: weather,
            onClose: _closeInfoCard,
          ),
        ),
      ),
    );
  }
}

/// A custom info card shown over the map for a selected heat marker.
///
/// The native `google_maps_flutter` info window is text-only and truncates
/// long snippets, so this card renders the full heat-index, time, weather and
/// precipitation details with full layout control.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.heatIndex,
    required this.createdAt,
    required this.weather,
    required this.onClose,
  });

  final double? heatIndex;
  final DateTime? createdAt;
  final Weather? weather;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = weather?.condition.description ?? '';

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Heat Index: ${heatIndex != null ? heatIndex!.toStringAsFixed(1) : '--'} °C',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onClose,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Read at: ${_fmtTimestamp(createdAt!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Weather: $description',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (weather?.precipitationPercent != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Precipitation: ${weather!.precipitationPercent}%',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds the heat-marker info-window snippet: the reading time, plus the
/// current weather condition and precipitation probability when available.
///
/// Each present line is separated by a newline so it reads as a small list in
/// the map info window. Extracted as a top-level function for unit testing.
String buildInfoSnippet(DateTime? createdAt, Weather? weather) {
  final lines = <String>[
    createdAt != null ? 'Read at: ${_fmtTimestamp(createdAt)}' : 'Unknown time',
  ];

  final description = weather?.condition.description ?? '';
  if (description.isNotEmpty) {
    lines.add('Weather: $description');
  }

  final precipitation = weather?.precipitationPercent;
  if (precipitation != null) {
    lines.add('Precipitation: $precipitation%');
  }

  return lines.join('\n');
}

String _fmtTimestamp(DateTime time) {
  return formatTimestamp(time, use24Hour: settingsController.is24Hour);
}