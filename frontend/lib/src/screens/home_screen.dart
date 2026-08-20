import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/forecast_hour.dart';
import '../models/weather.dart';
import '../utils/format.dart';
import '../utils/geolocation.dart';
import '../widgets/error_view.dart';
import '../widgets/heat_alert_section.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/weather_icon.dart';
import 'settings_screen.dart';

/// Home tab: current weather condition, icon, temperature, and an hourly
/// forecast strip.
///
/// Requests device location, then sequentially fetches current weather,
/// reverse-geocoded city, and the 6h forecast — updating the progress label
/// each step.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  String _progressLabel = 'Loading geolocation... (1/4)';
  String? _error;

  Weather? _weather;
  String? _city;
  Forecast? _forecast;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _progressLabel = 'Loading geolocation... (1/4)';
    });

    try {
      // 1/4 — device location.
      final position = await getPosition(subject: 'weather');
      if (!mounted) return;

      setState(() => _progressLabel = 'Loading current weather... (2/4)');

      // 2/4 — current weather.
      final weatherJson = await _api.post('weather', {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
      if (!mounted) return;
      final weather = Weather.fromJson(
        weatherJson is Map<String, dynamic> ? weatherJson : <String, dynamic>{},
      );

      setState(() => _progressLabel = 'Loading your city... (3/4)');

      // 3/4 — reverse geocode.
      final geocodeJson = await _api.post('geocode', {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
      if (!mounted) return;
      final city = _cityFromGeocode(geocodeJson);

      setState(() => _progressLabel = 'Loading forecast... (4/4)');

      // 4/4 — 6h forecast.
      final forecastJson = await _api.post('forecast', {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
      if (!mounted) return;
      final forecast = Forecast.fromJson(
        forecastJson is Map<String, dynamic>
            ? forecastJson
            : <String, dynamic>{},
      );

      setState(() {
        _weather = weather;
        _city = city;
        _forecast = forecast;
        _loading = false;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } on NetworkException catch (e) {
      _fail(e.message);
    } on Exception {
      _fail('Something went wrong while loading the weather.');
    }
  }

  String? _cityFromGeocode(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final results = json['results'];
    if (results is! List || results.isEmpty) return null;
    final first = results.first;
    if (first is Map<String, dynamic> && first['formattedAddress'] is String) {
      return first['formattedAddress'] as String;
    }
    return null;
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

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
        title: const Text('Nowcast'),
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
    return _HomeContent(
      weather: _weather,
      city: _city,
      forecast: _forecast,
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.weather,
    required this.city,
    required this.forecast,
  });

  final Weather? weather;
  final String? city;
  final Forecast? forecast;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (city != null && city!.isNotEmpty) ...<Widget>[
            Text(
              city!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
          _CurrentWeatherCard(weather: weather),
          const SizedBox(height: 16),
          const HeatAlertSection(),
          const SizedBox(height: 16),
          if (forecast != null && forecast!.hours.isNotEmpty) ...<Widget>[
            Text(
              'Next 6 hours',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _ForecastStrip(hours: forecast!.hours),
          ],
        ],
      ),
    );
  }
}

class _CurrentWeatherCard extends StatelessWidget {
  const _CurrentWeatherCard({required this.weather});

  final Weather? weather;

  @override
  Widget build(BuildContext context) {
    final condition = weather?.condition;
    final temp = weather?.temperatureC;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            if (condition != null && condition.iconBaseUri.isNotEmpty)
              WeatherIcon(iconBaseUri: condition.iconBaseUri, size: 96),
            const SizedBox(height: 12),
            Text(
              temp != null ? '${temp.toStringAsFixed(1)}°C' : '--°C',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              condition?.description.isNotEmpty == true
                  ? condition!.description
                  : 'Current conditions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastStrip extends StatelessWidget {
  const _ForecastStrip({required this.hours});

  final List<ForecastHour> hours;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final hour = hours[index];
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
    final temp = hour.temperatureC;
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            convertHour(hour.hour24),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hour.condition.iconBaseUri.isNotEmpty)
            WeatherIcon(
              iconBaseUri: hour.condition.iconBaseUri,
              dark: true,
              size: 40,
            ),
          Text(
            temp != null ? '${temp.toStringAsFixed(0)}°C' : '--°C',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}