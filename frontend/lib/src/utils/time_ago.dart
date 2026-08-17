/// Formats a [DateTime] as a short relative time string, e.g. "just now",
/// "5 minutes ago", "2 hours ago", "3 days ago".
///
/// Ported from the legacy web app's `timeAgo` helper. Times in the future
/// (e.g. due to clock skew) are reported as "in the future".
String timeAgo(DateTime time) {
  final now = DateTime.now();
  final secondsAgo = now.difference(time).inSeconds;

  if (secondsAgo < 0) return 'in the future';
  if (secondsAgo < 10) return 'just now';

  const intervals = <(int, String)>[
    (31536000, 'year'),
    (2592000, 'month'),
    (604800, 'week'),
    (86400, 'day'),
    (3600, 'hour'),
    (60, 'minute'),
    (1, 'second'),
  ];

  for (final (secondsInUnit, unit) in intervals) {
    final count = secondsAgo ~/ secondsInUnit;
    if (count >= 1) {
      final plural = count == 1 ? '' : 's';
      return '$count $unit$plural ago';
    }
  }

  return 'just now';
}
