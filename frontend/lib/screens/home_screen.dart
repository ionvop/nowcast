import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/location_service.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/alert_dialog.dart';
import '../widgets/loading_overlay.dart';

/// Home tab: current weather, city, and a 6-hour forecast strip.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _locationService = const LocationService();

  bool _loading = false;
  String _progressLabel = '';
  CancelToken? _cancelToken;

  Weather? _weather;
  String? _city;
  List<ForecastHour> _forecast = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
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
      _progressLabel = 'Loading geolocation... (1/4)';
    });

    // Step 1: location
    final loc = await _locationService.getCurrentLocation();
    if (!mounted || cancel.isCancelled) return;
    if (loc.denied) {
      setState(() => _loading = false);
      await showAppAlert(
        context,
        message: 'Location access is required to show your local weather. '
            'Please grant location permission and try again.',
      );
      return;
    }

    try {
      // Step 2: current weather
      setState(() => _progressLabel = 'Fetching current weather... (2/4)');
      final weatherJson = await api.post('/weather', data: {
        'latitude': loc.lat,
        'longitude': loc.lng,
      }, cancelToken: cancel);
      if (!mounted || cancel.isCancelled) return;
      setState(() => _weather = Weather.fromJson(_asMap(weatherJson)));

      // Step 3: reverse geocode city
      setState(() => _progressLabel = 'Locating your city... (3/4)');
      final geoJson = await api.post('/geocode', data: {
        'latitude': loc.lat,
        'longitude': loc.lng,
      }, cancelToken: cancel);
      if (!mounted || cancel.isCancelled) return;
      setState(() => _city = _parseCity(geoJson));

      // Step 4: forecast
      setState(() => _progressLabel = 'Fetching 6h forecast... (4/4)');
      final fcJson = await api.post('/forecast', data: {
        'latitude': loc.lat,
        'longitude': loc.lng,
      }, cancelToken: cancel);
      if (!mounted || cancel.isCancelled) return;
      final hours = (_asMap(fcJson)['forecastHours'] as List?)
          ?.whereType<Map>()
          .map((e) => ForecastHour.fromJson(_asMap(e)))
          .toList();
      setState(() => _forecast = hours ?? const []);
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

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  String? _parseCity(dynamic geoJson) {
    final map = _asMap(geoJson);
    final results = map['results'];
    if (results is List && results.isNotEmpty) {
      final first = results.first;
      if (first is Map) {
        final formatted = first['formatted_address'];
        if (formatted is String) return formatted;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ..._buildContent(),
        if (_loading) LoadingOverlay(label: _progressLabel),
      ],
    );
  }

  List<Widget> _buildContent() {
    if (_loading) return const [];
    if (_error != null) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF555555)),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCurrentWeather(),
            if (_city != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _city!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF555555),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _buildForecastStrip(),
          ],
        ),
      ),
    ];
  }

  Widget _buildCurrentWeather() {
    final w = _weather;
    final iconUri = w?.iconBaseUri;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (iconUri != null)
              SvgPicture.network(
                iconUri,
                height: 64,
                width: 64,
                placeholderBuilder: (_) => const Icon(
                  Icons.cloud_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              w?.description ?? 'Weather unavailable',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              w?.temperature != null
                  ? '${w!.temperature!.toStringAsFixed(1)} °C'
                  : '—',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastStrip() {
    if (_forecast.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No forecast available.',
          style: TextStyle(color: Color(0xFF555555)),
        ),
      );
    }
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _forecast.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final hour = _forecast[i];
          return _ForecastCard(hour: hour);
        },
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.hour});

  final ForecastHour hour;

  @override
  Widget build(BuildContext context) {
    final iconUri = hour.iconBaseUri;
    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        width: 88,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                convertHour(hour.displayHour),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (iconUri != null)
                SvgPicture.network(
                  iconUri,
                  height: 36,
                  width: 36,
                  placeholderBuilder: (_) => const Icon(
                    Icons.cloud_outlined,
                    size: 36,
                    color: Colors.grey,
                  ),
                ),
              Text(
                hour.temperature != null
                    ? '${hour.temperature!.toStringAsFixed(0)} °C'
                    : '—',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
