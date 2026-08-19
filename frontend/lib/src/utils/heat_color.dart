import 'dart:ui';

/// The heat-index color scale — the single source of truth for map marker
/// colors. Linear RGB interpolation between the stops below, clamped at the
/// ends.
///
/// | Heat Index (°C) | Color |
/// |---|---|
/// | ≤ 20 | Green `rgb(76, 175, 80)` |
/// | 28 | Yellow `rgb(255, 235, 59)` |
/// | 34 | Orange `rgb(255, 167, 38)` |
/// | 40 | Red `rgb(244, 67, 54)` |
/// | 46 | Dark Red `rgb(183, 28, 28)` |
/// | ≥ 55 | Purple `rgb(74, 20, 140)` |
Color getHeatIndexColor(double heatIndex) {
  const stops = <_HeatStop>[
    _HeatStop(20, Color(0xFF4CAF50)), // Green
    _HeatStop(28, Color(0xFFFFEB3B)), // Yellow
    _HeatStop(34, Color(0xFFFFA726)), // Orange
    _HeatStop(40, Color(0xFFF44336)), // Red
    _HeatStop(46, Color(0xFFB71C1C)), // Dark Red
    _HeatStop(55, Color(0xFF4A148C)), // Purple
  ];

  // Clamp below the minimum.
  if (heatIndex <= stops.first.value) {
    return stops.first.color;
  }

  // Clamp above the maximum.
  if (heatIndex >= stops.last.value) {
    return stops.last.color;
  }

  // Find the surrounding interval and interpolate each RGB channel linearly.
  for (var i = 0; i < stops.length - 1; i++) {
    final a = stops[i];
    final b = stops[i + 1];
    if (heatIndex >= a.value && heatIndex <= b.value) {
      final t = (heatIndex - a.value) / (b.value - a.value);
      return Color.lerp(a.color, b.color, t)!;
    }
  }

  return stops.first.color;
}

class _HeatStop {
  const _HeatStop(this.value, this.color);

  final double value;
  final Color color;
}