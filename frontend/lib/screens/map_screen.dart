import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../core/adapters/platform_maps_adapter.dart';
import '../core/api_client.dart';
import '../core/location_service.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/alert_dialog.dart';
import '../widgets/loading_overlay.dart';

/// Map tab: heat-location markers and tap-to-analyze.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.targetLat, this.targetLng});

  /// Optional target coordinates to pan to (e.g. from a post's location).
  final double? targetLat;
  final double? targetLng;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _locationService = const LocationService();
  final _maps = PlatformMapsAdapter();

  GoogleMapController? _mapController;

  bool _loading = false;
  String _progressLabel = '';
  CancelToken? _cancelToken;

  LatLng? _center;
  double? _initialZoom;
  final Set<Marker> _markers = {};
  String? _error;

  // Track markers that are in-progress (loading spinner marker).
  int _loadingMarkerSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    _cancelToken?.cancel();
    final cancel = CancelToken();
    _cancelToken = cancel;

    setState(() {
      _loading = true;
      _error = null;
      _progressLabel = 'Loading geolocation... (1/2)';
    });

    LatLng center;
    if (widget.targetLat != null && widget.targetLng != null) {
      center = LatLng(widget.targetLat!, widget.targetLng!);
      _initialZoom = 13;
      _progressLabel = 'Loading heat locations... (2/2)';
    } else {
      final loc = await _locationService.getCurrentLocation();
      if (!mounted || cancel.isCancelled) return;
      if (loc.denied) {
        setState(() => _loading = false);
        await showAppAlert(
          context,
          message: 'Location access is required to show the map. Please grant '
              'location permission and try again.',
        );
        return;
      }
      center = LatLng(loc.lat!, loc.lng!);
      _initialZoom = 13;
      setState(() => _progressLabel = 'Loading heat locations... (2/2)');
    }

    setState(() => _center = center);

    try {
      final heatJson = await api.post('/heat-locations', data: {}, cancelToken: cancel);
      if (!mounted || cancel.isCancelled) return;
      final list = heatJson is List ? heatJson : const [];
      final heatLocations = list
          .whereType<Map>()
          .map((e) => HeatLocation.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _addHeatLocationMarkers(heatLocations);
    } on ApiCancelledException {
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _addHeatLocationMarkers(List<HeatLocation> locations) {
    setState(() {
      _markers.clear();
      for (final loc in locations) {
        if (loc.heatIndex == null) continue;
        final color = getHeatIndexColor(loc.heatIndex!);
        _markers.add(
          _heatMarker(
            'heat-${loc.id ?? loc.latitude}-${loc.longitude}',
            LatLng(loc.latitude, loc.longitude),
            color,
            loc.heatIndex!,
            loc.createdAt,
          ),
        );
      }
    });
  }

  Marker _heatMarker(
    String id,
    LatLng position,
    Color color,
    double heatIndex,
    String? createdAt,
  ) {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      infoWindow: InfoWindow(
        title: '${heatIndex.toStringAsFixed(1)} °C',
        snippet: 'Recorded: ${_formatTimestamp(createdAt)}',
      ),
      icon: _heatIcon(color),
    );
  }

  BitmapDescriptor _heatIcon(Color color) {
    // Approximate the marker color by hue so it visually matches the scale.
    return BitmapDescriptor.defaultMarkerWithHue(_hueForColor(color));
  }

  double _hueForColor(Color color) {
    // Approximate a hue from the color so default marker hue roughly matches.
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
  }

  String? _formatTimestamp(String? iso) {
    if (iso == null) return 'unknown';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')} '
        '${local.day}/${local.month}';
  }

  Future<void> _onMapTap(LatLng position) async {
    final api = context.read<AppState>().api;
    final cancel = CancelToken();

    // Show a loading spinner marker while analyzing.
    _loadingMarkerSeq++;
    final loadingId = 'loading-$_loadingMarkerSeq';
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(loadingId),
          position: position,
          infoWindow: const InfoWindow(title: 'Analyzing...'),
          icon: BitmapDescriptor.defaultMarkerWithHue(0),
        ),
      );
    });
    // Pan the map to the tapped point.
    await _mapController?.animateCamera(
      CameraUpdate.newLatLng(position),
    );

    try {
      final json = await api.post('/analyze-heat-location', data: {
        'latitude': position.latitude,
        'longitude': position.longitude,
      }, cancelToken: cancel);
      if (!mounted) return;
      final map = json is Map
          ? Map<String, dynamic>.from(json)
          : <String, dynamic>{};
      final heatIndex = (map['heatIndex'] as num?)?.toDouble();

      setState(() => _markers.removeWhere((m) => m.markerId.value == loadingId));

      if (heatIndex == null) {
        await showAppAlert(
          context,
          message: 'Heat index could not be calculated for this location. '
              '(Maybe due to data license restrictions and local market '
              'protections.)',
        );
        return;
      }

      final color = getHeatIndexColor(heatIndex);
      final markerId = 'analyzed-$_loadingMarkerSeq';
      setState(() {
        _markers.add(
          _heatMarker(
            markerId,
            position,
            color,
            heatIndex,
            map['createdAt'] as String?,
          ),
        );
      });
      // (Info windows open on marker tap on most platforms.)
    } on ApiCancelledException {
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == loadingId);
      });
      await showAppAlert(context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == loadingId);
      });
      await showAppAlert(
        context,
        message: 'Could not analyze this location. Please try again.',
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Stack(
        children: [
          if (_center != null) _buildMap(),
          LoadingOverlay(label: _progressLabel),
        ],
      );
    }

    if (_error != null && _center == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF555555)),
          ),
        ),
      );
    }

    if (_center == null) {
      return const SizedBox.shrink();
    }

    return _buildMap();
  }

  Widget _buildMap() {
    if (!_maps.hasKey) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Google Maps is not configured. Provide a client Maps API key via '
            '--dart-define=GOOGLE_MAPS_CLIENT_KEY.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF555555)),
          ),
        ),
      );
    }
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _center!,
        zoom: _initialZoom ?? 13,
      ),
      onMapCreated: _onMapCreated,
      onTap: _onMapTap,
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}
