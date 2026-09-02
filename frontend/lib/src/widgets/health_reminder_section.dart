import 'package:flutter/material.dart';

import '../models/weather.dart';

/// A single health reminder derived from the current weather.
class HealthReminder {
  const HealthReminder({
    required this.emoji,
    required this.title,
    required this.message,
  });

  /// Emoji shown as the reminder's icon, e.g. `☔`.
  final String emoji;

  /// Short bold title, e.g. "Take an umbrella".
  final String title;

  /// One-line explanation shown under the title.
  final String message;
}

/// Computes a health reminder from the current [weather].
///
/// Rules are evaluated in priority order — the first matching condition wins:
/// 1. Flood risk: heavy rain (high precipitation probability).
/// 2. Rain: moderate precipitation probability → take an umbrella.
/// 3. High UV index → apply SPF.
/// 4. High heat index → stay cool / hydrate.
/// 5. High humidity → comfort note.
/// 6. Otherwise a neutral "enjoy the weather" reminder.
///
/// Returns a neutral reminder when [weather] is null or lacks the data needed
/// to make a decision.
HealthReminder determineHealthReminder(Weather? weather) {
  final precip = weather?.precipitationPercent;
  final uv = weather?.uvIndex;
  final heatIndex = weather?.heatIndexC;
  final humidity = weather?.relativeHumidity;

  // Flood risk — heavy rain.
  if (precip != null && precip >= 70) {
    return const HealthReminder(
      emoji: '🌊',
      title: 'Flood risk',
      message: 'Heavy rain expected — avoid low-lying areas and flooded roads.',
    );
  }

  // Rain — take an umbrella.
  if (precip != null && precip >= 40) {
    return const HealthReminder(
      emoji: '☔',
      title: 'Take an umbrella',
      message: 'Rain is likely — grab an umbrella before you head out.',
    );
  }

  // High UV index — apply SPF.
  if (uv != null && uv >= 6) {
    return const HealthReminder(
      emoji: '🧴',
      title: 'Apply SPF',
      message: 'UV index is high — wear sunscreen and a hat outdoors.',
    );
  }

  // High heat index — stay cool.
  if (heatIndex != null && heatIndex >= 32) {
    return const HealthReminder(
      emoji: '🥵',
      title: 'Stay cool',
      message: 'Heat index is high — hydrate and limit time in the sun.',
    );
  }

  // High humidity — comfort note.
  if (humidity != null && humidity >= 80) {
    return const HealthReminder(
      emoji: '💧',
      title: 'Humid out there',
      message: 'High humidity — stay hydrated and take it easy outdoors.',
    );
  }

  return const HealthReminder(
    emoji: '🌤️',
    title: 'Enjoy the weather',
    message: 'Conditions look pleasant — a good day to be outside.',
  );
}

/// The "Health reminder" card on the Home page: an emoji plus a short,
/// weather-driven tip (umbrella, SPF, flood, heat, etc.).
class HealthReminderSection extends StatelessWidget {
  const HealthReminderSection({super.key, required this.weather});

  final Weather? weather;

  @override
  Widget build(BuildContext context) {
    final reminder = determineHealthReminder(weather);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Text(
              reminder.emoji,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    reminder.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reminder.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}