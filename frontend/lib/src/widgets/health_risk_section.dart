import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../models/health_profile.dart';
import '../models/health_risk_assessment.dart';
import '../screens/health_details_screen.dart';
import '../services/health_profile_controller.dart';
import '../services/health_risk_cache.dart';
import '../services/settings_controller.dart';
import '../utils/format.dart';
import '../utils/risk_color.dart';
import 'ai_sign_in_prompt.dart';
import 'app_card.dart';
import 'health_risk_charts.dart';

/// The "Health risk" card on the Heat Data page.
///
/// Combines the signed-in user's health profile with the weather payloads the
/// page already fetched to produce a personalized heat-strain assessment: a
/// 0–100 risk score, an hourly probability curve, a core-temperature
/// uncertainty band, and a written summary.
///
/// The section is independent of the hourly/daily toggle above it. Generation
/// is user-initiated, and the result is cached locally with the date it was
/// generated so it survives an app restart. Regenerating sends the cached
/// assessment back as a reference point so the new answer stays consistent;
/// clearing removes it.
class HealthRiskSection extends StatefulWidget {
  const HealthRiskSection({
    super.key,
    required this.currentConditions,
    this.hourlyForecast,
    this.dailyForecast,
    this.api,
    this.auth,
    this.profileController,
    this.cache,
  });

  /// The raw Google current-conditions payload (see API §5.1).
  final Map<String, dynamic> currentConditions;

  /// The raw Google hourly forecast payload (see API §5.2). Optional.
  final Map<String, dynamic>? hourlyForecast;

  /// The raw Google daily forecast payload (see API §5.3). Optional.
  final Map<String, dynamic>? dailyForecast;

  /// Injectable client for tests. Defaults to a real [ApiClient].
  final ApiClient? api;

  /// Injectable auth state for tests. Defaults to the app-wide singleton.
  final AuthController? auth;

  /// Injectable profile controller for tests. Defaults to the app-wide
  /// singleton.
  final HealthProfileController? profileController;

  /// Injectable cache for tests. Defaults to the app-wide singleton.
  final HealthRiskCache? cache;

  @override
  State<HealthRiskSection> createState() => _HealthRiskSectionState();
}

class _HealthRiskSectionState extends State<HealthRiskSection> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final AuthController _auth = widget.auth ?? authController;
  late final HealthProfileController _profiles =
      widget.profileController ?? healthProfileController;
  late final HealthRiskCache _cache = widget.cache ?? healthRiskCache;

  bool _loading = false;
  String? _error;
  HealthRiskAssessment? _assessment;

  /// Whether the cached assessment has been read yet, so the card does not
  /// flash the "generate" state before the cache is restored.
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Restores the cached assessment and loads the profile.
  Future<void> _restore() async {
    final cached = await _cache.read();
    if (!mounted) return;
    setState(() {
      _assessment = cached;
      _restoring = false;
    });
    if (_auth.isAuthenticated) {
      await _profiles.load();
    }
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final json = await _api.post(
        'ai/health-risk',
        <String, dynamic>{
          'currentConditions': widget.currentConditions,
          if (widget.hourlyForecast != null)
            'hourlyForecast': widget.hourlyForecast,
          if (widget.dailyForecast != null) 'dailyForecast': widget.dailyForecast,
          // Send the previous result so the model can stay consistent with
          // what the user already saw.
          if (_assessment != null) 'previousAssessment': _assessment!.toJson(),
        },
        token: _auth.token,
      );
      if (!mounted) return;

      if (json is! Map<String, dynamic>) {
        _fail('The server returned an invalid assessment.');
        return;
      }

      final assessment = HealthRiskAssessment.fromJson(json);
      final stamped = await _cache.write(assessment);
      if (!mounted) return;

      setState(() {
        _assessment = stamped;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _auth.signOut();
        _fail('Your session expired. Please sign in again.');
        return;
      }
      _fail(e.message);
    } on NetworkException catch (e) {
      _fail(e.message);
    } on Exception {
      _fail('Something went wrong while generating your assessment.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  Future<void> _clear() async {
    await _cache.clear();
    if (!mounted) return;
    setState(() {
      _assessment = null;
      _error = null;
    });
  }

  Future<void> _openDetails() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => HealthDetailsScreen(controller: _profiles),
      ),
    );
    if (changed == true && mounted) {
      // The profile changed, so any existing assessment is now stale.
      await _clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_auth, _profiles]),
      builder: (context, _) {
        if (!_auth.isAuthenticated) {
          return AiSignInPrompt(
            auth: _auth,
            title: 'Health risk',
            description:
                'Sign in with Google to combine your health details with the '
                'current weather and estimate your heat risk.',
            icon: Icons.monitor_heart_outlined,
          );
        }

        return AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _header(context),
                const SizedBox(height: 12),
                _body(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          Icons.monitor_heart_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Health risk',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit health details',
          onPressed: _loading ? null : _openDetails,
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (_restoring) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_loading) {
      return const _RiskLoading();
    }

    if (_error != null) {
      return _RiskError(message: _error!, onRetry: _generate);
    }

    final assessment = _assessment;
    if (assessment != null) {
      return _RiskContent(
        assessment: assessment,
        use24Hour: settingsController.is24Hour,
        onRegenerate: _generate,
        onClear: _clear,
      );
    }

    if (!_profiles.hasProfile) {
      return _RiskNoProfile(
        onAddDetails: _openDetails,
        loading: _profiles.isLoading,
      );
    }

    return _RiskIdle(profile: _profiles.profile, onGenerate: _generate);
  }
}

/// The idle state: a summary of the saved profile plus a generate button.
class _RiskIdle extends StatelessWidget {
  const _RiskIdle({required this.profile, required this.onGenerate});

  final HealthProfile? profile;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Estimate how likely your core body temperature is to cross a '
          'clinical threshold in the current conditions.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (profile != null) ...<Widget>[
          const SizedBox(height: 12),
          _ProfileSummary(profile: profile),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.insights, size: 18),
            label: const Text('Generate assessment'),
          ),
        ),
      ],
    );
  }
}

/// Shown when the user has not entered any health details yet.
class _RiskNoProfile extends StatelessWidget {
  const _RiskNoProfile({required this.onAddDetails, required this.loading});

  final VoidCallback onAddDetails;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Add your personal and health details to estimate your heat risk. '
          'Only age and biological sex are required.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: loading ? null : onAddDetails,
            icon: const Icon(Icons.person_add_alt, size: 18),
            label: const Text('Add health details'),
          ),
        ),
      ],
    );
  }
}

/// A compact read-only summary of the saved profile.
class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});

  final HealthProfile profile;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (profile.age != null) '${profile.age} years',
      if (profile.biologicalSex != null)
        kHealthSexLabels[profile.biologicalSex] ?? profile.biologicalSex!,
      if (profile.activityLevel != null)
        kActivityLevelLabels[profile.activityLevel] ?? profile.activityLevel!,
    ];

    final tags = <String>[
      ...profile.conditions.map((c) => kHealthConditionLabels[c] ?? c),
      ...profile.medications.map((m) => kHealthMedicationLabels[m] ?? m),
      ...profile.lifestyle.map((l) => kHealthLifestyleLabels[l] ?? l),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          parts.join(' · '),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags
                .map(
                  (tag) => Chip(
                    label: Text(tag),
                    labelStyle: Theme.of(context).textTheme.bodySmall,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

/// The generated state: score, charts, and the written analysis.
class _RiskContent extends StatelessWidget {
  const _RiskContent({
    required this.assessment,
    required this.use24Hour,
    required this.onRegenerate,
    required this.onClear,
  });

  final HealthRiskAssessment assessment;
  final bool use24Hour;
  final VoidCallback onRegenerate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ScoreCard(assessment: assessment),
        if (assessment.hasChartData) ...<Widget>[
          const SizedBox(height: 20),
          _ChartTitle(
            title: 'Chance of crossing '
                '${assessment.thresholdC.toStringAsFixed(1)}°C',
            subtitle: assessment.thresholdLabel,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: LineChart(
              probabilityChartData(assessment, use24Hour: use24Hour),
            ),
          ),
          const SizedBox(height: 20),
          const _ChartTitle(
            title: 'Estimated core temperature',
            subtitle: 'Median with a 10th–90th percentile band',
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: LineChart(
              coreTempChartData(assessment, use24Hour: use24Hour),
            ),
          ),
        ],
        if (assessment.summary.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Text(
            assessment.summary,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (assessment.uncertainty.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _UncertaintyNote(text: assessment.uncertainty),
        ],
        if (assessment.keyFindings.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _BulletList(
            title: 'Key findings',
            icon: Icons.insights_outlined,
            items: assessment.keyFindings,
          ),
        ],
        if (assessment.recommendations.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _BulletList(
            title: 'What to do',
            icon: Icons.check_circle_outline,
            items: assessment.recommendations,
          ),
        ],
        const SizedBox(height: 16),
        _Footer(
          generatedAt: assessment.generatedAt,
          use24Hour: use24Hour,
          onRegenerate: onRegenerate,
          onClear: onClear,
        ),
      ],
    );
  }
}

/// The risk score, its level chip, and the threshold it was measured against.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.assessment});

  final HealthRiskAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final color = getRiskLevelColor(assessment.riskLevel);
    final foreground = riskLevelForeground(assessment.riskLevel);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${assessment.riskScore}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
              ),
              Text(
                'out of 100',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    riskLevelLabel(assessment.riskLevel),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${assessment.thresholdLabel} · '
                  '${assessment.thresholdC.toStringAsFixed(1)}°C',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartTitle extends StatelessWidget {
  const _ChartTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

/// A callout naming the largest sources of uncertainty.
class _UncertaintyNote extends StatelessWidget {
  const _UncertaintyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.help_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Uncertainty',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled bullet list.
class _BulletList extends StatelessWidget {
  const _BulletList({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('•  '),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The generation date plus the regenerate and clear actions.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.generatedAt,
    required this.use24Hour,
    required this.onRegenerate,
    required this.onClear,
  });

  final DateTime? generatedAt;
  final bool use24Hour;
  final VoidCallback onRegenerate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final generatedAt = this.generatedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (generatedAt != null)
          Text(
            'Generated ${formatDateTime(generatedAt, use24Hour: use24Hour)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Update'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}

class _RiskLoading extends StatelessWidget {
  const _RiskLoading();

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
        Expanded(
          child: Text(
            'Assessing your heat risk…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _RiskError extends StatelessWidget {
  const _RiskError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
