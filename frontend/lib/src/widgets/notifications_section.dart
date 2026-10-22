import 'package:flutter/material.dart';

import '../services/heat_alert_controller.dart';

/// The "Notifications" card on the Home page: a master toggle that starts/stops
/// the background notification service, plus per-type sub-toggles (heat alert
/// and health reminder) that appear once the master toggle is on.
///
/// Listens to the app-wide [HeatAlertController] so the switches and the
/// heat-index danger-threshold slider stay in sync with the persisted state and
/// the running background service.
class NotificationsSection extends StatefulWidget {
  const NotificationsSection({super.key, this.controller});

  /// The controller backing this section. Defaults to the app-wide
  /// [heatAlertController] singleton; injectable for tests.
  final HeatAlertController? controller;

  @override
  State<NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<NotificationsSection> {
  bool _starting = false;

  HeatAlertController get _controller =>
      widget.controller ?? heatAlertController;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onMasterToggle(bool value) async {
    setState(() => _starting = true);
    try {
      if (value) {
        await _controller.enableNotifications();
      } else {
        await _controller.disableNotifications();
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _onThreshold(double value) async {
    await _controller.setThreshold(value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _controller.isNotificationsEnabled;
    final heatAlertEnabled = _controller.isHeatAlertEnabled;
    final healthReminderEnabled = _controller.isHealthReminderEnabled;
    final threshold = _controller.threshold;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.notifications,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: _starting ? null : _onMasterToggle,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Get persistent notifications about your local conditions.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (enabled) ...<Widget>[
              const SizedBox(height: 8),
              const Divider(),
              _SubToggle(
                title: 'Heat alert',
                description:
                    'Get notified when the heat index is dangerously high.',
                value: heatAlertEnabled,
                onChanged: _controller.setHeatAlertEnabled,
              ),
              if (heatAlertEnabled) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Text(
                      'Danger threshold',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${threshold.toStringAsFixed(0)}°C',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                Slider(
                  value: threshold,
                  min: 25,
                  max: 40,
                  divisions: 15,
                  label: '${threshold.toStringAsFixed(0)}°C',
                  onChanged: _onThreshold,
                ),
              ],
              const SizedBox(height: 4),
              _SubToggle(
                title: 'Health reminder',
                description:
                    'Get a tip for the current conditions (rain, UV, heat…).',
                value: healthReminderEnabled,
                onChanged: _controller.setHealthReminderEnabled,
              ),
              const SizedBox(height: 8),
              Text(
                'Monitoring in the background — notifications update every '
                '15 minutes.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Turn this on to start monitoring your local conditions.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A labelled sub-toggle row used for the individual notification types.
class _SubToggle extends StatelessWidget {
  const _SubToggle({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
