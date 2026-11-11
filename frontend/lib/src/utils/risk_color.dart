import 'dart:ui';

/// The color used for a health-risk level.
///
/// Reuses the heat-index palette from `heat_color.dart` so the risk chip reads
/// on the same visual scale as the rest of the app: green for low risk through
/// to purple for extreme risk.
Color getRiskLevelColor(String level) {
  switch (level) {
    case 'moderate':
      return const Color(0xFFFFEB3B); // Yellow
    case 'high':
      return const Color(0xFFFFA726); // Orange
    case 'very_high':
      return const Color(0xFFF44336); // Red
    case 'extreme':
      return const Color(0xFF4A148C); // Purple
    case 'low':
    default:
      return const Color(0xFF4CAF50); // Green
  }
}

/// A human-readable label for a health-risk level.
String riskLevelLabel(String level) {
  switch (level) {
    case 'moderate':
      return 'Moderate';
    case 'high':
      return 'High';
    case 'very_high':
      return 'Very high';
    case 'extreme':
      return 'Extreme';
    case 'low':
    default:
      return 'Low';
  }
}

/// A color that stays legible on top of [getRiskLevelColor].
///
/// The yellow and orange bands are light enough that white text disappears, so
/// they get dark text instead.
Color riskLevelForeground(String level) {
  switch (level) {
    case 'moderate':
    case 'high':
      return const Color(0xFF1A1A1A);
    default:
      return const Color(0xFFFFFFFF);
  }
}
