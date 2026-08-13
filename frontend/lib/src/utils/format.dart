/// Converts a 24-hour integer to a 12-hour AM/PM string.
///
/// Examples: `15` -> `3PM`, `0` -> `12AM`, `12` -> `12PM`.
String convertHour(int hour24) {
  final ampm = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = (hour24 % 12) == 0 ? 12 : (hour24 % 12);
  return '$hour12$ampm';
}
