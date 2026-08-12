import 'dart:ui';

/// Converts a 24-hour hour (0-23) to a 12-hour AM/PM label, e.g. 15 -> "3PM".
String convertHour(int hour24) {
  final normalized = hour24 % 24;
  final period = normalized < 12 ? 'AM' : 'PM';
  var hour12 = normalized % 12;
  if (hour12 == 0) hour12 = 12;
  return '$hour12$period';
}

/// Returns a human-readable relative time string from a Unix timestamp
/// (seconds), e.g. "just now", "5 minutes ago", "2 hours ago".
String timeAgo(int unixTimestamp) {
  final now = DateTime.now();
  final then = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);
  final diff = now.difference(then);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
  if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  final weeks = diff.inDays ~/ 7;
  if (weeks < 5) return '$weeks week${weeks == 1 ? '' : 's'} ago';
  final months = diff.inDays ~/ 30;
  if (months < 12) return '$months month${months == 1 ? '' : 's'} ago';
  final years = diff.inDays ~/ 365;
  return '$years year${years == 1 ? '' : 's'} ago';
}

/// Escapes user-generated HTML content before rendering.
String escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
}

/// Stops of the heat-index color scale.
///
/// Linear interpolation is performed between the surrounding stops. Below the
/// minimum -> green, above the maximum -> purple.
class HeatColorStop {
  const HeatColorStop(this.celsius, this.color);
  final double celsius;
  final Color color;
}

const List<HeatColorStop> _heatStops = [
  HeatColorStop(20, Color(0xFF4CAF50)), // Green
  HeatColorStop(28, Color(0xFFFFEB3B)), // Yellow
  HeatColorStop(34, Color(0xFFFFA726)), // Orange
  HeatColorStop(40, Color(0xFFF44336)), // Red
  HeatColorStop(46, Color(0xFFB71C1C)), // Dark red
  HeatColorStop(55, Color(0xFF4A148C)), // Purple
];

/// Returns the interpolated RGB color for a given heat index (Celsius).
Color getHeatIndexColor(double heatIndex) {
  final stops = _heatStops;

  if (heatIndex <= stops.first.celsius) return stops.first.color;
  if (heatIndex >= stops.last.celsius) return stops.last.color;

  for (var i = 0; i < stops.length - 1; i++) {
    final a = stops[i];
    final b = stops[i + 1];
    if (heatIndex >= a.celsius && heatIndex <= b.celsius) {
      final t = (heatIndex - a.celsius) / (b.celsius - a.celsius);
      return Color.lerp(a.color, b.color, t)!;
    }
  }
  return stops.last.color;
}