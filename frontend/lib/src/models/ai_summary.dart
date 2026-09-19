/// The parsed response of the `POST /api/ai/summary` endpoint.
///
/// The backend analyzes the provided current-conditions and forecast payloads
/// through an LLM and returns a short summary paragraph, a paragraph of health
/// advice, and a single link to a recommended article. Fields are parsed
/// defensively because the LLM output may be missing or empty.
class AiSummary {
  const AiSummary({
    required this.summary,
    required this.healthAdvice,
    required this.articleUrl,
  });

  /// Short AI analysis of the current conditions and forecast payloads.
  final String summary;

  /// Short paragraph of health advice based on the conditions.
  final String healthAdvice;

  /// Single link to an article recommended by the AI for the user to read.
  final String articleUrl;

  factory AiSummary.fromJson(Map<String, dynamic> json) {
    return AiSummary(
      summary: _string(json['summary']),
      healthAdvice: _string(json['healthAdvice']),
      articleUrl: _string(json['articleUrl']),
    );
  }

  /// Reads a non-null String field, defaulting to '' when absent or empty.
  static String _string(dynamic value) {
    if (value is String) return value;
    return '';
  }
}