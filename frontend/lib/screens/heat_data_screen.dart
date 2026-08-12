import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/location_service.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/alert_dialog.dart';
import '../widgets/loading_overlay.dart';

/// Heat Data tab: six-series hourly temperature forecast line chart.
class HeatDataScreen extends StatefulWidget {
  const HeatDataScreen({super.key});

  @override
  State<HeatDataScreen> createState() => _HeatDataScreenState();
}

class _HeatDataScreenState extends State<HeatDataScreen> {
  final _locationService = const LocationService();

  bool _loading = false;
  String _progressLabel = '';
  CancelToken? _cancelToken;

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
      _progressLabel = 'Loading geolocation... (1/2)';
    });

    final loc = await _locationService.getCurrentLocation();
    if (!mounted || cancel.isCancelled) return;
    if (loc.denied) {
      setState(() => _loading = false);
      await showAppAlert(
        context,
        message: 'Location access is required to show heat data. Please grant '
            'location permission and try again.',
      );
      return;
    }

    try {
      setState(() => _progressLabel = 'Fetching 6h forecast... (2/2)');
      final fcJson = await api.post('/forecast', data: {
        'latitude': loc.lat,
        'longitude': loc.lng,
      }, cancelToken: cancel);
      if (!mounted || cancel.isCancelled) return;
      final map = fcJson is Map
          ? Map<String, dynamic>.from(fcJson)
          : <String, dynamic>{};
      final hours = (map['forecastHours'] as List?)
          ?.whereType<Map>()
          .map((e) => ForecastHour.fromJson(Map<String, dynamic>.from(e)))
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
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF555555)),
            ),
          ),
        ),
      ];
    }
    if (_forecast.isEmpty) {
      return const [
        Center(
          child: Text(
            'No forecast data available.',
            style: TextStyle(color: Color(0xFF555555)),
          ),
        ),
      ];
    }
    return [
      SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildChartCard(),
            const SizedBox(height: 8),
            _buildLegend(),
          ],
        ),
      ),
    ];
  }

  Widget _buildChartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hourly Temperature Forecast',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: LineChart(
                LineChartData(
                  minY: _yMin(),
                  maxY: _yMax(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _yTick(),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: _titles(),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipMargin: 8,
                      getTooltipColor: (_) => Colors.white,
                      getTooltipItems: (spots) => spots
                          .map(
                            (s) => LineTooltipItem(
                              '${_seriesNames[s.barIndex]}: ${s.y.toStringAsFixed(1)} °C',
                              TextStyle(
                                color: _seriesColors[s.barIndex],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: _series(),
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.linear,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _yMin() {
    final values = _allValues();
    if (values.isEmpty) return 0;
    final min = values.reduce((a, b) => a < b ? a : b);
    return (min - 2).floorToDouble();
  }

  double _yMax() {
    final values = _allValues();
    if (values.isEmpty) return 40;
    final max = values.reduce((a, b) => a > b ? a : b);
    return (max + 2).ceilToDouble();
  }

  double _yTick() {
    final range = _yMax() - _yMin();
    if (range <= 0) return 5;
    return (range / 5).ceilToDouble();
  }

  List<double> _allValues() {
    final result = <double>[];
    for (final h in _forecast) {
      for (final v in [
        h.temperature,
        h.feelsLike,
        h.dewPoint,
        h.heatIndex,
        h.windChill,
        h.wetBulb,
      ]) {
        if (v != null) result.add(v);
      }
    }
    return result;
  }

  // Six series in the required order/colors.
  static const List<Color> _seriesColors = [
    Color(0xFFe53935), // Temperature
    Color(0xFFfb8c00), // Feels-like
    Color(0xFF1e88e5), // Dew point
    Color(0xFF8e24aa), // Heat index
    Color(0xFF00897b), // Wind chill
    Color(0xFF3949ab), // Wet-bulb
  ];

  static const List<String> _seriesNames = [
    'Temperature',
    'Feels-like',
    'Dew Point',
    'Heat Index',
    'Wind Chill',
    'Wet-bulb',
  ];

  List<double?> _valueFor(int seriesIndex) {
    return _forecast
        .map<dynamic>((h) => switch (seriesIndex) {
              0 => h.temperature,
              1 => h.feelsLike,
              2 => h.dewPoint,
              3 => h.heatIndex,
              4 => h.windChill,
              5 => h.wetBulb,
              _ => null,
            })
        .map((v) => (v as num?)?.toDouble())
        .toList();
  }

  List<LineChartBarData> _series() {
    final result = <LineChartBarData>[];
    for (var i = 0; i < _seriesColors.length; i++) {
      final values = _valueFor(i);
      final spots = <FlSpot>[];
      for (var x = 0; x < values.length; x++) {
        final v = values[x];
        if (v != null) {
          spots.add(FlSpot(x.toDouble(), v));
        }
      }
      result.add(
        LineChartBarData(
          spots: spots,
          color: _seriesColors[i],
          isCurved: true,
          curveSmoothness: 0.3,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }
    return result;
  }

  FlTitlesData _titles() {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) => Text(
            value.toStringAsFixed(0),
            style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= _forecast.length) return const SizedBox();
            final h = _forecast[idx].displayHour;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${h.toString().padLeft(2, '0')}:00',
                style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
              ),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _buildLegend() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _seriesColors.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _seriesColors[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _seriesNames[i],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF555555),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}