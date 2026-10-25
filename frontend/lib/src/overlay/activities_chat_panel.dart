import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/geocode.dart';
import '../utils/geolocation.dart';

/// One AI activity suggestion (API §5.21).
class ActivitySuggestion {
  const ActivitySuggestion({
    required this.name,
    required this.category,
    required this.description,
    required this.reason,
    this.url,
  });

  factory ActivitySuggestion.fromJson(Map<String, dynamic> json) {
    return ActivitySuggestion(
      name: (json['name'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'other',
      description: (json['description'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      url: json['url'] is String ? json['url'] as String : null,
    );
  }

  final String name;
  final String category;
  final String description;
  final String reason;
  final String? url;
}

/// The expanded chat panel shown inside the overlay bubble.
///
/// On first expand it fetches the device location, the current weather
/// payloads, and the AI activity suggestions (`POST /api/ai/activities`,
/// API §5.21), then renders them as a chat-style suggestions list with
/// loading / error / retry states.
///
/// The whole load is bounded by [loadTimeout] so a slow or hung request can
/// never leave the panel stuck on the loading spinner: when the deadline
/// passes the panel shows the error state with a Retry button.
class ActivitiesChatPanel extends StatefulWidget {
  const ActivitiesChatPanel({
    super.key,
    required this.onMinimize,
    required this.onClose,
    this.api,
    this.loadTimeout = defaultLoadTimeout,
  });

  /// How long the whole load (location + weather + forecasts + AI) may take
  /// before the panel gives up and offers a retry.
  static const Duration defaultLoadTimeout = Duration(seconds: 30);

  /// The deadline applied to a single load attempt. Injectable for tests.
  final Duration loadTimeout;

  /// Collapses the panel back to the compact bubble.
  final VoidCallback onMinimize;

  /// Closes the overlay entirely.
  final VoidCallback onClose;

  /// Injectable client for tests. Defaults to a real [ApiClient].
  final ApiClient? api;

  @override
  State<ActivitiesChatPanel> createState() => _ActivitiesChatPanelState();
}

class _ActivitiesChatPanelState extends State<ActivitiesChatPanel> {
  late final ApiClient _api = widget.api ?? ApiClient();

  bool _loading = false;
  String? _error;
  String? _placeName;
  List<ActivitySuggestion> _suggestions = const <ActivitySuggestion>[];

  /// Incremented on every load attempt so a stale (timed-out or superseded)
  /// attempt can never overwrite the state of a newer one.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Runs one load attempt, bounded by [ActivitiesChatPanel.loadTimeout].
  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _fetch().timeout(widget.loadTimeout);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = result.suggestions;
        _placeName = result.placeName;
        _loading = false;
      });
    } on TimeoutException {
      if (requestId != _requestId) return;
      _fail(
        'This is taking longer than expected. Please try again.',
      );
    } on ApiException catch (e) {
      if (requestId != _requestId) return;
      _fail(e.message);
    } on NetworkException catch (e) {
      if (requestId != _requestId) return;
      _fail(e.message);
    } on Exception {
      if (requestId != _requestId) return;
      _fail('Something went wrong while loading suggestions.');
    }
  }

  /// Performs the network work for one load attempt.
  ///
  /// The location is resolved with [getPositionSilently] because the overlay
  /// runs in its own isolate, where there is no foreground `Activity` to host
  /// a permission dialog — the prompting variant can hang indefinitely.
  Future<_LoadResult> _fetch() async {
    // 1 — device location (never prompts; bounded internally).
    final position = await getPositionSilently();
    if (position == null) {
      throw const NetworkException(
        'Could not determine your location. Check that location access is '
        'enabled and try again.',
      );
    }

    final coordinates = <String, dynamic>{
      'latitude': position.latitude,
      'longitude': position.longitude,
    };

    // 2 — current weather. `POST /api/weather` returns the raw Google
    // current-conditions object at the top level (API §5.1), so the whole map
    // is forwarded as `currentConditions` — exactly as the AI summary card
    // does. Reading a `currentConditions` key here would always be null.
    final weatherJson = await _api.post('weather', coordinates);
    final weather = weatherJson is Map<String, dynamic>
        ? weatherJson
        : const <String, dynamic>{};

    // 3 — forecasts and place name, all optional: a failure in any of them
    // must not prevent the suggestions from loading.
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _optional(() => _api.post('forecast', coordinates)),
      _optional(() => _api.post('forecast/daily', coordinates)),
      _optional(() => _api.post('geocode', coordinates)),
    ]);

    final hourly = results[0] is Map<String, dynamic>
        ? results[0] as Map<String, dynamic>
        : null;
    final daily = results[1] is Map<String, dynamic>
        ? results[1] as Map<String, dynamic>
        : null;
    final placeName = addressFromGeocode(results[2]);

    // 4 — AI activity suggestions.
    final activitiesJson = await _api.post('ai/activities', <String, dynamic>{
      'currentConditions': weather,
      'hourlyForecast': ?hourly,
      'dailyForecast': ?daily,
      ...coordinates,
      'placeName': ?placeName,
    });

    return _LoadResult(
      suggestions: _parseSuggestions(activitiesJson),
      placeName: placeName,
    );
  }

  /// Runs [request], returning `null` instead of throwing on failure.
  Future<dynamic> _optional(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on Exception {
      return null;
    }
  }

  List<ActivitySuggestion> _parseSuggestions(dynamic json) {
    if (json is! Map<String, dynamic>) return const <ActivitySuggestion>[];
    final list = json['suggestions'];
    if (list is! List) return const <ActivitySuggestion>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ActivitySuggestion.fromJson)
        .toList();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  Future<void> _openUrl(String url) async {
    if (!url.startsWith('http')) return;
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: <Widget>[
          _buildHeader(theme),
          const Divider(height: 1),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.auto_awesome, color: AppTheme.seed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _placeName == null
                  ? 'Activity suggestions'
                  : 'Suggestions near $_placeName',
              style: theme.textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.minimize, size: 20),
            tooltip: 'Minimize',
            onPressed: widget.onMinimize,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close',
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Finding things to do near you…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.cloud_off, size: 40, color: Colors.grey.shade500),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_suggestions.isEmpty) {
      return const Center(child: Text('No suggestions right now.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return _SuggestionCard(
          suggestion: suggestion,
          onOpenUrl: suggestion.url == null
              ? null
              : () => _openUrl(suggestion.url!),
        );
      },
    );
  }
}

/// The outcome of one successful load attempt.
class _LoadResult {
  const _LoadResult({required this.suggestions, this.placeName});

  final List<ActivitySuggestion> suggestions;
  final String? placeName;
}

/// A single suggestion rendered as a chat bubble card.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, this.onOpenUrl});

  final ActivitySuggestion suggestion;
  final VoidCallback? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpenUrl,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      suggestion.name,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  _CategoryChip(category: suggestion.category),
                ],
              ),
              if (suggestion.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(suggestion.description),
              ],
              if (suggestion.reason.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  suggestion.reason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (suggestion.url != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  suggestion.url!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small colored chip showing the suggestion category.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.seed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        category,
        style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.seed),
      ),
    );
  }
}
