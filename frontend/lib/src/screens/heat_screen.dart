import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/forecast_day.dart';
import '../models/forecast_hour.dart';
import '../services/settings_controller.dart';
import '../utils/format.dart';
import '../utils/geolocation.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_overlay.dart';
import 'settings_screen.dart';

/// Heat Data tab: a multi-series line chart of temperature, feels-like, dew
/// point, heat index, wind chill, and wet bulb over the 6-hour forecast, with
/// a toggle to switch between the hourly and daily forecast views.
///
/// Requests device location, then fetches the 6h and daily forecasts and
/// renders a line chart titled "Hourly Temperature Forecast" (or "Daily
/// Temperature Forecast") with crosshair interaction and a bottom legend.
class HeatScreen extends StatefulWidget {
  const HeatScreen({super.key, this.api});

  /// Injectable client for tests. Defaults to a real [ApiClient].
  final ApiClient? api;

  @override
  State<HeatScreen> createState() => _HeatScreenState();
}

class _HeatScreenState extends State<HeatScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  bool _loading = true;
  String _progressLabel = 'Loading geolocation... (1/3)';
  String? _error;

  Forecast? _forecast;
  DailyForecast? _dailyForecast;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _progressLabel = 'Loading geolocation... (1/3)';
    });

    try {
      // 1/3 — device location.
      final position = await getPosition(subject: 'heat data');
      if (!mounted) return;

      setState(() => _progressLabel = 'Loading data... (2/3)');

      // 2/3 + 3/3 — 6h and daily forecasts, fetched in parallel.
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

      final forecast = Forecast.fromJson(
        results[0] is Map<String, dynamic>
            ? results[0] as Map<String, dynamic>
            : <String, dynamic>{},
      );
      final dailyForecast = DailyForecast.fromJson(
        results[1] is Map<String, dynamic>
            ? results[1] as Map<String, dynamic>
            : <String, dynamic>{},
      );

      setState(() {
        _forecast = forecast;
        _dailyForecast = dailyForecast;
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
    final dailyForecast = _dailyForecast;
    final hasHourly = forecast != null && forecast.hours.isNotEmpty;
    final hasDaily = dailyForecast != null && dailyForecast.days.isNotEmpty;
    if (!hasHourly && !hasDaily) {
      return const ErrorView(
        message: 'No forecast data is available for your location right now.',
      );
    }
    return _HeatChart(
      hours: hasHourly ? forecast.hours : const <ForecastHour>[],
      days: hasDaily ? dailyForecast.days : const <ForecastDay>[],
    );
  }
}

/// Which forecast view is shown on the heat chart.
enum _Mode { hourly, daily }

class _HeatChart extends StatefulWidget {
  const _HeatChart({required this.hours, required this.days});

  final List<ForecastHour> hours;
  final List<ForecastDay> days;

  @override
  State<_HeatChart> createState() => _HeatChartState();
}

class _HeatChartState extends State<_HeatChart> {
  _Mode _mode = _Mode.hourly;

  static final List<_Series> _series = <_Series>[
    _Series('Temperature', const Color(0xFFe53935), (h) => h.temperatureC),
    _Series('Feels Like', const Color(0xFFfb8c00), (h) => h.feelsLikeC),
    _Series('Dew Point', const Color(0xFF1e88e5), (h) => h.dewPointC),
    _Series('Heat Index', const Color(0xFF8e24aa), (h) => h.heatIndexC),
    _Series('Wind Chill', const Color(0xFF00897b), (h) => h.windChillC),
    _Series('Wet Bulb', const Color(0xFF3949ab), (h) => h.wetBulbC),
  ];

  static final List<_DaySeries> _daySeries = <_DaySeries>[
    _DaySeries('Max Temp', const Color(0xFFe53935), (d) => d.maxTemperatureC),
    _DaySeries('Min Temp', const Color(0xFF1e88e5), (d) => d.minTemperatureC),
  ];

  @override
  Widget build(BuildContext context) {
    final isHourly = _mode == _Mode.hourly;
    final title = isHourly
        ? 'Hourly Temperature Forecast'
        : 'Daily Temperature Forecast';
    final series = isHourly ? _series : _daySeries;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SegmentedButton<_Mode>(
            segments: const <ButtonSegment<_Mode>>[
              ButtonSegment<_Mode>(
                value: _Mode.hourly,
                label: Text('Hourly'),
                icon: Icon(Icons.schedule),
              ),
              ButtonSegment<_Mode>(
                value: _Mode.daily,
                label: Text('Daily'),
                icon: Icon(Icons.calendar_today),
              ),
            ],
            selected: <_Mode>{_mode},
            onSelectionChanged: (selection) {
              setState(() => _mode = selection.first);
            },
          ),
          const SizedBox(height: 16),
          Text(
            title,
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
          _Legend(series: series),
        ],
      ),
    );
  }

  LineChartData _data() {
    return _mode == _Mode.hourly ? _hourlyData() : _dailyData();
  }

  LineChartData _hourlyData() {
    final hours = widget.hours;
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

  LineChartData _dailyData() {
    final days = widget.days;
    final indexOf = <double, int>{};
    for (var i = 0; i < days.length; i++) {
      indexOf[i.toDouble()] = i;
    }

    return LineChartData(
      lineBarsData: _dayBarData(),
      minX: 0,
      maxX: (days.length - 1).toDouble(),
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
          axisNameWidget: const Text('Day'),
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
                child: Text(_dayLabel(days[index].date)),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) => const Color(0xCC212121),
          getTooltipItems: _dayTooltipItems,
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

  List<LineChartBarData> _dayBarData() {
    return _daySeries.map((series) {
      return LineChartBarData(
        spots: _daySpots(series),
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
    final hours = widget.hours;
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

  List<FlSpot> _daySpots(_DaySeries series) {
    final spots = <FlSpot>[];
    final days = widget.days;
    for (var i = 0; i < days.length; i++) {
      final value = series.getValue(days[i]);
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

  static String _dayLabel(DateTime date) => '${date.month}/${date.day}';

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

  static List<LineTooltipItem> _dayTooltipItems(
    List<LineBarSpot> touchedSpots,
  ) {
    return touchedSpots.map((spot) {
      final label = _daySeries[spot.barIndex].label;
      final color = spot.bar.color ?? Colors.white;
      return LineTooltipItem(
        '$label: ${spot.y.toStringAsFixed(1)} °C',
        TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
      );
    }).toList();
  }
}

/// A single series plotted on the hourly heat chart.
class _Series {
  const _Series(this.label, this.color, this.getValue);

  final String label;
  final Color color;

  /// Extracts this series' temperature value from a forecast hour.
  final double? Function(ForecastHour hour) getValue;
}

/// A single series plotted on the daily heat chart.
class _DaySeries {
  const _DaySeries(this.label, this.color, this.getValue);

  final String label;
  final Color color;

  /// Extracts this series' temperature value from a forecast day.
  final double? Function(ForecastDay day) getValue;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.series});

  final List<Object> series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: series.map((s) {
        final label = s is _Series ? s.label : (s as _DaySeries).label;
        final color = s is _Series ? s.color : (s as _DaySeries).color;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
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
