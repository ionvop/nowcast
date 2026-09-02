import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/forecast_hour.dart';
import '../services/settings_controller.dart';
import '../utils/format.dart';
import '../utils/geolocation.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_overlay.dart';
import 'settings_screen.dart';

/// Heat Data tab: a multi-series line chart of temperature, feels-like, dew
/// point, heat index, wind chill, and wet bulb over the 6-hour forecast.
///
/// Requests device location, then fetches the 6h forecast and renders a line
/// chart titled "Hourly Temperature Forecast" with crosshair interaction and
/// a bottom legend.
class HeatScreen extends StatefulWidget {
  const HeatScreen({super.key});

  @override
  State<HeatScreen> createState() => _HeatScreenState();
}

class _HeatScreenState extends State<HeatScreen> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  String _progressLabel = 'Loading geolocation... (1/2)';
  String? _error;

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
      _progressLabel = 'Loading geolocation... (1/2)';
    });

    try {
      // 1/2 — device location.
      final position = await getPosition(subject: 'heat data');
      if (!mounted) return;

      setState(() => _progressLabel = 'Loading data... (2/2)');

      // 2/2 — 6h forecast.
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
        _forecast = forecast;
        _loading = false;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } on NetworkException catch (e) {
      _fail(e.message);
    } on Exception {
      _fail('Something went wrong while loading the heat data.');
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
        title: const Text('Heat Data'),
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
    final forecast = _forecast;
    if (forecast == null || forecast.hours.isEmpty) {
      return const ErrorView(
        message: 'No forecast data is available for your location right now.',
      );
    }
    return _HeatChart(hours: forecast.hours);
  }
}

/// A single series plotted on the heat chart.
class _Series {
  const _Series(this.label, this.color, this.getValue);

  final String label;
  final Color color;

  /// Extracts this series' temperature value from a forecast hour.
  final double? Function(ForecastHour hour) getValue;
}

class _HeatChart extends StatelessWidget {
  const _HeatChart({required this.hours});

  final List<ForecastHour> hours;

  static final List<_Series> _series = <_Series>[
    _Series('Temperature', const Color(0xFFe53935), (h) => h.temperatureC),
    _Series('Feels Like', const Color(0xFFfb8c00), (h) => h.feelsLikeC),
    _Series('Dew Point', const Color(0xFF1e88e5), (h) => h.dewPointC),
    _Series('Heat Index', const Color(0xFF8e24aa), (h) => h.heatIndexC),
    _Series('Wind Chill', const Color(0xFF00897b), (h) => h.windChillC),
    _Series('Wet Bulb', const Color(0xFF3949ab), (h) => h.wetBulbC),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Hourly Temperature Forecast',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 24, 20, 24),
              child: SizedBox(height: 340, child: LineChart(_data())),
            ),
          ),
          const SizedBox(height: 12),
          _Legend(series: _series),
        ],
      ),
    );
  }

  LineChartData _data() {
    final indexOf = <double, int>{};
    for (var i = 0; i < hours.length; i++) {
      indexOf[i.toDouble()] = i;
    }

    return LineChartData(
      lineBarsData: _barData(),
      minX: 0,
      maxX: (hours.length - 1).toDouble(),
      gridData: FlGridData(
        drawVerticalLine: true,
        getDrawingVerticalLine: (value) =>
            const FlLine(color: Color(0x11000000), strokeWidth: 1),
        getDrawingHorizontalLine: (value) =>
            const FlLine(color: Color(0x22000000), strokeWidth: 1),
      ),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          left: BorderSide(color: Color(0x44000000)),
          bottom: BorderSide(color: Color(0x44000000)),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: const Text('Temperature (°C)'),
          axisNameSize: 28,
          sideTitles: const SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: 1,
            getTitlesWidget: _yTitle,
          ),
        ),
        bottomTitles: AxisTitles(
          axisNameWidget: const Text('Hour'),
          axisNameSize: 28,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = indexOf[value];
              if (index == null) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                child: ListenableBuilder(
                  listenable: settingsController,
                  builder: (context, _) => Text(
                    formatHour(
                      hours[index].hour24,
                      use24Hour: settingsController.is24Hour,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) => const Color(0xCC212121),
          getTooltipItems: _tooltipItems,
          fitInsideVertically: true,
        ),
        getTouchedSpotIndicator: (barData, spotIndexes) {
          return spotIndexes.map((index) {
            final color = barData.color ?? const Color(0xFF3949ab);
            return TouchedSpotIndicatorData(
              FlLine(color: color, strokeWidth: 1.5),
              FlDotData(
                getDotPainter: (spot, percent, bar, dotIndex) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: bar.color ?? const Color(0xFF3949ab),
                      strokeColor: Colors.white,
                      strokeWidth: 2,
                    ),
              ),
            );
          }).toList();
        },
        distanceCalculator: (touchPoint, spotPixelCoordinates) {
          return (touchPoint.dx - spotPixelCoordinates.dx).abs();
        },
      ),
    );
  }

  List<LineChartBarData> _barData() {
    return _series.map((series) {
      return LineChartBarData(
        spots: _spots(series),
        color: series.color,
        barWidth: 2,
        isCurved: true,
        curveSmoothness: 0.3,
        isStrokeCapRound: true,
        isStrokeJoinRound: true,
        dotData: const FlDotData(show: true),
      );
    }).toList();
  }

  List<FlSpot> _spots(_Series series) {
    final spots = <FlSpot>[];
    for (var i = 0; i < hours.length; i++) {
      final value = series.getValue(hours[i]);
      if (value == null) {
        spots.add(FlSpot.nullSpot);
      } else {
        spots.add(FlSpot(i.toDouble(), value));
      }
    }
    return spots;
  }

  static Widget _yTitle(double value, TitleMeta meta) {
    return SideTitleWidget(meta: meta, child: Text('${value.round()}°'));
  }

  static List<LineTooltipItem> _tooltipItems(List<LineBarSpot> touchedSpots) {
    return touchedSpots.map((spot) {
      final label = _series[spot.barIndex].label;
      final color = spot.bar.color ?? Colors.white;
      return LineTooltipItem(
        '$label: ${spot.y.toStringAsFixed(1)} °C',
        TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
      );
    }).toList();
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.series});

  final List<_Series> series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: series.map((s) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: s.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              s.label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
