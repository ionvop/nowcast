import 'package:flutter_test/flutter_test.dart';

import 'package:nowcast/src/models/health_profile.dart';

void main() {
  group('HealthProfile.fromJson', () {
    test('parses a full payload', () {
      final profile = HealthProfile.fromJson(<String, dynamic>{
        'age': 68,
        'biologicalSex': 'female',
        'heightCm': 162.5,
        'weightKg': 61,
        'activityLevel': 'light',
        'conditions': <String>['cardiovascular', 'diabetes'],
        'medications': <String>['beta_blockers'],
        'lifestyle': <String>['acclimatized'],
        'updatedAt': '2026-11-11T09:12:00Z',
      });

      expect(profile.age, 68);
      expect(profile.biologicalSex, 'female');
      expect(profile.heightCm, 162.5);
      expect(profile.weightKg, 61.0);
      expect(profile.activityLevel, 'light');
      expect(profile.conditions, <String>['cardiovascular', 'diabetes']);
      expect(profile.medications, <String>['beta_blockers']);
      expect(profile.lifestyle, <String>['acclimatized']);
      expect(profile.updatedAt, DateTime.utc(2026, 11, 11, 9, 12));
    });

    test('tolerates a minimal payload', () {
      final profile = HealthProfile.fromJson(<String, dynamic>{
        'age': 30,
        'biologicalSex': 'male',
      });

      expect(profile.age, 30);
      expect(profile.heightCm, isNull);
      expect(profile.weightKg, isNull);
      expect(profile.activityLevel, isNull);
      expect(profile.conditions, isEmpty);
      expect(profile.medications, isEmpty);
      expect(profile.lifestyle, isEmpty);
      expect(profile.updatedAt, isNull);
    });

    test('ignores malformed values instead of throwing', () {
      final profile = HealthProfile.fromJson(<String, dynamic>{
        'age': 'not a number',
        'biologicalSex': 42,
        'heightCm': <String, dynamic>{},
        'conditions': 'cardiovascular',
        'medications': <dynamic>[1, 'diuretics', null],
      });

      expect(profile.age, isNull);
      expect(profile.biologicalSex, isNull);
      expect(profile.heightCm, isNull);
      expect(profile.conditions, isEmpty);
      expect(profile.medications, <String>['diuretics']);
    });

    test('accepts numeric strings', () {
      final profile = HealthProfile.fromJson(<String, dynamic>{
        'age': '45',
        'heightCm': '175.5',
        'weightKg': '80',
      });

      expect(profile.age, 45);
      expect(profile.heightCm, 175.5);
      expect(profile.weightKg, 80.0);
    });
  });

  group('HealthProfile.toJson', () {
    test('omits unset optional fields', () {
      const profile = HealthProfile(age: 30, biologicalSex: 'male');

      expect(profile.toJson(), <String, dynamic>{
        'age': 30,
        'biologicalSex': 'male',
        'conditions': <String>[],
        'medications': <String>[],
        'lifestyle': <String>[],
      });
    });

    test('includes set optional fields', () {
      const profile = HealthProfile(
        age: 30,
        biologicalSex: 'male',
        heightCm: 180,
        weightKg: 75,
        activityLevel: 'active',
        conditions: <String>['diabetes'],
      );

      final json = profile.toJson();

      expect(json['heightCm'], 180.0);
      expect(json['weightKg'], 75.0);
      expect(json['activityLevel'], 'active');
      expect(json['conditions'], <String>['diabetes']);
    });

    test('round-trips through fromJson', () {
      const original = HealthProfile(
        age: 55,
        biologicalSex: 'other',
        heightCm: 170,
        weightKg: 68.5,
        activityLevel: 'moderate',
        conditions: <String>['kidney'],
        medications: <String>['diuretics'],
        lifestyle: <String>['outdoor_worker'],
      );

      final restored = HealthProfile.fromJson(original.toJson());

      expect(restored.age, original.age);
      expect(restored.biologicalSex, original.biologicalSex);
      expect(restored.heightCm, original.heightCm);
      expect(restored.weightKg, original.weightKg);
      expect(restored.activityLevel, original.activityLevel);
      expect(restored.conditions, original.conditions);
      expect(restored.medications, original.medications);
      expect(restored.lifestyle, original.lifestyle);
    });
  });

  group('HealthProfile helpers', () {
    test('isComplete requires age and biological sex', () {
      expect(
        const HealthProfile(age: 30, biologicalSex: 'male').isComplete,
        isTrue,
      );
      expect(const HealthProfile(age: 30).isComplete, isFalse);
      expect(
        const HealthProfile(biologicalSex: 'male').isComplete,
        isFalse,
      );
    });

    test('hasOptionalDetails reflects the non-required fields', () {
      expect(
        const HealthProfile(age: 30, biologicalSex: 'male').hasOptionalDetails,
        isFalse,
      );
      expect(
        const HealthProfile(
          age: 30,
          biologicalSex: 'male',
          conditions: <String>['diabetes'],
        ).hasOptionalDetails,
        isTrue,
      );
    });

    test('copyWith can clear a nullable field', () {
      const profile = HealthProfile(
        age: 30,
        biologicalSex: 'male',
        heightCm: 180,
      );

      expect(profile.copyWith(heightCm: null).heightCm, isNull);
      // Omitting the argument keeps the existing value.
      expect(profile.copyWith(age: 31).heightCm, 180);
    });
  });
}
