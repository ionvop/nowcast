import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api/api_client.dart';
import '../models/weather.dart';
import '../models/weather_location.dart';
import '../services/settings_controller.dart';
import '../utils/format.dart';
import '../utils/geolocation.dart';
import '../utils/heat_color.dart';
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

  /// The marker whose custom info card is currently shown, and its data.
  LatLng? _selectedPosition;
  double? _selectedHeatIndex;
  DateTime? _selectedCreatedAt;
  Weather? _selectedWeather;

  /// Screen offset (in the map's coordinate space) of [_selectedPosition].
  Offset? _infoWindowOffset;

  /// Whether the camera is currently animating; the info card is hidden while
  /// it moves and repositioned once it settles.
  bool _cameraMoving = false;

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
      _infoWindowOffset = null;
    });
    _repositionInfoWindow();
  }

  /// Converts the selected marker's geographic position to screen coordinates
  /// and stores it as [_infoWindowOffset], so the card can be positioned over
  /// the marker.
  Future<void> _repositionInfoWindow() async {
    final controller = _mapController;
    final position = _selectedPosition;
    if (controller == null || position == null) return;
    try {
      final screen = await controller.getScreenCoordinate(position);
      if (!mounted) return;
      setState(() {
        _infoWindowOffset = Offset(screen.x.toDouble(), screen.y.toDouble());
      });
    } on Exception {
      // Ignore: the card simply stays hidden until the next reposition.
    }
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
      setState(() {
        _dialogVisible = false;
        _lastDialogClosedAt = DateTime.now();
      });
    });
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
              onTap: _analyzeSpot,
              onCameraMoveStarted: () {
                // Hide the info card while the camera moves; it is repositioned
                // once the camera settles.
                if (_infoWindowOffset != null) {
                  setState(() {
                    _cameraMoving = true;
                    _infoWindowOffset = null;
                  });
                }
              },
              onCameraIdle: () {
                if (_cameraMoving) {
                  setState(() => _cameraMoving = false);
                  _repositionInfoWindow();
                }
              },
            ),
          ),
          if (_selectedPosition != null && _infoWindowOffset != null)
            _buildInfoCard(),
        ],
      ),
    );
  }

  /// Builds the custom info card positioned over the selected marker.
  Widget _buildInfoCard() {
    final offset = _infoWindowOffset!;
    final heatIndex = _selectedHeatIndex;
    final createdAt = _selectedCreatedAt;
    final weather = _selectedWeather;

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -1.0),
        child: _InfoCard(
          heatIndex: heatIndex,
          createdAt: createdAt,
          weather: weather,
          onClose: () {
            setState(() {
              _selectedPosition = null;
              _infoWindowOffset = null;
            });
          },
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