import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/geocode.dart';
import '../utils/geolocation.dart';
import '../widgets/app_card.dart';

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

/// Owns the load state for [ActivitiesChatPanel].
///
/// The overlay host swaps the compact bubble for the chat panel on every
/// expand, which destroys the panel's [State]. Keeping the load state here —
/// in a controller owned by the overlay host — means the suggestions survive
/// a collapse/expand cycle for the lifetime of the overlay engine, and are
/// only fetched again when the user asks for it (see [load]).
///
/// [loadIfNeeded] starts a fetch only when no fetch is running and no
/// suggestions have been displayed yet; [load] always starts a fresh fetch
/// and backs the panel's Regenerate and Retry actions.
class ActivitiesSuggestionsController extends ChangeNotifier {
  ActivitiesSuggestionsController({
    ApiClient? api,
    this.loadTimeout = defaultLoadTimeout,
  }) : _api = api ?? ApiClient();

  /// How long the whole load (location + weather + forecasts + AI) may take
  /// before the attempt gives up and offers a retry.
  static const Duration defaultLoadTimeout = Duration(seconds: 30);

  final ApiClient _api;

  /// The deadline applied to a single load attempt. Injectable for tests.
  final Duration loadTimeout;

  bool _loading = false;
  String? _error;
  String? _placeName;
  List<ActivitySuggestion> _suggestions = const <ActivitySuggestion>[];

  /// Whether a fetch has completed successfully at least once. An empty
  /// result still counts, so an empty list cannot cause a refetch loop.
  bool _hasLoaded = false;

  /// Incremented on every load attempt so a stale (timed-out or superseded)
  /// attempt can never overwrite the state of a newer one.
  int _requestId = 0;

  bool _disposed = false;

  /// Whether a fetch is currently running.
  bool get loading => _loading;

  /// The message of the last failed attempt, or null when the last attempt
  /// succeeded (or none has run yet).
  String? get error => _error;

  /// The place name resolved by the last successful attempt.
  String? get placeName => _placeName;

  /// The suggestions from the last successful attempt.
  List<ActivitySuggestion> get suggestions => _suggestions;

  /// Whether suggestions have been displayed at least once.
  bool get hasLoaded => _hasLoaded;

  /// Loads the suggestions unless a fetch is already running or results have
  /// already been loaded.
  Future<void> loadIfNeeded() async {
    if (_loading || _hasLoaded) return;
    await load();
  }

  /// Runs one load attempt, bounded by [loadTimeout].
  ///
  /// The previous suggestions are kept while the attempt runs, so a
  /// regenerate never blanks the panel.
  Future<void> load() async {
    final requestId = ++_requestId;
    _loading = true;
    _error = null;
    _notify();

    try {
      final result = await _fetch().timeout(loadTimeout);
      if (requestId != _requestId) return;
      _suggestions = result.suggestions;
      _placeName = result.placeName;
      _hasLoaded = true;
      _loading = false;
      _notify();
    } on TimeoutException {
      if (requestId != _requestId) return;
      _fail('This is taking longer than expected. Please try again.');
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
    _loading = false;
    _error = message;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The expanded chat panel shown inside the overlay bubble.
///
/// It renders the suggestions held by an [ActivitiesSuggestionsController]:
/// the device location, the current weather payloads, and the AI activity
/// suggestions (`POST /api/ai/activities`, API §5.21) are fetched once and
/// then kept for the session, so collapsing and re-expanding the panel does
/// not refetch. A Regenerate action in the list footer starts a fresh fetch.
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
    this.controller,
    this.loadTimeout = defaultLoadTimeout,
  });

  /// How long the whole load (location + weather + forecasts + AI) may take
  /// before the panel gives up and offers a retry.
  static const Duration defaultLoadTimeout =
      ActivitiesSuggestionsController.defaultLoadTimeout;

  /// The deadline applied to a single load attempt. Injectable for tests.
  ///
  /// Ignored when [controller] is supplied — the controller owns its own
  /// deadline.
  final Duration loadTimeout;

  /// Collapses the panel back to the compact bubble.
  final VoidCallback onMinimize;

  /// Closes the overlay entirely.
  final VoidCallback onClose;

  /// Injectable client for tests. Defaults to a real [ApiClient].
  ///
  /// Ignored when [controller] is supplied.
  final ApiClient? api;

  /// The load state to render.
  ///
  /// Supplying one lets the suggestions survive the panel being rebuilt (the
  /// overlay host swaps the panel for the bubble on every collapse). When
  /// omitted the panel creates — and disposes — its own controller.
  final ActivitiesSuggestionsController? controller;

  @override
  State<ActivitiesChatPanel> createState() => _ActivitiesChatPanelState();
}

class _ActivitiesChatPanelState extends State<ActivitiesChatPanel> {
  late final ActivitiesSuggestionsController _controller =
      widget.controller ??
      ActivitiesSuggestionsController(
        api: widget.api,
        loadTimeout: widget.loadTimeout,
      );

  /// Whether this state created [_controller] and must therefore dispose it.
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    // Only fetches when nothing is running and nothing has been shown yet, so
    // re-expanding the panel reuses the results from this session.
    _controller.loadIfNeeded();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
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
    return AppCard(
      margin: const EdgeInsets.all(12),
      elevated: true,
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
              _controller.placeName == null
                  ? 'Activity suggestions'
                  : 'Suggestions near ${_controller.placeName}',
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
    final loading = _controller.loading;
    final error = _controller.error;
    final suggestions = _controller.suggestions;

    // A regenerate keeps the previous list on screen, so the full-screen
    // spinner is only used when there is nothing to show yet.
    if (loading && suggestions.isEmpty && error == null) {
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
    if (error != null && suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.cloud_off, size: 40, color: Colors.grey.shade500),
              const SizedBox(height: 12),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: loading ? null : _controller.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('No suggestions right now.'),
              const SizedBox(height: 12),
              _RegenerateButton(
                onPressed: loading ? null : _controller.load,
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        // Slim progress bar while a regenerate runs over the existing list.
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            // One extra item for the Regenerate action in the footer.
            itemCount: suggestions.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == suggestions.length) {
                return Center(
                  child: _RegenerateButton(
                    onPressed: loading ? null : _controller.load,
                  ),
                );
              }
              final suggestion = suggestions[index];
              return _SuggestionCard(
                suggestion: suggestion,
                onOpenUrl: suggestion.url == null
                    ? null
                    : () => _openUrl(suggestion.url!),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The "Regenerate" action shown below the suggestions.
class _RegenerateButton extends StatelessWidget {
  const _RegenerateButton({required this.onPressed});

  /// Null while a fetch is running, which disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Regenerate'),
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
    return AppCard(
      margin: EdgeInsets.zero,
      borderRadius: 12,
      onTap: onOpenUrl,
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
