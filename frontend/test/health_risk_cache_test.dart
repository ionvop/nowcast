import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nowcast/src/models/health_risk_assessment.dart';
import 'package:nowcast/src/services/health_risk_cache.dart';

HealthRiskAssessment buildAssessment() {
  return HealthRiskAssessment.fromJson(<String, dynamic>{
    'riskScore': 62,
    'riskLevel': 'very_high',
    'thresholdC': 38.0,
    'thresholdLabel': 'Clinical fever threshold',
    'summary': 'Heat strain is likely this afternoon.',
    'uncertainty': 'Humidity is forecast with moderate confidence.',
    'keyFindings': <String>['Peak risk is between 14:00 and 16:00.'],
    'recommendations': <String>['Avoid strenuous outdoor work at midday.'],
    'hourly': <Map<String, dynamic>>[
      <String, dynamic>{
        'hourIndex': 0,
        'hour': 12,
        'probability': 0.25,
        'coreTempMedianC': 37.4,
        'coreTempP10C': 37.1,
        'coreTempP90C': 37.8,
      },
    ],
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('read returns null when nothing is cached', () async {
    final cache = HealthRiskCache();

    expect(await cache.read(), isNull);
  });

  test('write stamps the assessment with the current time', () async {
    final now = DateTime.utc(2026, 11, 11, 9, 12);
    final cache = HealthRiskCache(now: () => now);

    final stamped = await cache.write(buildAssessment());

    expect(stamped.generatedAt, now);
  });

  test('write then read restores the assessment and its date', () async {
    final now = DateTime.utc(2026, 11, 11, 9, 12);
    final cache = HealthRiskCache(now: () => now);

    await cache.write(buildAssessment());
    final restored = await cache.read();

    expect(restored, isNotNull);
    expect(restored!.riskScore, 62);
    expect(restored.riskLevel, 'very_high');
    expect(restored.thresholdC, 38.0);
    expect(restored.summary, 'Heat strain is likely this afternoon.');
    expect(restored.hourly, hasLength(1));
    expect(restored.generatedAt, now);
  });

  test('clear removes the cached assessment', () async {
    final cache = HealthRiskCache();

    await cache.write(buildAssessment());
    expect(await cache.read(), isNotNull);

    await cache.clear();

    expect(await cache.read(), isNull);
  });

  test('read returns null for corrupt JSON instead of throwing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kHealthRiskCacheKey: 'not json at all',
    });
    final cache = HealthRiskCache();

    expect(await cache.read(), isNull);
  });

  test('read returns null when the stored value is not an object', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kHealthRiskCacheKey: '[1, 2, 3]',
    });
    final cache = HealthRiskCache();

    expect(await cache.read(), isNull);
  });
}
