import 'package:flutter/material.dart';

import '../services/heat_alert_controller.dart';
import 'app_card.dart';

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

class _NotificationsSectionState extends State<NotificationsSection>
    with WidgetsBindingObserver {
  bool _starting = false;

  HeatAlertController get _controller =>
      widget.controller ?? heatAlertController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onChanged);
    // Re-read the OS permission once the first frame is up so a permission
    // revoked while the app was closed shows the blocked warning immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.refreshPermissionState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have changed the permission in the system settings while
    // the app was in the background.
    if (state == AppLifecycleState.resumed) {
      _controller.refreshPermissionState();
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onMasterToggle(bool value) async {
    setState(() => _starting = true);
    try {
      if (value) {
        final enabled = await _controller.enableNotifications();
        if (!enabled && mounted) _showPermissionDenied();
      } else {
        await _controller.disableNotifications();
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Tells the user why the toggle snapped back off and offers a shortcut to
  /// the system settings, where the permission can still be granted after the
  /// system stopped showing the dialog.
  void _showPermissionDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Notifications are blocked. Allow them in your device settings to '
          'turn this on.',
        ),
        action: SnackBarAction(
          label: 'Open settings',
          onPressed: _controller.openNotificationSettings,
        ),
      ),
    );
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

    return AppCard(
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
            if (_controller.areNotificationsBlocked) ...<Widget>[
              const SizedBox(height: 8),
              _BlockedWarning(
                onOpenSettings: _controller.openNotificationSettings,
              ),
            ],
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

/// Inline warning shown when notifications are enabled in the app but blocked
/// by the operating system.
class _BlockedWarning extends StatelessWidget {
  const _BlockedWarning({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.notifications_off, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Notifications are blocked',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onErrorContainer,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Allow them in your device settings to receive alerts.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                ),
                TextButton(
                  onPressed: onOpenSettings,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: colors.onErrorContainer,
                  ),
                  child: const Text('Open settings'),
                ),
              ],
            ),
          ),
        ],
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
