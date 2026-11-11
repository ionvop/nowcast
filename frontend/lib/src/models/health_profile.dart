/// The biological-sex values accepted by the backend.
const List<String> kHealthSexes = <String>['male', 'female', 'other'];

/// The activity levels accepted by the backend, from least to most active.
const List<String> kActivityLevels = <String>[
  'sedentary',
  'light',
  'moderate',
  'active',
  'very_active',
];

/// The chronic conditions that materially raise heat-strain risk.
const List<String> kHealthConditions = <String>[
  'cardiovascular',
  'diabetes',
  'respiratory',
  'kidney',
  'pregnancy',
  'neurological',
  'obesity',
];

/// The medication classes that impair thermoregulation.
const List<String> kHealthMedications = <String>[
  'diuretics',
  'beta_blockers',
  'anticholinergics',
  'antipsychotics',
  'stimulants',
  'antihistamines',
];

/// The behavioural and environmental modifiers the model can reason about.
const List<String> kHealthLifestyle = <String>[
  'acclimatized',
  'alcohol',
  'dehydrated',
  'outdoor_worker',
  'high_fitness',
  'limited_mobility',
];

/// Human-readable labels for [kHealthSexes].
const Map<String, String> kHealthSexLabels = <String, String>{
  'male': 'Male',
  'female': 'Female',
  'other': 'Other',
};

/// Human-readable labels for [kActivityLevels].
const Map<String, String> kActivityLevelLabels = <String, String>{
  'sedentary': 'Sedentary',
  'light': 'Lightly active',
  'moderate': 'Moderately active',
  'active': 'Active',
  'very_active': 'Very active',
};

/// Human-readable labels for [kHealthConditions].
const Map<String, String> kHealthConditionLabels = <String, String>{
  'cardiovascular': 'Cardiovascular disease',
  'diabetes': 'Diabetes',
  'respiratory': 'Respiratory disease',
  'kidney': 'Kidney disease',
  'pregnancy': 'Pregnancy',
  'neurological': 'Neurological condition',
  'obesity': 'Obesity',
};

/// Human-readable labels for [kHealthMedications].
const Map<String, String> kHealthMedicationLabels = <String, String>{
  'diuretics': 'Diuretics',
  'beta_blockers': 'Beta blockers',
  'anticholinergics': 'Anticholinergics',
  'antipsychotics': 'Antipsychotics',
  'stimulants': 'Stimulants',
  'antihistamines': 'Antihistamines',
};

/// Human-readable labels for [kHealthLifestyle].
const Map<String, String> kHealthLifestyleLabels = <String, String>{
  'acclimatized': 'Acclimatized to heat',
  'alcohol': 'Drinks alcohol regularly',
  'dehydrated': 'Often dehydrated',
  'outdoor_worker': 'Works outdoors',
  'high_fitness': 'High fitness level',
  'limited_mobility': 'Limited mobility',
};

/// A user's personal and health details, as stored by
/// `GET|PUT /api/profile/health`.
///
/// Only [age] and [biologicalSex] are required; every other field is optional
/// so the user can share as much or as little as they are comfortable with.
/// Parsed defensively because the payload is user-authored and may be partial.
class HealthProfile {
  const HealthProfile({
    this.age,
    this.biologicalSex,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.conditions = const <String>[],
    this.medications = const <String>[],
    this.lifestyle = const <String>[],
    this.updatedAt,
  });

  /// The user's age in years.
  final int? age;

  /// One of [kHealthSexes].
  final String? biologicalSex;

  /// Height in centimetres.
  final double? heightCm;

  /// Weight in kilograms.
  final double? weightKg;

  /// One of [kActivityLevels].
  final String? activityLevel;

  /// Selected values from [kHealthConditions].
  final List<String> conditions;

  /// Selected values from [kHealthMedications].
  final List<String> medications;

  /// Selected values from [kHealthLifestyle].
  final List<String> lifestyle;

  /// When the profile was last saved on the server.
  final DateTime? updatedAt;

  /// Whether the profile has the two values the backend requires.
  bool get isComplete => age != null && biologicalSex != null;

  /// Whether the user has entered anything beyond the required fields.
  bool get hasOptionalDetails =>
      heightCm != null ||
      weightKg != null ||
      activityLevel != null ||
      conditions.isNotEmpty ||
      medications.isNotEmpty ||
      lifestyle.isNotEmpty;

  /// The body sent to `PUT /api/profile/health`.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'age': age,
      'biologicalSex': biologicalSex,
      if (heightCm != null) 'heightCm': heightCm,
      if (weightKg != null) 'weightKg': weightKg,
      if (activityLevel != null) 'activityLevel': activityLevel,
      'conditions': conditions,
      'medications': medications,
      'lifestyle': lifestyle,
    };
  }

  factory HealthProfile.fromJson(Map<String, dynamic> json) {
    return HealthProfile(
      age: _int(json['age']),
      biologicalSex: _string(json['biologicalSex']),
      heightCm: _double(json['heightCm']),
      weightKg: _double(json['weightKg']),
      activityLevel: _string(json['activityLevel']),
      conditions: _stringList(json['conditions']),
      medications: _stringList(json['medications']),
      lifestyle: _stringList(json['lifestyle']),
      updatedAt: _dateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  /// Returns a copy with the given fields replaced.
  ///
  /// Nullable fields use a sentinel so they can be explicitly cleared, which
  /// the form needs when the user empties a numeric input.
  HealthProfile copyWith({
    int? age,
    String? biologicalSex,
    Object? heightCm = _unset,
    Object? weightKg = _unset,
    Object? activityLevel = _unset,
    List<String>? conditions,
    List<String>? medications,
    List<String>? lifestyle,
  }) {
    return HealthProfile(
      age: age ?? this.age,
      biologicalSex: biologicalSex ?? this.biologicalSex,
      heightCm: heightCm == _unset ? this.heightCm : heightCm as double?,
      weightKg: weightKg == _unset ? this.weightKg : weightKg as double?,
      activityLevel: activityLevel == _unset
          ? this.activityLevel
          : activityLevel as String?,
      conditions: conditions ?? this.conditions,
      medications: medications ?? this.medications,
      lifestyle: lifestyle ?? this.lifestyle,
      updatedAt: updatedAt,
    );
  }

  static const Object _unset = Object();

  static int? _int(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String? _string(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }

  static DateTime? _dateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000);
    }
    return null;
  }
}
