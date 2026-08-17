import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api/api_client.dart';
import '../models/heat_location.dart';
import '../utils/geolocation.dart';
import '../utils/heat_color.dart';
import '../utils/map_focus.dart';
import '../widgets/error_view.dart';
import '../widgets/heat_marker.dart';
import '../widgets/loading_overlay.dart';

/// Map tab: an interactive map of crowd-sourced heat readings.
///
/// Centers on the user's location, renders colored circular markers for the
/// heat locations, and lets the user tap anywhere to analyze that spot's
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
      final position = await getPosition(subject: 'the heat map');
      if (!mounted) return;

      setState(() => _progressLabel = 'Loading map... (2/2)');

      // 2/2 — existing heat locations.
      final heatJson = await _api.post('heat-locations', <String, dynamic>{});
      if (!mounted) return;

      final heatLocations = _parseHeatLocations(heatJson);
      final markers = await _buildMarkers(heatLocations);

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
      _fail('Something went wrong while loading the heat map.');
    }
  }

  List<HeatLocation> _parseHeatLocations(dynamic json) {
    if (json is! List) return const <HeatLocation>[];
    return json
        .whereType<Map<String, dynamic>>()
        .map(HeatLocation.fromJson)
        .toList();
  }

  Future<Set<Marker>> _buildMarkers(List<HeatLocation> locations) async {
    final markers = <Marker>{};
    for (final location in locations) {
      final heatIndex = location.heatIndex;
      if (heatIndex == null) continue;
      final icon = await buildHeatMarker(getHeatIndexColor(heatIndex));
      markers.add(_markerFor(
        location.latitude,
        location.longitude,
        heatIndex,
        location.createdAt,
        icon,
      ));
    }
    return markers;
  }

  Marker _markerFor(
    double latitude,
    double longitude,
    double heatIndex,
    DateTime? createdAt,
    BitmapDescriptor icon,
  ) {
    final id = MarkerId('heat_$latitude,$longitude');
    return Marker(
      markerId: id,
      position: LatLng(latitude, longitude),
      icon: icon,
      infoWindow: InfoWindow(
        title: 'Heat Index: ${_formatHeat(heatIndex)} °C',
        snippet: createdAt != null ? _formatTimestamp(createdAt) : 'Unknown time',
      ),
    );
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
      final json = await _api.post('analyze-heat-location', <String, dynamic>{
        'latitude': location.latitude,
        'longitude': location.longitude,
      });
      if (!mounted) return;

      final result = HeatLocation.fromJson(
        json is Map<String, dynamic> ? json : <String, dynamic>{},
      );

      setState(() {
        _markers.removeWhere((m) => m.markerId == loadingId);
      });

      final heatIndex = result.heatIndex;
      if (heatIndex == null) {
        _showHeatUnavailableAlert();
        return;
      }

      final icon = await buildHeatMarker(getHeatIndexColor(heatIndex));
      if (!mounted) return;

      final marker = _markerFor(
        result.latitude,
        result.longitude,
        heatIndex,
        result.createdAt,
        icon,
      );
      setState(() {
        _markers.add(marker);
      });
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

  String _formatTimestamp(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      ),
    );
  }
}