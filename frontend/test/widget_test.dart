import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/utils/format.dart';

void main() {
  test('convertHour converts 24h to 12h AM/PM', () {
    expect(convertHour(15), '3PM');
    expect(convertHour(0), '12AM');
    expect(convertHour(12), '12PM');
    expect(convertHour(9), '9AM');
    expect(convertHour(23), '11PM');
  });

  test('timeAgo returns relative strings', () {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    expect(timeAgo(now), 'just now');
    expect(timeAgo(now - 5 * 60), '5 minutes ago');
    expect(timeAgo(now - 2 * 3600), '2 hours ago');
  });

  test('getHeatIndexColor clamps and interpolates', () {
    // Clamp below min -> green
    expect(getHeatIndexColor(10), const Color(0xFF4CAF50));
    // Clamp above max -> purple
    expect(getHeatIndexColor(99), const Color(0xFF4A148C));
    // Exact stop -> that color
    expect(getHeatIndexColor(28), const Color(0xFFFFEB3B));
  });
}
