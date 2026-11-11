import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/health_risk_assessment.dart';
import '../utils/format.dart';

/// The color of the probability curve.
const Color kProbabilityColor = Color(0xFFe53935);

/// The color of the median core-temperature line.
const Color kCoreTempColor = Color(0xFF8e24aa);

/// The color of the uncertainty band around the median.
const Color kCoreTempBandColor = Color(0x338e24aa);

/// The color of the clinical threshold line.
const Color kThresholdColor = Color(0xFFd32f2f);

/// Builds the hourly probability-of-crossing chart.
///
/// The y axis runs 0–100 % and the x axis is the forecast hour index, labelled
/// with the hour of day so the axis stays correct across midnight.
LineChartData probabilityChartData(
  HealthRiskAssessment assessment, {
  required bool use24Hour,
}) {
  final hours = assessment.hourly;
  final spots = hours
      .map(
        (h) => FlSpot(h.hourIndex.toDouble(), h.probability * 100),
      )
      .toList(growable: false);

  return LineChartData(
    minX: 0,
    maxX: _maxX(hours),
    minY: 0,
    maxY: 100,
    lineBarsData: <LineChartBarData>[
      LineChartBarData(
        spots: spots,
        color: kProbabilityColor,
        barWidth: 2.5,
        isCurved: true,
        curveSmoothness: 0.25,
        isStrokeCapRound: true,
        isStrokeJoinRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          color: kProbabilityColor.withValues(alpha: 0.12),
        ),
      ),
    ],
    gridData: _gridData(),
    borderData: _borderData(),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        axisNameWidget: const Text('Chance'),
        axisNameSize: 24,
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: 25,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            child: Text(
              '${value.toInt()}%',
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        axisNameWidget: const Text('Hour'),
        axisNameSize: 24,
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: 1,
          getTitlesWidget: (value, meta) => _hourTitle(
            value,
            meta,
            hours,
            use24Hour: use24Hour,
          ),
        ),
      ),
    ),
    lineTouchData: LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => const Color(0xCC212121),
        getTooltipItems: (touched) => touched.map((spot) {
          final hour = _hourAt(hours, spot.x);
          final label = hour == null
              ? ''
              : '${formatHour(hour.hour, use24Hour: use24Hour)} · ';
          return LineTooltipItem(
            '$label${spot.y.toStringAsFixed(0)}% chance',
            const TextStyle(color: Colors.white, fontSize: 12),
          );
        }).toList(growable: false),
      ),
    ),
  );
}

/// Builds the core-temperature chart: a median line with a p10–p90 band and a
/// dashed clinical-threshold line.
LineChartData coreTempChartData(
  HealthRiskAssessment assessment, {
  required bool use24Hour,
}) {
  final hours = assessment.hourly;
  final p10 = <FlSpot>[];
  final median = <FlSpot>[];
  final p90 = <FlSpot>[];

  for (final hour in hours) {
    final x = hour.hourIndex.toDouble();
    p10.add(FlSpot(x, hour.coreTempP10C));
    median.add(FlSpot(x, hour.coreTempMedianC));
    p90.add(FlSpot(x, hour.coreTempP90C));
  }

  // Pad the y range so the band and the threshold line are never clipped.
  final values = <double>[
    ...p10.map((s) => s.y),
    ...p90.map((s) => s.y),
    assessment.thresholdC,
  ];
  final minY = values.reduce((a, b) => a < b ? a : b) - 0.4;
  final maxY = values.reduce((a, b) => a > b ? a : b) + 0.4;

  return LineChartData(
    minX: 0,
    maxX: _maxX(hours),
    minY: minY,
    maxY: maxY,
    // The band is drawn between the p10 and p90 bars, so it needs no masking.
    betweenBarsData: <BetweenBarsData>[
      BetweenBarsData(fromIndex: 0, toIndex: 2, color: kCoreTempBandColor),
    ],
    lineBarsData: <LineChartBarData>[
      LineChartBarData(
        spots: p10,
        color: Colors.transparent,
        barWidth: 0,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots: median,
        color: kCoreTempColor,
        barWidth: 2.5,
        isCurved: true,
        curveSmoothness: 0.25,
        isStrokeCapRound: true,
        isStrokeJoinRound: true,
        dotData: const FlDotData(show: true),
      ),
      LineChartBarData(
        spots: p90,
        color: Colors.transparent,
        barWidth: 0,
        dotData: const FlDotData(show: false),
      ),
    ],
    extraLinesData: ExtraLinesData(
      horizontalLines: <HorizontalLine>[
        HorizontalLine(
          y: assessment.thresholdC,
          color: kThresholdColor,
          strokeWidth: 1.5,
          dashArray: <int>[6, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: const TextStyle(
              color: kThresholdColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            labelResolver: (_) =>
                '${assessment.thresholdC.toStringAsFixed(1)}°C',
          ),
        ),
      ],
    ),
    gridData: _gridData(),
    borderData: _borderData(),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        axisNameWidget: const Text('Core °C'),
        axisNameSize: 24,
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            child: Text(
              value.toStringAsFixed(1),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        axisNameWidget: const Text('Hour'),
        axisNameSize: 24,
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: 1,
          getTitlesWidget: (value, meta) => _hourTitle(
            value,
            meta,
            hours,
            use24Hour: use24Hour,
          ),
        ),
      ),
    ),
    lineTouchData: LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => const Color(0xCC212121),
        getTooltipItems: (touched) => touched.map((spot) {
          // Only the median bar carries a meaningful tooltip.
          if (spot.barIndex != 1) return null;
          final hour = _hourAt(hours, spot.x);
          if (hour == null) return null;
          return LineTooltipItem(
            '${formatHour(hour.hour, use24Hour: use24Hour)}\n'
            '${hour.coreTempMedianC.toStringAsFixed(1)}°C '
            '(${hour.coreTempP10C.toStringAsFixed(1)}–'
            '${hour.coreTempP90C.toStringAsFixed(1)})',
            const TextStyle(color: Colors.white, fontSize: 12),
          );
        }).toList(growable: false),
      ),
    ),
  );
}

/// The largest x value, kept at least 1 so a single-point chart still renders.
double _maxX(List<HealthRiskHour> hours) {
  if (hours.isEmpty) return 1;
  final maxIndex = hours
      .map((h) => h.hourIndex)
      .reduce((a, b) => a > b ? a : b)
      .toDouble();
  return maxIndex < 1 ? 1 : maxIndex;
}

/// Finds the hour whose index matches [x], if any.
HealthRiskHour? _hourAt(List<HealthRiskHour> hours, double x) {
  for (final hour in hours) {
    if (hour.hourIndex == x.round()) return hour;
  }
  return null;
}

/// Renders an hour-of-day label for the x axis.
Widget _hourTitle(
  double value,
  TitleMeta meta,
  List<HealthRiskHour> hours, {
  required bool use24Hour,
}) {
  final hour = _hourAt(hours, value);
  if (hour == null) return const SizedBox.shrink();
  return SideTitleWidget(
    meta: meta,
    child: Text(
      formatHour(hour.hour, use24Hour: use24Hour),
      style: const TextStyle(fontSize: 10),
    ),
  );
}

FlGridData _gridData() {
  return FlGridData(
    drawVerticalLine: false,
    getDrawingHorizontalLine: (_) =>
        const FlLine(color: Color(0x22000000), strokeWidth: 1),
  );
}

FlBorderData _borderData() {
  return FlBorderData(
    show: true,
    border: const Border(
      left: BorderSide(color: Color(0x44000000)),
      bottom: BorderSide(color: Color(0x44000000)),
    ),
  );
}
