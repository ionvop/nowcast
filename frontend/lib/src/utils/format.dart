/// Converts a 24-hour integer to a 12-hour AM/PM string.
///
/// Examples: `15` -> `3PM`, `0` -> `12AM`, `12` -> `12PM`.
String convertHour(int hour24) {
  final ampm = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = (hour24 % 12) == 0 ? 12 : (hour24 % 12);
  return '$hour12$ampm';
}

/// Formats a 24-hour integer as a time label, honoring the user's time-format
/// preference.
///
/// When [use24Hour] is `true`, returns 24-hour format (e.g. `15:00`).
/// Otherwise returns 12-hour AM/PM format via [convertHour] (e.g. `3PM`).
String formatHour(int hour24, {required bool use24Hour}) {
  return use24Hour ? '$hour24:00' : convertHour(hour24);
}

/// Formats a [DateTime] as a clock time, honoring the user's time-format
/// preference.
///
/// When [use24Hour] is `true`, returns 24-hour format (e.g. `15:30`).
/// Otherwise returns 12-hour AM/PM format (e.g. `3:30 PM`).
String formatTimestamp(DateTime time, {required bool use24Hour}) {
  final local = time.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  if (use24Hour) {
    final hour = local.hour.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

/// Month abbreviations used by [formatDateTime].
const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a [DateTime] as a date and clock time, e.g. `11 Nov 2026, 09:12`.
///
/// The time portion honors the user's time-format preference via
/// [formatTimestamp].
String formatDateTime(DateTime time, {required bool use24Hour}) {
  final local = time.toLocal();
  final month = _months[local.month - 1];
  final clock = formatTimestamp(local, use24Hour: use24Hour);
  return '${local.day} $month ${local.year}, $clock';
}
