/// One hour of a [HealthRiskAssessment].
///
/// [probability] is the chance that the user's core body temperature crosses
/// the assessment's threshold during this hour, and the three temperature
/// fields describe the estimated core temperature distribution.
class HealthRiskHour {
  const HealthRiskHour({
    required this.hourIndex,
    required this.hour,
    required this.probability,
    required this.coreTempMedianC,
    required this.coreTempP10C,
    required this.coreTempP90C,
  });

  /// Zero-based index of this hour in the forecast the assessment was built
  /// from. Used as the chart's x value so the axis stays correct across
  /// midnight.
  final int hourIndex;

  /// Hour of day in 24-hour time (0–23).
  final int hour;

  /// Probability (0.0–1.0) that core temperature crosses the threshold.
  final double probability;

  /// Median estimated core temperature in degrees Celsius.
  final double coreTempMedianC;

  /// 10th-percentile (optimistic) core temperature in degrees Celsius.
  final double coreTempP10C;

  /// 90th-percentile (pessimistic) core temperature in degrees Celsius.
  final double coreTempP90C;

  factory HealthRiskHour.fromJson(Map<String, dynamic> json) {
    return HealthRiskHour(
      hourIndex: _int(json['hourIndex']) ?? 0,
      hour: _int(json['hour']) ?? 0,
      probability: _double(json['probability']) ?? 0,
      coreTempMedianC: _double(json['coreTempMedianC']) ?? 0,
      coreTempP10C: _double(json['coreTempP10C']) ?? 0,
      coreTempP90C: _double(json['coreTempP90C']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hourIndex': hourIndex,
      'hour': hour,
      'probability': probability,
      'coreTempMedianC': coreTempMedianC,
      'coreTempP10C': coreTempP10C,
      'coreTempP90C': coreTempP90C,
    };
  }

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
}

/// The parsed response of the `POST /api/ai/health-risk` endpoint.
///
/// The backend combines the user's health profile with the current weather and
/// returns a risk score, the clinical core-temperature threshold it modelled
/// against, an hourly probability curve with an uncertainty band, and a written
/// summary. Fields are parsed defensively because the LLM output may be
/// missing or empty.
class HealthRiskAssessment {
  const HealthRiskAssessment({
    required this.riskScore,
    required this.riskLevel,
    required this.thresholdC,
    required this.thresholdLabel,
    required this.summary,
    required this.uncertainty,
    required this.keyFindings,
    required this.recommendations,
    required this.hourly,
    this.generatedAt,
  });

  /// Overall heat-strain risk from 0 (none) to 100 (emergency).
  final int riskScore;

  /// One of `low`, `moderate`, `high`, `very_high`, `extreme`.
  final String riskLevel;

  /// The core-temperature threshold the model assessed against, in Celsius.
  final double thresholdC;

  /// A short human-readable name for [thresholdC].
  final String thresholdLabel;

  /// Plain-language explanation of the overall risk.
  final String summary;

  /// The largest sources of uncertainty in this estimate.
  final String uncertainty;

  /// Short, actionable findings for decision-makers.
  final List<String> keyFindings;

  /// Short, concrete actions for the user today.
  final List<String> recommendations;

  /// The hourly probability curve and core-temperature band.
  final List<HealthRiskHour> hourly;

  /// When this assessment was generated.
  ///
  /// Set by the client when the response is cached, not by the backend, so it
  /// survives a round-trip through `shared_preferences`.
  final DateTime? generatedAt;

  /// Whether there is enough data to draw the charts.
  bool get hasChartData => hourly.isNotEmpty;

  /// A copy of this assessment stamped with [generatedAt].
  HealthRiskAssessment withGeneratedAt(DateTime time) {
    return HealthRiskAssessment(
      riskScore: riskScore,
      riskLevel: riskLevel,
      thresholdC: thresholdC,
      thresholdLabel: thresholdLabel,
      summary: summary,
      uncertainty: uncertainty,
      keyFindings: keyFindings,
      recommendations: recommendations,
      hourly: hourly,
      generatedAt: time,
    );
  }

  factory HealthRiskAssessment.fromJson(Map<String, dynamic> json) {
    final hourly = json['hourly'];
    return HealthRiskAssessment(
      riskScore: _int(json['riskScore']) ?? 0,
      riskLevel: _string(json['riskLevel'], fallback: 'low'),
      thresholdC: _double(json['thresholdC']) ?? 38.0,
      thresholdLabel: _string(json['thresholdLabel']),
      summary: _string(json['summary']),
      uncertainty: _string(json['uncertainty']),
      keyFindings: _stringList(json['keyFindings']),
      recommendations: _stringList(json['recommendations']),
      hourly: hourly is List
          ? hourly
                .whereType<Map<String, dynamic>>()
                .map(HealthRiskHour.fromJson)
                .toList(growable: false)
          : const <HealthRiskHour>[],
      generatedAt: _dateTime(json['generatedAt'] ?? json['generated_at']),
    );
  }

  /// The JSON sent back to the backend as `previousAssessment`, and stored in
  /// the local cache.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'thresholdC': thresholdC,
      'thresholdLabel': thresholdLabel,
      'summary': summary,
      'uncertainty': uncertainty,
      'keyFindings': keyFindings,
      'recommendations': recommendations,
      'hourly': hourly.map((h) => h.toJson()).toList(growable: false),
      if (generatedAt != null) 'generatedAt': generatedAt!.toIso8601String(),
    };
  }

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

  static String _string(dynamic value, {String fallback = ''}) {
    if (value is String && value.isNotEmpty) return value;
    return fallback;
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
