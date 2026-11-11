import 'package:flutter_test/flutter_test.dart';

import 'package:nowcast/src/models/health_risk_assessment.dart';

/// A complete assessment payload as returned by `POST /api/ai/health-risk`.
Map<String, dynamic> assessmentJson() {
  return <String, dynamic>{
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
      <String, dynamic>{
        'hourIndex': 1,
        'hour': 13,
        'probability': 0.55,
        'coreTempMedianC': 37.9,
        'coreTempP10C': 37.5,
        'coreTempP90C': 38.3,
      },
    ],
  };
}

void main() {
  group('HealthRiskAssessment.fromJson', () {
    test('parses a full payload', () {
      final assessment = HealthRiskAssessment.fromJson(assessmentJson());

      expect(assessment.riskScore, 62);
      expect(assessment.riskLevel, 'very_high');
      expect(assessment.thresholdC, 38.0);
      expect(assessment.thresholdLabel, 'Clinical fever threshold');
      expect(assessment.summary, 'Heat strain is likely this afternoon.');
      expect(
        assessment.uncertainty,
        'Humidity is forecast with moderate confidence.',
      );
      expect(assessment.keyFindings, hasLength(1));
      expect(assessment.recommendations, hasLength(1));
      expect(assessment.hourly, hasLength(2));
      expect(assessment.hourly.first.hour, 12);
      expect(assessment.hourly.last.probability, 0.55);
      expect(assessment.hasChartData, isTrue);
    });

    test('falls back to safe defaults for a sparse payload', () {
      final assessment = HealthRiskAssessment.fromJson(<String, dynamic>{});

      expect(assessment.riskScore, 0);
      expect(assessment.riskLevel, 'low');
      expect(assessment.thresholdC, 38.0);
      expect(assessment.summary, '');
      expect(assessment.keyFindings, isEmpty);
      expect(assessment.hourly, isEmpty);
      expect(assessment.hasChartData, isFalse);
    });

    test('skips hourly entries that are not objects', () {
      final json = assessmentJson();
      json['hourly'] = <dynamic>[
        <String, dynamic>{
          'hourIndex': 0,
          'hour': 12,
          'probability': 0.2,
          'coreTempMedianC': 37.4,
          'coreTempP10C': 37.1,
          'coreTempP90C': 37.8,
        },
        'not an object',
        42,
      ];

      final assessment = HealthRiskAssessment.fromJson(json);

      expect(assessment.hourly, hasLength(1));
    });

    test('parses a generatedAt timestamp', () {
      final json = assessmentJson()
        ..['generatedAt'] = '2026-11-11T09:12:00Z';

      final assessment = HealthRiskAssessment.fromJson(json);

      expect(assessment.generatedAt, DateTime.utc(2026, 11, 11, 9, 12));
    });
  });

  group('HealthRiskAssessment.toJson', () {
    test('round-trips through fromJson', () {
      final original = HealthRiskAssessment.fromJson(assessmentJson());
      final restored = HealthRiskAssessment.fromJson(original.toJson());

      expect(restored.riskScore, original.riskScore);
      expect(restored.riskLevel, original.riskLevel);
      expect(restored.thresholdC, original.thresholdC);
      expect(restored.summary, original.summary);
      expect(restored.hourly, hasLength(original.hourly.length));
      expect(
        restored.hourly.first.coreTempP90C,
        original.hourly.first.coreTempP90C,
      );
    });

    test('includes generatedAt only when set', () {
      final assessment = HealthRiskAssessment.fromJson(assessmentJson());

      expect(assessment.toJson().containsKey('generatedAt'), isFalse);

      final stamped = assessment.withGeneratedAt(DateTime.utc(2026, 11, 11));
      expect(stamped.toJson()['generatedAt'], '2026-11-11T00:00:00.000Z');
    });

    test('withGeneratedAt preserves the assessment data', () {
      final assessment = HealthRiskAssessment.fromJson(assessmentJson());
      final stamped = assessment.withGeneratedAt(DateTime.utc(2026, 11, 11));

      expect(stamped.riskScore, assessment.riskScore);
      expect(stamped.hourly, hasLength(assessment.hourly.length));
      expect(stamped.generatedAt, isNotNull);
    });
  });

  group('HealthRiskHour', () {
    test('round-trips through JSON', () {
      const hour = HealthRiskHour(
        hourIndex: 3,
        hour: 15,
        probability: 0.75,
        coreTempMedianC: 38.1,
        coreTempP10C: 37.7,
        coreTempP90C: 38.6,
      );

      final restored = HealthRiskHour.fromJson(hour.toJson());

      expect(restored.hourIndex, 3);
      expect(restored.hour, 15);
      expect(restored.probability, 0.75);
      expect(restored.coreTempMedianC, 38.1);
      expect(restored.coreTempP10C, 37.7);
      expect(restored.coreTempP90C, 38.6);
    });
  });
}
