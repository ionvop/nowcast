import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models/ai_summary.dart';

/// The "AI summary" card on the Home page.
///
/// Sends the current-conditions, hourly-forecast, and (optionally) daily
/// forecast payloads that the Home page already fetched to the
/// `POST /api/ai/summary` endpoint, then renders:
///
/// 1. A short paragraph summarizing the analysis.
/// 2. A short paragraph of health advice based on the conditions.
/// 3. A single link to an article recommended by the AI.
///
/// The section manages its own load state so a slow or failing LLM call never
/// blocks the rest of the Home page: while loading it shows a compact
/// placeholder, and on failure a compact inline card with a Retry button.
class AiSummarySection extends StatefulWidget {
  const AiSummarySection({
    super.key,
    required this.currentConditions,
    this.hourlyForecast,
    this.dailyForecast,
    this.api,
  });

  /// The raw Google current-conditions payload (see API §5.1).
  final Map<String, dynamic> currentConditions;

  /// The raw Google hourly forecast payload (see API §5.2). Optional.
  final Map<String, dynamic>? hourlyForecast;

  /// The raw Google daily forecast payload (see API §5.3). Optional.
  final Map<String, dynamic>? dailyForecast;

  /// Injectable client for tests. Defaults to a real [ApiClient].
  final ApiClient? api;

  @override
  State<AiSummarySection> createState() => _AiSummarySectionState();
}

class _AiSummarySectionState extends State<AiSummarySection> {
  late final ApiClient _api = widget.api ?? ApiClient();

  bool _loading = true;
  String? _error;
  AiSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final json = await _api.post(
        'ai/summary',
        <String, dynamic>{
          'currentConditions': widget.currentConditions,
          if (widget.hourlyForecast != null)
            'hourlyForecast': widget.hourlyForecast,
          if (widget.dailyForecast != null) 'dailyForecast': widget.dailyForecast,
        },
      );
      if (!mounted) return;
      final summary = json is Map<String, dynamic>
          ? AiSummary.fromJson(json)
          : const AiSummary(summary: '', healthAdvice: '', articleUrl: '');
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } on NetworkException catch (e) {
      _fail(e.message);
    } on Exception {
      _fail('Something went wrong while generating your summary.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  Future<void> _openArticle(String url) async {
    if (!url.startsWith('http')) return;
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the article.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_loading) {
      child = const _AiSummaryLoading();
    } else if (_error != null) {
      child = _AiSummaryError(message: _error!, onRetry: _load);
    } else {
      child = _AiSummaryContent(
        summary: _summary!,
        onOpenArticle: _openArticle,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _AiSummaryLoading extends StatelessWidget {
  const _AiSummaryLoading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(
          'Analyzing local conditions…',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _AiSummaryError extends StatelessWidget {
  const _AiSummaryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class _AiSummaryContent extends StatelessWidget {
  const _AiSummaryContent({
    required this.summary,
    required this.onOpenArticle,
  });

  final AiSummary summary;
  final ValueChanged<String> onOpenArticle;

  @override
  Widget build(BuildContext context) {
    final hasSummary = summary.summary.isNotEmpty;
    final hasAdvice = summary.healthAdvice.isNotEmpty;
    final hasArticle = summary.articleUrl.isNotEmpty;

    // Nothing usable returned — treat like an unexpected response.
    if (!hasSummary && !hasAdvice && !hasArticle) {
      return Text(
        'The AI summary is unavailable right now.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (hasSummary) ...<Widget>[
          Text(
            summary.summary,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (hasSummary && hasAdvice) const SizedBox(height: 8),
        if (hasAdvice) ...<Widget>[
          Text(
            summary.healthAdvice,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        if ((hasSummary || hasAdvice) && hasArticle) const SizedBox(height: 12),
        if (hasArticle)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => onOpenArticle(summary.articleUrl),
              icon: const Icon(Icons.article_outlined, size: 18),
              label: const Text('Recommended reading'),
            ),
          ),
      ],
    );
  }
}