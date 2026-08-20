import 'package:flutter/material.dart';

import '../services/heat_alert_controller.dart';

/// The "Heat alert" card on the Home page: a heat-index danger-threshold
/// slider and an on/off toggle that starts/stops the background notification
/// service.
///
/// Listens to the app-wide [HeatAlertController] so the slider and toggle stay
/// in sync with the persisted state and the running background service.
class HeatAlertSection extends StatefulWidget {
  const HeatAlertSection({super.key});

  @override
  State<HeatAlertSection> createState() => _HeatAlertSectionState();
}

class _HeatAlertSectionState extends State<HeatAlertSection> {
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    heatAlertController.addListener(_onChanged);
  }

  @override
  void dispose() {
    heatAlertController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onToggle(bool value) async {
    setState(() => _starting = true);
    try {
      if (value) {
        await heatAlertController.enable();
      } else {
        await heatAlertController.disable();
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _onThreshold(double value) async {
    await heatAlertController.setThreshold(value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = heatAlertController.isEnabled;
    final threshold = heatAlertController.threshold;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.thermostat,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Heat alert',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: _starting ? null : _onToggle,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Get notified when the heat index is dangerously high.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
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
              onChanged: enabled ? _onThreshold : null,
            ),
            const SizedBox(height: 4),
            Text(
              enabled
                  ? 'Monitoring in the background — you\'ll see a status '
                      'notification updated every 15 minutes.'
                  : 'Turn this on to start monitoring your local heat index.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
