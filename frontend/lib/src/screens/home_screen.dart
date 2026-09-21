import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models/forecast_hour.dart';
import '../models/weather.dart';
import '../services/settings_controller.dart';
import '../utils/format.dart';
import '../utils/geocode.dart';
import '../utils/geolocation.dart';
import '../widgets/ai_summary_section.dart';
import '../widgets/error_view.dart';
import '../widgets/health_reminder_section.dart';
import '../widgets/heat_alert_section.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/weather_icon.dart';
import 'settings_screen.dart';

/// Home tab: current weather condition, icon, temperature, an hourly
/// forecast strip, and an AI-generated summary of the local conditions.
///
/// Requests device location, then sequentially fetches current weather,
/// reverse-geocoded city, the 6h forecast, and the daily forecast — updating
/// the progress label each step.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  String _progressLabel = 'Loading geolocation... (1/5)';
  String? _error;

  Weather? _weather;
  String? _city;
  Forecast? _forecast;

  /// The raw current-conditions and forecast payloads, kept alongside the
  /// typed models so the AI summary can forward the full JSON to the backend
  /// without dropping fields the typed models do not parse.
  Map<String, dynamic>? _weatherJson;
  Map<String, dynamic>? _forecastJson;
  Map<String, dynamic>? _dailyJson;

  /// Incremented on every load/refresh so failed weather icons are retried.
  int _refreshCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _refreshCount++;
    setState(() {
      _loading = true;
      _error = null;
      _progressLabel = 'Loading geolocation... (1/4)';
    });

    try {
      // 1/5 — device location.
      final position = await getPosition(subject: 'weather');
      if (!mounted) return;

      setState(() => _progressLabel = 'Loading current weather... (2/5)');

      // 2/5 — current weather.
      final weatherJson = await _api.post('weather', {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
      if (!mounted) return;
      final weatherMap = weatherJson is Map<String, dynamic>
          ? weatherJson
          : const <String, dynamic>{};
      final weather = Weather.fromJson(weatherMap);

      setState(() => _progressLabel = 'Loading your city... (3/5)');

      // 3/5 — reverse geocode.
      final geocodeJson = await _api.post('geocode', {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
      if (!mounted) return;
      final city = addressFromGeocode(geocodeJson);

      setState(() => _progressLabel = 'Loading forecast... (4/5)');

      // 4/5 + 5/5 — 6h and daily forecasts, fetched in parallel.
      final results = await Future.wait<dynamic>([
        _api.post('forecast', {
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
        _api.post('forecast/daily', {
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      ]);
      if (!mounted) return;

      final forecastMap = results[0] is Map<String, dynamic>
          ? results[0] as Map<String, dynamic>
          : const <String, dynamic>{};
      final dailyMap = results[1] is Map<String, dynamic>
          ? results[1] as Map<String, dynamic>
          : const <String, dynamic>{};
      final forecast = Forecast.fromJson(forecastMap);

      setState(() {
        _weather = weather;
        _weatherJson = weatherMap;
        _forecastJson = forecastMap;
        _dailyJson = dailyMap;
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
      weatherJson: _weatherJson,
      forecastJson: _forecastJson,
      dailyJson: _dailyJson,
      retryToken: _refreshCount,
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.weather,
    required this.city,
    required this.forecast,
    required this.weatherJson,
    required this.forecastJson,
    required this.dailyJson,
    required this.retryToken,
  });

  final Weather? weather;
  final String? city;
  final Forecast? forecast;

  /// The raw weather payloads forwarded to the AI summary section.
  final Map<String, dynamic>? weatherJson;
  final Map<String, dynamic>? forecastJson;
  final Map<String, dynamic>? dailyJson;

  final int retryToken;

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
          _CurrentWeatherCard(weather: weather, retryToken: retryToken),
          if (weatherJson != null) ...<Widget>[
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: settingsController,
              builder: (context, _) => settingsController.isAiSummaryEnabled
                  ? AiSummarySection(
                      currentConditions: weatherJson!,
                      hourlyForecast: forecastJson,
                      dailyForecast: dailyJson,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
          const SizedBox(height: 16),
          HealthReminderSection(weather: weather),
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
            _ForecastStrip(hours: forecast!.hours, retryToken: retryToken),
          ],
          const SizedBox(height: 24),
          const _EmergencyButton(),
        ],
      ),
    );
  }
}

class _CurrentWeatherCard extends StatelessWidget {
  const _CurrentWeatherCard({required this.weather, required this.retryToken});

  final Weather? weather;
  final int retryToken;

  @override
  Widget build(BuildContext context) {
    final condition = weather?.condition;
    final temp = weather?.temperatureC;
    final heatIndex = weather?.heatIndexC;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            if (condition != null && condition.iconBaseUri.isNotEmpty)
              WeatherIcon(
                iconBaseUri: condition.iconBaseUri,
                size: 96,
                retryToken: retryToken,
              ),
            const SizedBox(height: 12),
            Column(
              children: <Widget>[
                Text(
                  temp != null ? '${temp.toStringAsFixed(1)}°C' : '--°C',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                if (heatIndex != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Heat ${heatIndex.toStringAsFixed(1)}°',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
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
  const _ForecastStrip({required this.hours, required this.retryToken});

  final List<ForecastHour> hours;
  final int retryToken;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final hour = hours[index];
          return _ForecastCard(hour: hour, retryToken: retryToken);
        },
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.hour, required this.retryToken});

  final ForecastHour hour;
  final int retryToken;

  @override
  Widget build(BuildContext context) {
    final temp = hour.temperatureC;
    final heatIndex = hour.heatIndexC;
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
          ListenableBuilder(
            listenable: settingsController,
            builder: (context, _) => Text(
              formatHour(
                hour.hour24,
                use24Hour: settingsController.is24Hour,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hour.condition.iconBaseUri.isNotEmpty)
            WeatherIcon(
              iconBaseUri: hour.condition.iconBaseUri,
              dark: true,
              size: 40,
              retryToken: retryToken,
            ),
          Column(
            children: <Widget>[
              Text(
                temp != null ? '${temp.toStringAsFixed(0)}°C' : '--°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (heatIndex != null)
                Text(
                  'Heat ${heatIndex.toStringAsFixed(0)}°',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A prominent card at the bottom of the home page that opens the device
/// dialer pre-filled with the configured emergency number.
///
/// Uses a `tel:` URI with [LaunchMode.externalApplication], so the dialer app
/// opens at the call-confirmation screen and **no call is placed** unless the
/// user explicitly confirms it.
class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton();

  Future<void> _openDialer(BuildContext context) async {
    final number = settingsController.emergencyNumber;
    final uri = Uri(scheme: 'tel', path: number);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open dialer.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDialer(context),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListenableBuilder(
            listenable: settingsController,
            builder: (context, _) => Row(
              children: <Widget>[
                Icon(
                  Icons.emergency,
                  color: scheme.onErrorContainer,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Emergency',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: scheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Open dialer with ${settingsController.emergencyNumber}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onErrorContainer,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onErrorContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}